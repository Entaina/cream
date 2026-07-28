# Bump de Gema

## Uso

`/gem-bump NOMBRE_GEMA`

Ejemplo: `/gem-bump langchainrb` o `/gem-bump rails`

El nombre de la gema es el parámetro obligatorio que el usuario proporciona tras el comando.

---

## Objetivo

Actualizar una gema del proyecto de forma segura: evaluar el impacto antes de actualizar, aplicar los cambios necesarios y asegurar que los tests sigan pasando.

---

## Flujo de trabajo

### 1. Validar que la gema existe en el proyecto

- Comprobar que la gema está en `Gemfile` o `Gemfile.jumpstart`
- Si no existe, informar al usuario y detener

### 2. Investigar cambios antes de actualizar

Antes de ejecutar `bundle update GEMA`:

- Consultar el changelog/releases de la gema (GitHub, rubygems.org)
- Identificar si hay **breaking changes**, cambios de API o deprecaciones
- Revisar la versión actual en `Gemfile.lock` y la versión objetivo según restricciones del Gemfile

**Criterios de impacto significativo** (requieren preguntar al usuario antes de continuar):

- Cambios de API incompatibles (métodos renombrados, eliminados o con firma distinta)
- Cambios de versión mayor (ej: 1.x → 2.x) sin guía de migración clara
- Dependencias nuevas que puedan afectar a otras gemas
- Cambios en convenciones o configuración que afecten a múltiples archivos
- Gemas core del stack (rails, turbo-rails, puma, etc.) con cambios estructurales

Si detectas impacto significativo:

1. Resumir los cambios relevantes
2. Indicar qué partes del código podrían verse afectadas
3. Preguntar explícitamente: *"¿Quieres que proceda con la actualización? Puede requerir cambios en [X archivos/áreas]. Responde sí para continuar."*
4. No ejecutar `bundle update` hasta recibir confirmación

### 3. Actualizar la gema

Solo si no hay impacto significativo o el usuario ha confirmado:

```bash
bundle update NOMBRE_GEMA
```

### 4. Verificar y corregir el código

- Ejecutar `bundle exec rspec --tag "~llm"` (excluyendo tests LLM por defecto)
- Si hay fallos:
  - Analizar el error y la causa
  - Aplicar los cambios necesarios en el código
  - Actualizar tests si la API ha cambiado (mockear siempre llamadas HTTP y jobs según reglas del proyecto)
  - Volver a ejecutar los tests hasta que pasen

### 5. Ejecutar herramientas de calidad

- `bundle exec standardrb --fix`
- `bundle exec erblint -a .`
- `bundle exec i18n-tasks normalize`

Corregir cualquier problema que aparezca.

### 6. Resumen final

- Versión anterior → versión nueva
- Archivos modificados
- Cambios relevantes aplicados
- Estado de los tests

---

## Reglas importantes

- **Mockear siempre**: Llamadas HTTP y jobs en tests (según reglas del proyecto)
- **No modificar nada adicional**: Solo lo necesario para que la gema funcione
- **KISS y YAGNI**: Soluciones mínimas que cumplan el objetivo
- **Preguntar antes de cambios de alto impacto**: No asumir que el usuario quiere asumir riesgos grandes
