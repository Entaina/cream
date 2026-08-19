---
description: Motor de desarrollo GSM/event-driven — procesa un evento (card, PR, CI, petición) con la skill adw
---

Activa la skill **`adw`** (`.claude/skills/adw/SKILL.md`) y trátala como el motor del flujo de desarrollo de cream.

**Evento a procesar:** $ARGUMENTS

Si no se ha pasado ningún argumento, pregunta al usuario qué evento/WorkItem quiere procesar (una URL o id de card de Basecamp, un nº de PR, un fallo de CI, o una petición libre "entrega X").

Sigue el ciclo del motor tal como lo define la skill: **cargar** el contrato (`references/contract.md` + los ficheros Conditional según el área), **percibir** el estado GSM del WorkItem desde observables reales (Basecamp, git, `gh`, filesystem) sin primar contexto de `Understand`, **deliberar** la orquestación (inline / subagente / workflow dinámico) hasta el objetivo de quiescencia, y **ejecutar y verificar** cada milestone contra su observable. Respeta las invariantes: `Guard[advance_any]`, `Guard[understand]` (no se planifica sin card asignada + In progress), gates humanos en las acciones outward (merge, mover card a Done) y nada outward dentro de un workflow. Al terminar, reporta el estado GSM final y el siguiente gate humano pendiente.
