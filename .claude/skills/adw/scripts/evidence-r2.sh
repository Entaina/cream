#!/usr/bin/env bash
#
# evidence-r2.sh — sube ficheros de evidencia de ADW a Cloudflare R2.
#
# Réplica autocontenida de `bin/adw evidence` de brainsome-rails (adw/lib/adw/r2.rb +
# commands/evidence.rb), pero sin depender del bundle de la app: usa el CLI `aws` (S3 API
# compatible con R2). Se empaqueta dentro de la skill `adw` (convención canónica: scripts/).
#
# Uso:
#   scripts/evidence-r2.sh status
#   scripts/evidence-r2.sh upload <ref> <fichero> [<fichero>...]
#
# Credenciales (en .env, gitignored — NUNCA exportadas al shell):
#   CLOUDFLARE_R2_BUCKET_URL       (obligatoria)  https://<accountid>.r2.cloudflarestorage.com/<bucket>
#   CLOUDFLARE_R2_ACCESS_KEY_ID    (obligatoria)
#   CLOUDFLARE_R2_SECRET_ACCESS_KEY(obligatoria)
#   CLOUDFLARE_R2_PUBLIC_DOMAIN    (opcional)     base de la URL pública; si falta, la URL es "/<key>"
#
# Contrato (idéntico a bin/adw evidence):
#   - `status`  : exit 0 si las 3 vars están; imprime "R2 enabled (bucket <name>)".
#                 exit 3 si falta alguna; imprime qué var falta a stderr.
#   - `upload`  : por fichero sube a la key adw/<ref>/<basename> e imprime "<basename>\t<url>"
#                 a stdout (una línea por fichero). Fallo por fichero → "FAILED\t<path>\t<err>"
#                 a stderr. Exit 0 todo ok / 1 algún fallo / 3 R2 deshabilitado.
#   - "R2 disabled" SOLO es conclusión válida si `status` devolvió exit 3. Nunca se infiere
#     leyendo $CLOUDFLARE_R2_* del shell (están vacías por diseño: viven en .env).
#
# Nota aws-cli/R2: fijamos AWS_REQUEST_CHECKSUM_CALCULATION=when_required para evitar los
# checksums por defecto que algunas versiones de aws-cli v2 (2025+) envían y R2 rechaza.
# En versiones anteriores la variable se ignora sin efecto.

set -u

REQUIRED_VARS=(CLOUDFLARE_R2_BUCKET_URL CLOUDFLARE_R2_ACCESS_KEY_ID CLOUDFLARE_R2_SECRET_ACCESS_KEY)

# --- carga de .env (en este proceso, no en el shell padre) -------------------
# No-overriding: si las 3 vars ya están en el entorno (CI/shell), no toca nada;
# si no, parsea .env.local y .env desde la raíz del repo.
#
# NO usamos `source .env`: los ficheros dotenv pueden tener valores no válidos
# como shell (espacios, `<`, `>`, `#`, `$` sin comillas — p.ej.
# `MAILER_FROM=Cream <noreply@example.com>`). Parseamos línea a línea y
# asignamos el valor LITERAL (sin evaluación de shell), igual que dotenv-rails.
parse_env_file() {
  local file="$1" line key val
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"                       # CRLF → LF
    case "$line" in ''|'#'*) continue ;; esac  # blancos/comentarios
    line="${line#export }"                      # prefijo opcional `export `
    case "$line" in *=*) ;; *) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    key="${key//[[:space:]]/}"                   # sin espacios en la clave
    case "$key" in [A-Za-z_][A-Za-z0-9_]*) ;; *) continue ;; esac
    # quitar comillas envolventes emparejadas
    if [ "${val#\"}" != "$val" ] && [ "${val%\"}" != "$val" ]; then
      val="${val#\"}"; val="${val%\"}"
    elif [ "${val#\'}" != "$val" ] && [ "${val%\'}" != "$val" ]; then
      val="${val#\'}"; val="${val%\'}"
    fi
    # non-overriding: solo si la var no está ya definida
    if [ -z "${!key:-}" ]; then
      export "$key=$val"
    fi
  done < "$file"
}

load_env() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  cd "$root" 2>/dev/null || true

  if [ -n "${CLOUDFLARE_R2_BUCKET_URL:-}" ] \
    && [ -n "${CLOUDFLARE_R2_ACCESS_KEY_ID:-}" ] \
    && [ -n "${CLOUDFLARE_R2_SECRET_ACCESS_KEY:-}" ]; then
    return
  fi

  local f
  for f in .env.local .env; do
    [ -f "$f" ] && parse_env_file "$f"
  done
}

missing_vars() {
  local v missing=()
  for v in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!v:-}" ]; then
      missing+=("$v")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    printf '%s\n' "${missing[@]}"
  fi
}

# --- derivación de endpoint / bucket desde CLOUDFLARE_R2_BUCKET_URL ----------
bucket_name() {
  local url="$CLOUDFLARE_R2_BUCKET_URL" rest bucket
  rest="${url#*://}"                 # host/bucket...
  case "$rest" in
    */*) bucket="${rest#*/}" ;;      # todo lo que hay tras el primer /
    *)   bucket="" ;;
  esac
  bucket="${bucket%/}"               # sin barra final
  printf '%s' "$bucket"
}

endpoint() {
  local url="$CLOUDFLARE_R2_BUCKET_URL" scheme rest host
  scheme="${url%%://*}"
  rest="${url#*://}"
  host="${rest%%/*}"
  printf '%s://%s' "$scheme" "$host"
}

content_type_for() {
  local ext="${1##*.}"
  case "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')" in
    png)       printf 'image/png' ;;
    jpg|jpeg)  printf 'image/jpeg' ;;
    webp)      printf 'image/webp' ;;
    gif)       printf 'image/gif' ;;
    webm)      printf 'video/webm' ;;
    mp4)       printf 'video/mp4' ;;
    *)         printf 'application/octet-stream' ;;
  esac
}

public_url() {
  local key="$1" base="${CLOUDFLARE_R2_PUBLIC_DOMAIN:-}"
  base="${base%/}"                   # sin barra final
  printf '%s/%s' "$base" "$key"
}

disabled_message() {
  local missing
  missing="$(missing_vars | paste -sd, - | sed 's/,/, /g')"
  printf 'R2 disabled: missing %s (expected in .env)\n' "$missing" >&2
}

# --- subcomandos -------------------------------------------------------------
cmd_status() {
  if [ -z "$(missing_vars)" ]; then
    printf 'R2 enabled (bucket %s)\n' "$(bucket_name)"
    exit 0
  else
    disabled_message
    exit 3
  fi
}

cmd_upload() {
  local ref="${1:-}"; shift || true
  if [ -z "$ref" ] || [ "$#" -eq 0 ]; then
    printf 'usage: evidence-r2.sh upload <ref> <file> [<file>...]\n' >&2
    exit 2
  fi

  if [ -n "$(missing_vars)" ]; then
    disabled_message
    exit 3
  fi

  local ep bkt
  ep="$(endpoint)"
  bkt="$(bucket_name)"

  export AWS_ACCESS_KEY_ID="$CLOUDFLARE_R2_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$CLOUDFLARE_R2_SECRET_ACCESS_KEY"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
  export AWS_REQUEST_CHECKSUM_CALCULATION="${AWS_REQUEST_CHECKSUM_CALCULATION:-when_required}"

  local failed=0 path base key err
  for path in "$@"; do
    base="$(basename "$path")"
    key="adw/${ref}/${base}"
    if [ ! -f "$path" ]; then
      printf 'FAILED\t%s\tno such file\n' "$path" >&2
      failed=1
      continue
    fi
    if err="$(aws s3api put-object \
      --endpoint-url "$ep" \
      --bucket "$bkt" \
      --key "$key" \
      --body "$path" \
      --content-type "$(content_type_for "$path")" 2>&1 >/dev/null)"; then
      printf '%s\t%s\n' "$base" "$(public_url "$key")"
    else
      printf 'FAILED\t%s\t%s\n' "$path" "${err:-aws put-object error}" >&2
      failed=1
    fi
  done

  [ "$failed" -eq 0 ] || exit 1
}

main() {
  local sub="${1:-}"; shift || true
  load_env
  case "$sub" in
    status)  cmd_status ;;
    upload)  cmd_upload "$@" ;;
    ''|-h|--help|help)
      printf 'usage: evidence-r2.sh {status | upload <ref> <file>...}\n' >&2
      [ -z "$sub" ] && exit 2 || exit 0
      ;;
    *)
      printf 'unknown subcommand: %s\n' "$sub" >&2
      exit 2
      ;;
  esac
}

main "$@"
