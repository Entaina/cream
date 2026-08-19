# task-triage — Evaluación de readiness de un WorkItem

> Skill-herramienta del motor `adw`. Consumible en 3 modos: (a) por el motor en el intake de cards nuevas, (b) por un subagente de workflow dinámico que reciba la ruta de este fichero, (c) standalone. **Sin estado y sin acciones outward**: solo evalúa y reporta; no publica comentarios, no mueve cards, no crea nada. El consumidor decide qué hacer con el veredicto.

## Propósito

Evaluar, desde la perspectiva de un ingeniero que debe implementar el trabajo **sin acceso al product owner**, si el contenido de un WorkItem (card de Basecamp o petición libre) tiene detalle suficiente para implementarse. No sabe nada del lifecycle GSM.

## Contrato

**Inputs** — Contenido del WorkItem: texto de la card o petición (título, descripción, checklist → trátalos como criterios de aceptación, comentarios, adjuntos/imágenes). Acepta JSON estructurado o texto plano.

**Outputs** — Reporte estructurado (JSON en un bloque de código):

```json
{
  "verdict": "ready | not_ready | needs_split",
  "criteria": [
    {"name": "Alcance Acotado", "level": "required", "pass": false, "notes": "'y páginas similares' no especifica cuáles"}
  ],
  "edge_cases": [
    {"dimension": "Permisos y roles", "severity": "critical | important | nice_to_have", "gap": "No se dice quién puede exportar", "question": "¿Todos los miembros del workspace o solo admin?"}
  ],
  "clarification_questions": ["(solo si not_ready) Preguntas redactadas, listas para publicar tal cual"],
  "split_proposal": [{"title": "(solo si needs_split)", "scope": "qué incluye", "rationale": "por qué es independiente"}],
  "summary": "Veredicto en una línea"
}
```

- `ready` — implementable ya; observaciones menores van en `edge_cases`.
- `not_ready` — incluye `clarification_questions` con la lista CONCRETA de preguntas redactadas.
- `needs_split` — agrupa varios entregables independientes; incluye `split_proposal`.

> **No hay `delivery_path`.** cream tiene un único camino `main`-first (sin hotfix/producción-first, sin staging). Un bug urgente es el flujo normal acelerado; no requiere decisión de camino en el triage.

## Criterios de readiness

Todos los **Required** deben pasar para `ready`. Para cada criterio: pass/fail + nota breve.

| Criterio | Nivel | Pregunta clave |
|---|---|---|
| **Problema Definido** | Required | ¿El problema/necesidad que motiva el trabajo está explícito o es inequívocamente inferible? |
| **Solución Funcional Clara** | Required | ¿La solución esperada desde la perspectiva del usuario está definida? Si hay varias opciones viables, ¿están explicadas para que el PO decida? |
| **Objetivo Claro** | Required | ¿Un ingeniero entiende la meta sin adivinar? |
| **Alcance Acotado** | Required | ¿Está claro qué entra y qué queda fuera? ¿Sin frases abiertas ("etc.", "y similares")? ¿Cabe en una entrega o agrupa varios entregables (→ `needs_split`)? |
| **Criterios de Aceptación** | Required | ¿Hay condiciones explícitas de "terminado" (checkboxes, comportamientos esperados)? |
| **Sin Ambigüedades** | Required | ¿No hay frases interpretables de varias formas sin contexto adicional? |
| **Sin Dependencias Bloqueantes Desconocidas** | Required | ¿Depende de decisiones pendientes, accesos o trabajo de terceros no resuelto? |
| **Contexto Suficiente** | Recommended | ¿Las referencias a sistemas/diseños/decisiones previas son concretas (links, nombres, fechas)? |
| **Resultado Verificable** | Recommended | ¿El resultado se puede verificar mirando la UI, ejecutando un test o revisando datos? |

## Procedimiento

1. **Parsear la entrada** (JSON o texto; incorpora adjuntos/imágenes si los hay).
2. **Evaluar cada criterio**: pass/fail + nota explicando por qué.
3. **Análisis proactivo de edge cases** — piensa adversarialmente ("¿qué pasa si esto sale mal?", "¿y en el caso límite?") sobre: errores y fallos (¿solo happy path?) · estados vacíos y límites de datos (0, 1, 10.000 items) · **permisos y roles (multi-tenant: aislamiento entre workspaces; roles `admin`/`sales_director`/`salesperson`)** · concurrencia · impacto en funcionalidad existente (migración de datos, retrocompatibilidad) · estados intermedios · dependencias externas · formatos. Reporta solo las que revelen gaps reales.
4. **Determinar veredicto**: `not_ready` si falla algún Required o hay edge cases críticos sin resolver; `needs_split` si es implementable pero agrupa entregables independientes; `ready` en otro caso.
5. **Redactar las preguntas** (si `not_ready`): 1-2 preguntas concretas por gap, agrupadas por tema.

## Reglas

- **Sin acciones outward**: no publiques las preguntas ni comentes/muevas nada — devuélvelas redactadas en el reporte. Nunca crees issues de GitHub (modo por defecto = card directa; ver [`contract.md`](contract.md)).
- **Sin conocimiento del lifecycle**: no razones sobre stages/milestones/columnas aquí.
- **No asumas** información no explícita; pero no te limites a lo explícito: identifica escenarios que el PO probablemente no ha considerado.
- **Preguntas para el PO, en lenguaje llano**: cero jerga técnica (nada de "API", "endpoint", "base de datos"), perspectiva de usuario/negocio, autocontenidas, máximo 5-7. Cuando "Solución Funcional Clara" falla por existir varias opciones, describe cada opción con pros y contras en lenguaje no técnico.
