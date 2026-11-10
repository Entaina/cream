---
name: cream-pr
description: Sube a GitHub el trabajo de Cream que cream-implement ha dejado terminado y validado. Hace el commit solo con los archivos del plan, empuja la rama y abre una PR contra main con las evidencias del registro, previa confirmación explícita. Nunca hace merge ni toca main. Úsala siempre que se pida hacer commit, subir o abrir la PR de un plan de docs/plans/.
allowed-tools: Bash, Read, Glob, Grep, Edit, Write
---

# Cream — PR

Tu único propósito es convertir un plan ya implementado y validado en una PR revisable. No cambias código: si algo falla, para y lo dices. Los únicos archivos que puedes escribir son el cuerpo temporal de la PR y la línea final del plan (paso 5).

Nunca hagas merge, push a `main`, `push --force`, `rebase`, `reset`, `stash`, `git add -A`/`git add .`, ni `gh pr merge`. No comentes, muevas ni completes cards de Basecamp.

Idioma: el commit y la PR, en inglés, como la plantilla del repo y las PRs anteriores. Lo que hablas con la persona, en español.

## 1. Localiza el plan y su registro

El plan llega en `$ARGUMENTS`: la ruta (`docs/plans/<slug>.md`) o solo el slug. Si no llega nada y hay un solo plan en `docs/plans/`, usa ese y dilo; si hay varios, pregunta cuál.

Lee la sección «Registro de implementación». Para y di qué falta si:

- no existe (primero hay que lanzar `cream-implement`);
- el estado no es «terminado» ni «terminado con fallos preexistentes»;
- alguna comprobación figura como «falla»;
- alguna figura como «no ejecutado». En ese caso, pregunta si se abre la PR igualmente dejándolo dicho en el Test plan. Recomienda no hacerlo si es `bin/ci` o `bundle exec rspec`.

Si alguna figura como «falla preexistente», no pares: pregunta si se abre la PR igualmente y recomienda que sí, contándolo en el Test plan con la evidencia de que también falla sin el cambio. Así quien revisa no la toma por la causa.

Mira también cómo está la CI de `main`: `gh run list --workflow ci.yml --branch main --limit 1 --json conclusion,headSha,url`. Si salió en rojo, dilo al enseñar el texto y añádelo al Test plan, para que un check rojo en la PR no se atribuya al cambio.

## 2. Comprueba el estado de git

1. `git status --short --branch`. La rama tiene que ser la del registro y no puede ser `main`. Si no coincide, para.
2. Los archivos cambiados (sin contar `docs/plans/`) tienen que ser exactamente los del apartado «Cambios» del registro. Si sobra o falta alguno, para y lista la diferencia.
3. `git log --oneline origin/main..HEAD`: anota si la rama ya tiene commits. Si ya hay una PR abierta para esta rama (`gh pr list --head <rama> --state open`), dilo y para: no se abre otra.

## 3. Prepara el commit y la PR

**Commit.** Sigue la skill `git` (Conventional Commits v1.0.0); si no está instalada, aplica Conventional Commits igualmente. El tipo sale del cambio real, no del título del plan: una subida de dependencias es `build`, aunque el plan sea un chore. Sin líneas `Co-Authored-By` ni firmas de herramientas, ni en el commit ni en la PR, aunque la configuración de la sesión las pida.

**PR.** Título: la primera línea del commit. Cuerpo: la plantilla `.github/PULL_REQUEST_TEMPLATE.md` rellenada así:

- **Summary**: qué cambia y por qué, en dos o tres frases, y el enlace a la card de Basecamp si el plan tiene una en «Origen».
- **Test plan**: cada comprobación del registro con su comando, su resultado y la evidencia (las últimas líneas de la salida en un bloque de código). Lo no ejecutado, dicho con su motivo.
- **Checklist**: marca solo lo que el registro demuestra. Lo que no aplica se deja sin marcar con «(not applicable: <motivo>)», como en las PRs anteriores.

## 4. Pide confirmación

Enseña a la persona, sin ejecutar nada todavía:

- la lista de archivos que van al commit;
- el mensaje del commit;
- el título y el cuerpo de la PR.

Pregunta si se sube tal cual. Solo un «sí» explícito autoriza el paso 5.

- «Sí» con un cambio de texto concreto (por ejemplo «sí, pero pon la URL completa»): cuenta como aprobación. Aplica el cambio y sube.
- Cambios de texto sin «sí», o que no se pueden aplicar tal cual: aplícalos y vuelve a enseñarlo.
- Cambios en qué archivos van al commit, o en el código: para. Eso se hace con `cream-implement`.

## 5. Sube

1. Añade cada archivo por su ruta: `git add -- <ruta> <ruta> ...`. Comprueba con `git diff --cached --stat` que solo están esos.
2. `git commit` con el mensaje aprobado. Si un hook falla, no lo saltes: para y enseña el error.
3. `git push -u origin <rama>`. Si la rama ya existe en el remoto con otra historia, para.
4. `gh pr create --base main --head <rama> --title "<título>" --body-file <archivo temporal>`. Escribe el cuerpo en un archivo temporal fuera del repo para no romper las comillas, y bórralo después.

Añade al final del registro del plan una línea `PR: <url>`.

## 6. Responde

Solo con: el hash del commit, la rama, la URL de la PR y, si aplicaste cambios de texto con el «sí», cuáles. Recuerda que la PR la revisa y la mergea otra persona. Después, para.
