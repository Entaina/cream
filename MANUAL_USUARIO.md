# Manual de usuario — Cream

> 🇬🇧 [English version](USER_MANUAL.md)

Cream es un CRM por **workspaces** para gestionar **personas**, **empresas** y **deals** (oportunidades), con notas, tareas, listas y un historial de actividad compartido en el equipo.

> **Última revisión:** 2026-09-30 (reservas: el anfitrión figura como asistente en Google Calendar)
> Este documento describe la funcionalidad **visible para el usuario**. Las funcionalidades desactivadas aparecen al final en «Próximamente».

---

## Índice

1. [Acceso y cuenta](#1-acceso-y-cuenta)
2. [Workspaces](#2-workspaces)
3. [Navegación](#3-navegación)
4. [Dashboard](#4-dashboard)
5. [Personas, empresas y deals](#5-personas-empresas-y-deals)
6. [Productos](#6-productos)
7. [Tareas](#7-tareas)
8. [Listas](#8-listas)
9. [Pipelines y tablero kanban](#9-pipelines-y-tablero-kanban)
10. [Vistas guardadas](#10-vistas-guardadas)
11. [Campos personalizados](#11-campos-personalizados)
12. [Columnas mágicas](#12-columnas-mágicas)
13. [Ficha de un registro](#13-ficha-de-un-registro)
14. [Importar y exportar CSV](#14-importar-y-exportar-csv)
15. [Email desde registros](#15-email-desde-registros)
16. [Automatizaciones](#16-automatizaciones)
17. [Alertas configurables](#17-alertas-configurables)
18. [Webhooks](#18-webhooks)
19. [Notificaciones](#19-notificaciones)
20. [Equipo e invitaciones](#20-equipo-e-invitaciones)
21. [Ajustes del workspace](#21-ajustes-del-workspace)
22. [Tokens de API y MCP](#22-tokens-de-api-y-mcp)
23. [Reports](#23-reports)
24. [Asistente IA](#24-asistente-ia)
25. [Chat de conocimiento](#25-chat-de-conocimiento)
26. [Pagos de Stripe](#26-pagos-de-stripe)
27. [Formularios de captación](#27-formularios-de-captación)
28. [Reservas de calendario](#28-reservas-de-calendario)
29. [Marketing](#29-marketing)
30. [Próximamente](#30-próximamente)

---

## 1. Acceso y cuenta

### Iniciar sesión

En la pantalla de acceso puedes:

- **Iniciar sesión con Google** (si está configurado en tu entorno).
- Usar **email y contraseña** registrados en Cream.

Si olvidaste la contraseña, usa **¿Olvidaste la contraseña?** para recibir un enlace de restablecimiento por email.

En la esquina superior derecha de la pantalla de acceso (y registro) verás el selector **ES | EN**. Elige el idioma de la interfaz; la preferencia se guarda en tu navegador hasta que crees cuenta o inicies sesión.

### Crear cuenta

En **Crear cuenta** introduces tu nombre, email, contraseña y el nombre del workspace. Al registrarte:

- Se crea tu usuario.
- Se crea un workspace nuevo con el nombre indicado (o «Nombre's Workspace» si no indicas uno).
- Eres **admin** de ese workspace.

### Cambiar tu nombre

1. Abre **Perfil** (también desde tu nombre en la parte inferior del menú lateral).
2. En **Datos personales**, edita el campo **Nombre** y, si quieres, el **Idioma** (Español / English).
3. Pulsa **Guardar**.

El nombre se actualiza en el menú lateral, en las menciones y en la actividad del equipo. El idioma afecta al menú, login, notificaciones del cromo de la app y secciones compartidas de las fichas (notas, tareas, actividad…). El email se muestra en esa misma sección, pero no se puede cambiar desde ahí.

También puedes cambiar el idioma al vuelo con **ES | EN** en la parte inferior del menú lateral (junto al tema claro/oscuro).

### Cerrar sesión

En la parte inferior del menú lateral, pulsa el icono de salida junto a tu nombre.

---

## 2. Workspaces

Un **workspace** es el espacio de trabajo compartido del equipo. Todos los registros (personas, empresas, deals, etc.) pertenecen a un workspace concreto.

### Cambiar de workspace

Si perteneces a más de un workspace, en la cabecera del menú lateral verás el nombre del workspace actual. Haz clic para desplegar la lista y cambiar al que quieras.

### Roles

| Rol                 | Descripción |
|---------------------|-------------|
| Admin               | Acceso total al workspace: invitar miembros, cambiar roles, editar el nombre del workspace, gestionar campos personalizados y ver **todos** los deals. |
| Director comercial  | Ve y edita **todos** los deals; puede añadir colaboradores en cualquier deal. No gestiona invitaciones, roles ni ajustes del workspace. |
| Vendedor            | Ve y edita solo los deals de los que es **Owner** o en los que le han dado acceso como **colaborador**. Personas, empresas, tareas y el resto de registros siguen siendo visibles para todo el workspace. |

Los **vendedores** ven en el **Dashboard** y en **Deals** únicamente sus deals (propios o compartidos). **Admin** y **Director comercial** ven todos los deals del workspace.

---

## 3. Navegación

El menú lateral izquierdo concentra el acceso principal. En **pantallas pequeñas (móvil)** el menú está oculto por defecto: pulsa el icono de **hamburguesa** (☰) en la cabecera de la página para abrirlo. Toca fuera del menú, pulsa **Escape** o navega a otra sección para cerrarlo. En escritorio el menú permanece siempre visible.

Arriba del menú (**Buscar…**, **Notificaciones**) y debajo del selector de **pipeline activo**, las entradas se agrupan así.

Algunas entradas son **opcionales por workspace** y están **ocultas por defecto**. Un administrador puede activarlas en **Ajustes → Funcionalidades**: **Reports**, **Atribución**, **Puntuación de leads**, **Webhooks** y **Campos personalizados**.

**Uso diario** (siempre visibles, sin desplegable):

| Entrada | Descripción |
|---------|-------------|
| **Buscar…** | Búsqueda global. Atajo: `/` |
| **Notificaciones** | Avisos del workspace (menciones, alertas, formularios, reservas…) |
| **Panel** | Resumen del workspace |
| **Personas** | Contactos; puede incluir submenú de **vistas guardadas** |
| **Empresas** | Empresas; vistas guardadas |
| **Oportunidades** | Tablero kanban; vistas guardadas |
| **Tareas** | Todas las tareas del workspace |

**Marketing** (grupo desplegable; ver [§29](#29-marketing)):

| Entrada | Descripción |
|---------|-------------|
| **Suscripciones** | Tipos de lista y consentimiento |
| **Campañas** | Envíos masivos a segmentos |
| **Segmentos** | Audiencias filtradas |
| **Atribución** *(opcional)* | Informe UTM |
| **Recorridos** | Secuencias automatizadas |
| **Puntuación de leads** *(opcional)* | Reglas de scoring |
| **MQLs** | Pool de contactos con permiso de marketing |
| **Plantillas** | Plantillas de email (campañas, ficha, formularios) |

**Configuración** (solo **admins**; grupo desplegable):

| Entrada | Descripción |
|---------|-------------|
| **Equipo** | Miembros e invitaciones |
| **Productos** | Catálogo de productos |
| **Pipelines** | Etapas, disparadores, condiciones |
| **Campos personalizados** *(opcional)* | Campos personalizados |
| **Alertas** | Reglas de aviso por fechas |
| **Automatizaciones** | Automatizaciones por eventos |
| **Formularios** | Captación web pública |
| **Stripe** | Pagos importados y conciliación |
| **Webhooks** *(opcional)* | Integraciones salientes HTTP |
| **Informes** *(opcional)* | Informes y exportación CSV |
| **Ajustes** | Ajustes del workspace (OKM, Mailjet, permisos…) |

**Mi perfil** (grupo desplegable; cada usuario):

| Entrada | Descripción |
|---------|-------------|
| **Perfil** | Nombre, idioma, zona horaria, pipeline predeterminado, briefing IA, canales de alerta |
| **Gmail** | Conexión OAuth para enviar desde ficha y detectar respuestas |
| **Reservas** | Páginas públicas de reserva de calendario |
| **Mis listas** | Listas personales del workspace |
| **Tokens de API** | Tokens MCP / REST API v1 |

También puedes abrir **Perfil** pulsando tu **nombre** en la parte inferior del menú lateral.

Las entradas que dependen de funcionalidades desactivadas **no aparecen** hasta habilitarlas (ver [Próximamente](#30-próximamente)). Ejemplo hoy: **Mail merge**.

### Personalizar el menú

Junto al título **Menú** del menú lateral hay un icono de engranaje. Al pulsarlo entras en **modo edición**:

- **Reordenar:** arrastra un apartado por el icono de agarre (⋮⋮) a la posición que quieras.
- **Ocultar o mostrar:** usa el icono del ojo en cada apartado. Los ocultos dejan de verse en el menú normal, pero siguen visibles (atenuados) mientras editas para poder recuperarlos.

Los cambios se guardan automáticamente para **tu usuario** al salir del modo edición (vuelve a pulsar el engranaje). Cada persona del workspace tiene su propia configuración; no afecta a Buscar ni a Notificaciones. Puedes ocultar entradas de cualquier grupo (incluido Marketing o Mi perfil) sin borrarlas del workspace.

### Pipeline activo

Debajo del nombre del workspace, la barra lateral muestra el **pipeline activo**. Puedes elegir tu pipeline predeterminado para ese workspace en **Perfil**. Es el que se selecciona al iniciar sesión y al abrir el add-on de Gmail. Al cambiar el pipeline activo:

- **Deals** (tablero y tabla) filtran por ese pipeline.
- **Dashboard** y **Reports** usan ese pipeline como filtro por defecto en las métricas de deals.
- La opción **Todos los pipelines** quita el filtro de deals: el dashboard y los informes agrupan las etapas **por nombre** (una barra por etapa, con tramos apilados por pipeline; al pasar el cursor sobre cada tramo verás cuántos deals hay en ese pipeline), el tablero kanban muestra **una columna por nombre de etapa** (cada tarjeta indica su pipeline) y la vista tabla añade una columna **Pipeline**.

La selección se guarda por usuario y workspace, y se mantiene entre sesiones. También puedes cambiarla desde los selectores de Deals y Dashboard cuando hay varios pipelines.

### Tema claro y oscuro

En la parte inferior del menú lateral, junto a tu nombre, hay un botón que alterna el **tema** de la aplicación. Cada pulsación pasa al modo siguiente:

| Icono | Modo | Comportamiento |
|-------|------|----------------|
| ☀️ Sol | **Claro** | Siempre fondo claro |
| 🌙 Luna | **Oscuro** | Siempre fondo oscuro |
| 🖥️ Monitor | **Sistema** | Sigue automáticamente el tema del sistema operativo (por defecto) |

La preferencia se guarda en tu usuario, así que se mantiene entre sesiones y dispositivos. El cambio se aplica al instante, sin recargar la página.

---

## 4. Dashboard

El dashboard muestra un resumen del workspace:

- **Mis tareas:** tus tareas pendientes próximas, en el bloque principal del dashboard (marca completadas con un clic).
- **Director de ventas:** briefing diario generado por IA con indicaciones para el equipo, clasificadas en **Urgente** e **Importante**. Solo aparece en workspaces donde un administrador lo haya activado en **Settings** (checkbox *Briefing diario del director de ventas*), y además requiere que la IA esté configurada en el servidor (`CREAM_AI_API_KEY`). Cada usuario puede desactivarlo para sí en **Settings → Profile** (checkbox *Mostrar briefing del director de ventas en el dashboard*); también puedes abrir Profile desde tu nombre en la parte inferior del menú lateral. Para enriquecer el informe, el director usa herramientas de lectura del CRM, el **OKM** del workspace (si está configurado) y **memoria persistente** (llmemory) con aprendizajes de briefings anteriores. Además, cada usuario que lo tenga activado recibe un bloque **Para ti** con indicaciones directas, **Aciertos** (felicitaciones por logros recientes) y **A mejorar** (fallos u omisiones con recomendación). Si un deal ya tiene una **próxima acción** (tarea abierta con fecha futura), el briefing no pide acciones paralelas ni lo marca como inactivo; como mucho puede sugerir **adelantar** esa fecha. Los deals sin tarea abierta sí pueden aparecer como pendientes de definir siguiente paso. Si aún no hay briefing del día, puedes pulsar **Generar ahora**; si ya existe, puedes pulsar **Regenerar** hasta 5 veces al día (se muestra cuántas regeneraciones te quedan). Las indicaciones pueden enlazar a deals, personas, empresas o tareas; en el bloque de equipo se resaltan las asignadas a ti.
- **Tarjetas de métricas:** número de personas, empresas, valor del pipeline abierto y ingresos ganados (deals en etapa *won*). Las métricas de deals respetan el **pipeline activo** (ver abajo); personas y empresas son del workspace completo.
- **Pipeline por etapa:** barras con el reparto de deals por etapa. Si tienes un pipeline activo, el gráfico y las tarjetas de deals usan ese pipeline; si eliges **Todos los pipelines**, las tarjetas suman todos los deals y el gráfico agrupa las etapas por nombre con barras apiladas por pipeline (cada tramo muestra el recuento de ese pipeline al pasar el cursor).
- **Actividad reciente:** últimas acciones del equipo (creaciones, cambios de campo, cambios de etapa, etc.).

Haz clic en cualquier tarjeta o enlace para ir al listado correspondiente.

---

## 5. Personas, empresas y deals

Los tres tipos de registro comparten un patrón similar en la interfaz.

### Listados (tabla)

Cada listado incluye:

- **Búsqueda** por texto. En personas busca por nombre, email y cargo; en empresas por nombre, dominio e industria; en deals por el nombre del deal, **por el nombre de la empresa asociada** y por el **número de factura** (si está indicado).
- **Filtros** específicos por tipo de registro (ver tabla más abajo en [Deals → Filtros](#filtros-en-deals)).
- **Filtros por campos personalizados** cuando existen.
- **Columnas ordenables** (clic en la cabecera).
- **Columnas mágicas** y **campos personalizados** como columnas extra.
- Botones **New …** para crear un registro.

Haz clic en una fila para abrir la ficha del registro. **Cmd/Ctrl+clic** o **clic central** (rueda del ratón) abre la ficha en una pestaña nueva sin perder el listado.

El listado muestra **50 registros por página**. Cuando hay más, aparece una barra de paginación al pie con los botones **Anterior** / **Siguiente** y el indicador de página; al cambiar de página se conservan la búsqueda, los filtros y el orden activos. El contador junto al título refleja el total de registros, no solo los de la página actual.

**Persistencia durante la sesión:** si aplicas búsqueda o filtros y luego navegas a otra pantalla (por ejemplo, abres una ficha y vuelves al listado desde el menú lateral), Cream **recuerda los filtros activos y la página de paginación** mientras dures conectado. Al volver al listado se restauran automáticamente. Pulsa **Clear** (o la pestaña **All** en vistas guardadas) para volver al listado sin filtros. Esta memoria es **por sesión**: al cerrar sesión o iniciar una nueva, los filtros no se conservan (para guardarlos de forma permanente usa [vistas guardadas](#10-vistas-guardadas)).

### Personas

- Pueden vincularse a una **empresa**.
- Atributos habituales: nombre, email(s), teléfono, cargo, ubicación, propietario (*owner*).
- **Varios emails por contacto:** una persona puede tener más de una dirección (personal, trabajo, alias, etc.). En la ficha se listan todas; la marcada como **Principal** es la que se usa por defecto al enviar emails desde Cream y la que aparece en el listado. Para añadir, quitar o cambiar cuál es la principal, pulsa **Edit** en la ficha: la sección **Emails** permite añadir filas con **Add email**, marcar la principal y eliminar direcciones.
- La **búsqueda** de personas encuentra contactos si el término coincide con **cualquiera** de sus emails, no solo con el principal.
- En el listado puedes filtrar por **empresa** (*All companies*) y por **propietario** (*All owners*), además de la búsqueda y los campos personalizados.
- **Edición rápida en el listado:** haz **doble clic** en la celda **Company** o **Owner** para cambiar ese valor sin abrir la ficha. Aparece el mismo control que en el formulario de edición (buscador de empresa con opción **+ Create "…"**, o selector de propietario con **Unassigned**). Al elegir un valor se guarda al instante y la celda se actualiza; pulsa **Escape** para cancelar sin guardar. Un clic simple en el resto de la fila sigue abriendo la ficha.
- Al crear o editar una persona, el campo **Company** es un buscador: escribe parte del nombre (o dominio) y elige entre las sugerencias. Si el nombre no existe, aparece la opción **+ Create "…"** para crear la empresa al momento sin salir del formulario.
- Al crear o editar una persona, junto al campo **LinkedIn URL** aparece el botón **Buscar en LinkedIn**: abre la búsqueda de perfiles en LinkedIn en otra pestaña con el nombre y la empresa ya rellenados. Cuando encuentres el perfil correcto, copia su URL y pégala en **LinkedIn URL**.
- **Relaciones entre contactos:** en el panel izquierdo de la ficha, la sección **Relationships** permite vincular esta persona con otra del workspace. Elige la otra persona, el tipo de relación (**Invitó a**, **Referido por**, **Trabajó con**, **Colega de**) y pulsa **Add**. La relación se guarda con dirección: lo que declares desde la ficha actual es el origen (por ejemplo, «Ana invitó a Bruno»). En la ficha de Bruno verás la etiqueta inversa coherente («invitado por Ana»). Puedes eliminar la relación desde cualquiera de las dos fichas; desaparece en ambas.
- **Crear deal desde la ficha:** pulsa **Add deal** en la barra superior. Se abre un cuadro donde eliges el **pipeline** (por defecto el tuyo en *Settings → Profile*, o el del workspace si no tienes uno), el **producto** y la **primera acción** (título y fecha). El deal se crea en la **primera etapa** del pipeline elegido, con la empresa y el contacto de la persona; el nombre se genera como «Empresa — Producto». Tras crearlo irás a la ficha del deal. Si hay errores de validación, se muestran dentro del mismo cuadro sin salir de la ficha. Si no hay productos en el catálogo, el cuadro te indica que debes crear uno antes.
- **Oportunidades de la persona:** en la pestaña **Actividad**, la sección **Oportunidades** lista las oportunidades en las que la persona es contacto y que puedes ver, de la más reciente a la más antigua. Cada fila muestra el nombre (enlace a la ficha), la **etapa**, la fecha de creación y los **productos**. Ves las cinco primeras; el resto está en **Mostrar N oportunidades más**. Si hay más de cinco, **Ver oportunidades (N)** abre la pestaña **Oportunidades**, con la lista completa. Si esas oportunidades tienen más de un producto distinto, esa pestaña incluye el filtro **Todos los productos**.
- **Suscripciones** (marketing): si el workspace tiene activo el módulo de consentimiento, en el panel izquierdo verás cada **tipo de suscripción** (general, newsletter, etc.) con su estado (**Suscrito**, **Dado de baja** o **Pendiente**). Puedes **Suscribir** o **Dar de baja** manualmente, y copiar el enlace al **centro de preferencias** del contacto para que gestione sus listas (ver [§29](#29-marketing)).
- **Lead score** y **Lifecycle**: con la puntuación de leads activa, el panel izquierdo muestra la puntuación numérica y la etapa del ciclo de vida (*subscriber*, *lead*, *mql*, *sql*, *opportunity*, *customer*, *evangelist*). El lifecycle refleja la puntuación automática; **no** equivale a tener una oportunidad (deal) abierta en ventas.

**Posibles duplicados**

En el listado de **People**, el botón **Possible duplicates** abre un resumen de contactos con el **mismo email** en el workspace (aunque estén en empresas distintas). El número junto al botón indica cuántos grupos de duplicados hay.

1. Revisa cada grupo (email, empresas implicadas y contactos).
2. Pulsa **Review merge** para abrir el asistente de fusión.
3. El contacto más antiguo se propone como registro a conservar; puedes cambiar la selección en la pantalla de fusión.

**Fusionar contactos**

Desde la ficha de una persona, **Merge** abre el mismo asistente:

1. Arriba verás el contacto que se **conservará** (incluida su empresa).
2. Marca uno o más contactos sugeridos a fusionar: los de la **misma empresa** y, si el contacto tiene email(s), también otros contactos que compartan **alguna** de esas direcciones en otras empresas.
3. Si no aparece el contacto que buscas, usa el buscador **Search for other contacts** para encontrar y añadir **cualquier otro contacto del workspace**.
4. Confirma la acción.

Al fusionar, las notas, tareas, deals, emails y actividad del timeline de los contactos seleccionados pasan al contacto conservado. Las direcciones de email de los duplicados se unen en el contacto resultante (sin repetir la misma dirección). El contacto resultante **permanece en la empresa del contacto que conservas**. Los campos del contacto principal tienen prioridad; si faltan datos (teléfono, cargo, etc.), se rellenan con los del duplicado. La acción es **irreversible** y queda registrada en el timeline del contacto resultante.

### Empresas

- Atributos habituales: nombre, dominio, industria, tamaño, ubicación, propietario.
- Al crear o editar una empresa, junto al campo **LinkedIn URL** aparece el botón **Buscar en LinkedIn**: abre la búsqueda de empresas en LinkedIn en otra pestaña con el nombre ya rellenado. Cuando encuentres la página correcta, copia su URL y pégala en **LinkedIn URL**.
- Campo **Fiscal information**: caja de texto libre en el formulario de la empresa para anotar todos los datos fiscales (razón social, CIF/NIF, dirección fiscal, IBAN, etc.). Si está relleno, aparece como sección propia en el panel izquierdo de la ficha.

**Posibles duplicados**

En el listado de **Companies**, el botón **Possible duplicates** abre un resumen de empresas con **nombre similar** (p. ej. *Mapfre* y *Mapfre España*) o el **mismo dominio web**. El número junto al botón indica cuántos grupos de duplicados hay.

1. Revisa cada grupo (motivo de la sugerencia y empresas implicadas).
2. Pulsa **Review merge** para abrir el asistente de fusión.
3. La empresa más antigua se propone como registro a conservar; puedes cambiar la selección en la pantalla de fusión.

**Fusionar empresas**

Desde la ficha de una empresa, **Merge** abre el mismo asistente:

1. Arriba verás la empresa que se **conservará**.
2. Marca una o más empresas sugeridas como duplicadas que quieras fusionar en ella.
3. Confirma la acción.

Al fusionar, los contactos, deals, notas, tareas, emails y actividad del timeline de las empresas seleccionadas pasan a la empresa conservada. Si dos contactos tenían el mismo email, se fusionan automáticamente en uno. Los campos de la empresa principal tienen prioridad; si faltan datos (dominio, industria, etc.), se rellenan con los del duplicado. La acción es **irreversible** y queda registrada en el timeline de la empresa resultante.

### Deals

- Representan oportunidades de venta con **valor**, **moneda**, **etapa**, **probabilidad**, **fecha de cierre prevista**, **duración de la ejecución** (días, opcional) y, opcionalmente, **número de factura** (*Nº factura*). El valor se escribe con la cifra exacta (incluido céntimos) y se muestra igual en la **ficha**, la **tabla** y el **tablero**; si no hay céntimos, no se añaden ceros.
- Se asocian a una **empresa** y un **propietario**; los **contactos** son opcionales.
- Pueden incluir **líneas de producto** (productos del catálogo con cantidad y precio).
- Al **crear un deal** (`New deal`):
  - Elige **Pipeline** y **Stage** para decidir en qué etapa entra la oportunidad.
  - En **Company**, escribe para buscar la empresa y elige una sugerencia; si no existe, usa **+ Create "…"** para crearla al momento. Los **Contacts** son opcionales (puedes crear uno nuevo con **New** sin salir del formulario).
  - En el diálogo **New contact** puedes indicar **First name** (obligatorio), **Last name**, **Email**, **Phone**, **Contact source** (*Formulario web*, *Recomendado*, *Lo trae alguien del equipo*) y **First contact date**.
  - En **Products of interest** puedes añadir productos del catálogo con **Edition** (buscador con selección de una existente o **+ Create "…"**) y cantidad antes de guardar.
  - Debes definir una **Next action** (tarea con fecha futura) para poder crear el deal.
  - Opcionalmente puedes indicar **Duración de la ejecución (días)** y **Nº factura** si ya los tienes; también puedes añadirlos o cambiarlos al editar el deal.
- Tienen un **Version history** (historial de versiones) que guarda cada cambio de atributos del deal (valor, nombre, probabilidad, etc.) y permite consultar cómo estaba el deal en un momento concreto.
- Al **editar** un deal y guardar un cambio de etapa a **Won**, se muestra una breve animación de celebración en pantalla antes de volver a la ficha. Si la nueva etapa es **cerrada** pero no de ganancia (p. ej. *Lost*), se muestra una animación de derrota. Lo mismo ocurre al cambiar de etapa con los botones **Move to stage** de la ficha del deal. No ocurre al mover tarjetas en el tablero kanban. Si la etapa destino tiene **condiciones de entrada** que el deal no cumple, el cambio se rechaza, se muestra un aviso de error y el deal permanece en la etapa original.
- Desde la ficha de un deal puedes **Duplicar** el deal con un clic: se crea una copia con el mismo nombre más «(copia)», empresa, contactos, etapa, valor, moneda, probabilidad, fecha de cierre, duración de la ejecución, responsable, campos personalizados y tareas en curso. **No se copia el número de factura**. No se copian las líneas de producto, notas, adjuntos, emails ni el historial de actividad.
- En la ficha del deal, la sección **Colaboradores** permite al **Owner**, a un **Admin** o a un **Director comercial** añadir o quitar **vendedores** con acceso a ese deal. Un colaborador puede ver y editar el deal aunque no sea el propietario. Los vendedores que no son owner ni colaboradores no verán ese deal en listados, tablero ni dashboard.

### Filtros en deals {#filtros-en-deals}

En la **vista tabla** y en el **tablero kanban** puedes combinar varios filtros; al cambiar cualquier control, la lista se actualiza al instante. Pulsa **Clear** para quitar todos los filtros activos.

| Filtro (etiqueta en pantalla) | Vista tabla | Tablero | Qué hace |
|-------------------------------|:-----------:|:-------:|----------|
| **Search deals…** | sí | sí | Busca por nombre del deal, de la empresa o por número de factura |
| **All stages** | sí | no | Muestra solo deals en la etapa elegida (en el tablero no aplica: las columnas ya son etapas) |
| **All products** | sí | sí | Deals que incluyen ese producto en sus líneas |
| **All editions** | sí | sí | Deals con una línea que tenga esa edición concreta (el desplegable agrupa ediciones **por producto**; el mismo nombre puede existir en varios productos) |
| **First contact from / to** (campos de fecha) | sí | sí | Deals cuyo contacto tenga **First contact date** dentro del rango (si hay varios contactos, basta con que uno cumpla) |
| Campos personalizados | sí | no | Igual que en personas y empresas |

Los filtros activos se conservan al cambiar entre **Board** y **Table**, al paginar, al activar **Show closed** y al exportar CSV. También se pueden **guardar en una vista** (ver [§10](#10-vistas-guardadas)).

**Vistas del listado de deals:**

- **Board** (menú Deals): tablero kanban por etapas — arrastra tarjetas entre columnas para cambiar de etapa. Barra de filtros con búsqueda, producto, edición y rango de primer contacto, más pestañas de **vistas guardadas** (igual que en la tabla).
- **Table** (botón en el tablero): vista en tabla con los mismos filtros (incluida etapa), vistas guardadas, campos personalizados e importación/exportación CSV. Con **Todos los pipelines** activo, la tabla incluye una columna **Pipeline** antes de la etapa.

En el tablero, una vista guardada con filtro de **etapa** no restringe las columnas (las etapas ya son columnas); el resto de filtros sí se aplican.

---

## 6. Productos

El catálogo de **Products** guarda productos reutilizables al crear líneas en un deal. Desde la ficha de un deal — o al **crear un deal nuevo** — puedes añadir productos con cantidad, edición y precio unitario; el valor del deal puede reflejar esas líneas.

Cada producto puede marcarse con un **segmento** **B2B** o **B2C** al crearlo o editarlo. En el listado de productos puedes filtrar y ordenar por segmento.

En la página de edición de un producto, el botón **View deals** abre el listado de **Deals** (vista tabla) filtrado por ese producto e incluyendo deals cerrados. Desde ahí puedes refinar con los filtros habituales: edición, propietario, etapa, etc.

### Ediciones

Cada producto tiene **sus propias ediciones** (convocatorias o variantes). **No hay pestaña global de ediciones**: se gestionan dentro de cada producto.

1. Ve a **Products** y abre un producto (**Edit**).
2. En la sección **Editions** verás la tabla de ediciones (nombre, fechas, líneas en uso).
3. Pulsa **New edition** para crear una; edita o elimina desde la misma sección.
4. Cada edición tiene **nombre** y, opcionalmente, **fecha de inicio** y **fecha de fin**.

En las líneas de producto de un deal:

- El campo **Edition** es un **buscador** que solo muestra ediciones **del producto de esa línea**.
- Al **añadir** una línea nueva, primero elige el producto; entonces se habilita Edition y se cargan sus ediciones.
- Escribe para filtrar (las fechas aparecen junto al nombre), selecciona una o usa **+ Create "…"** para darla de alta al momento (queda ligada a ese producto).
- Las ediciones creadas al vuelo nacen sin fechas; complétalas después en la ficha del producto.

---

## 7. Tareas

Las tareas pueden crearse:

- Desde la sección **Tasks** del menú (vista global del workspace).
- Desde la ficha de una persona, empresa o deal.
- Al **crear un deal** nuevo, en el bloque «Next action (required)».

Cada tarea tiene **título**, **fecha límite**, **asignado** y estado **pendiente / completada**. Las tareas vencidas se muestran en rojo. En el dashboard y en Tasks puedes marcar una tarea como hecha con un clic.

### Mencionar y asignar con @

Al escribir el **título** de una tarea puedes mencionar a un compañero del workspace:

1. Escribe `@` en el campo de título.
2. Aparece un desplegable con los miembros del equipo; sigue escribiendo para filtrar por nombre o por el prefijo del email (p. ej. `@ana` para `ana@…`).
3. Elige con el ratón o con las flechas ↑↓ y **Enter** (o **Tab**).
4. Al guardar la tarea, **se asigna automáticamente** a la persona mencionada (si hay varias menciones, cuenta la primera). Si no mencionas a nadie, la tarea queda asignada a quien la crea.
5. La mención permanece en el título y se muestra **resaltada en color** en el listado, el dashboard y las fichas de registro.

> **Comentarios vs tareas:** en **Comments** puedes escribir `@nombre` a mano (sin desplegable) y recibirás una **notificación**. En **Tasks**, la mención con `@` incluye autocompletado y **asigna** la tarea, pero **aún no genera notificación**.

---

## 8. Listas

Las **listas** agrupan registros de un solo tipo (Person, Company o Deal) con un nombre y color. Están en el grupo **Mi perfil** → **Mis listas** (cada usuario ve las del workspace; el submenú despliega acceso rápido a cada lista).

- Crea una lista con el botón **+** junto a **Mis listas**.
- Añade o quita registros desde la ficha del registro o desde la vista de la lista.
- Los **recorridos** pueden incluir un paso **Añadir a lista** para meter contactos automáticamente.
- Para envíos masivos de email usa **Campañas** con un **segmento** ([§29](#29-marketing)); las listas del CRM son útiles para seguimiento manual y pasos de recorridos.

---

## 9. Pipelines y tablero kanban

Un **pipeline** define las **etapas** por las que pasa un deal (nombre, color y probabilidad de cierre).

### Gestionar pipelines

En **Pipelines** puedes:

- Crear un pipeline nuevo con sus etapas.
- Editar etapas, probabilidades y colores.
- **Reordenar etapas** arrastrando la fila por el asa (icono de puntos) al editar un pipeline; guarda los cambios con **Save changes**.
- Marcar un pipeline como **por defecto** (el que usan los deals nuevos).
- Elegir qué **campos visibles en las tarjetas del tablero** (checkboxes al editar el pipeline): valor, empresa, responsable, fecha de cierre, probabilidad, **duración de la ejecución**, **número de factura**, contactos, productos y ediciones. Por defecto: valor, empresa, fecha de cierre y responsable.
- **Duplicar** un pipeline (copia etapas y la selección de campos del tablero, no los deals).
- Crear desde **plantillas** predefinidas (Sales, Recruiting, etc.).
- Configurar **disparadores por etapa** (icono ⚡ junto a cada etapa guardada): acciones de IA o funciones predefinidas que se ejecutan al entrar un deal en la etapa — ver [Automatizaciones](#16-automatizaciones).
- Configurar **formatos de campos por etapa** (icono de ojo junto a cada etapa guardada): reglas que cambian cómo se **muestra** un campo del deal mientras está en esa etapa. Por ejemplo, mostrar «guest» en lugar de «0 €» cuando el precio es cero. Cada regla tiene: campo (precio, probabilidad o fecha de cierre), condición (*es igual a*, *es menor que*, *es mayor que* o *está vacío* con su valor) y el texto a mostrar. Gana la primera regla activa que coincida. Solo afecta a la presentación (ficha, tabla y tablero); el dato guardado no cambia, y los totales de columna del tablero siguen usando el valor real.
- Configurar **condiciones de entrada por etapa** (icono de candado junto a cada etapa guardada): reglas que **bloquean** pasar un deal a esa etapa hasta que se cumplan. Cada condición elige un campo (del deal, de su empresa o de sus contactos — incluidos campos personalizados), un operador (*es igual a*, *no es igual a*, comparaciones numéricas o de fecha, *contiene*, *está vacío* o *tiene valor*) y, salvo en vacío/presente, un valor de referencia. **Todas** las condiciones activas deben cumplirse. Para campos de **contacto**, basta con que **algún** contacto del deal cumpla la regla (excepto *está vacío*, que exige que ningún contacto tenga valor). Si intentas mover el deal sin cumplirlas — en el tablero, en la ficha o al editar — verás un aviso de error y el deal permanecerá en la etapa actual.

### Tablero kanban

En **Deals** (vista board):

- Cada columna es una etapa; la cabecera muestra probabilidad, número de deals y valor total.
- **En móvil**, el tablero muestra **una etapa a la vez**. Desliza el dedo hacia la izquierda o la derecha para pasar a la etapa siguiente o anterior. También puedes usar las flechas y el indicador «etapa X / N» bajo la cabecera.
- **Barra de filtros** bajo el título: búsqueda, producto, edición y rango de **First contact date**. No hay filtro por etapa (las columnas ya representan las etapas).
- **Arrastra** una tarjeta a otra columna para mover el deal de etapa. El cambio se guarda al instante y los contadores y totales de las columnas se actualizan solos, sin recargar la página. Si el movimiento no se puede guardar (p. ej. por condiciones de entrada de la etapa destino), la tarjeta vuelve a su columna de origen y aparece un **aviso de error** en la parte superior de la pantalla.
- **Reordena las columnas** arrastrando la cabecera de una etapa por el icono de puntos; el nuevo orden se guarda al soltar.
- Si hay varios pipelines, también puedes cambiar el pipeline activo desde el selector de la cabecera. Con **Todos los pipelines**, el tablero agrupa las columnas **por nombre de etapa** y cada tarjeta muestra el **pipeline** al que pertenece; al arrastrar un deal a otra columna, se mueve a la etapa homónima **dentro de su pipeline** (no cambia de pipeline).
- Las tarjetas con **tareas pendientes** muestran un icono de tarea en la esquina superior derecha: **rojo** si alguna tarea está vencida, **azul** si todas están al día o sin fecha límite. **Pasa el cursor** sobre el icono para ver la próxima tarea pendiente (título, fecha límite y asignado) sin abrir la ficha del deal; si hay varias pendientes, también indica cuántas quedan.
- Los campos visibles en cada tarjeta (valor, empresa, responsable, fecha de cierre, probabilidad, duración de la ejecución, número de factura, contactos, productos y ediciones) dependen de la configuración del pipeline activo — ver [Gestionar pipelines](#gestionar-pipelines).
- Desde la ficha de un deal también puedes cambiar etapa (botones **Move to stage**; el selector se actualiza al instante) o **mover a otro pipeline** (empezará en la primera etapa del pipeline destino).

### Etapas cerradas (won / lost)

Por defecto, las etapas marcadas como **cerradas** (p. ej. *Won* y *Lost*) **no se muestran**:

- En el **tablero board** no aparecen sus columnas.
- En el **listado (tabla)** no aparecen los deals que están en una etapa cerrada, y el filtro de etapa solo lista etapas abiertas.

Para verlas, pulsa **Show closed** en la cabecera de Deals (board o tabla). Al activarlo:

- El tablero añade las columnas de etapas cerradas.
- La tabla incluye los deals cerrados y el filtro de etapa lista también las etapas cerradas.

El estado se mantiene en la URL (`?closed=1`) mientras navegas, y vuelve a ocultarse al quitar el filtro.

---

## 10. Vistas guardadas

En los listados de **People**, **Companies** y **Deals** (tablero y tabla), las pestañas superiores permiten guardar combinaciones de filtros y orden:

1. Aplica búsqueda y filtros (en deals en el tablero: producto, edición y rango de primer contacto; en la tabla también etapa y campos personalizados).
2. Escribe un nombre en **View name**.
3. Marca **Shared** si quieres que todo el workspace la vea (si no, es personal).
4. Pulsa **Save view**.

Las vistas guardadas aparecen también como enlaces bajo la entrada correspondiente en el menú lateral. En **Deals**, esos enlaces abren el **tablero** con la vista activa.

Con una vista activa puedes **Update view** si cambias filtros, **Rename**, marcar como compartida o **Delete view**.

---

## 11. Campos personalizados

Esta sección está **oculta por defecto**. Un administrador debe activar **Campos personalizados** en **Ajustes → Funcionalidades** para ver la entrada en el menú y gestionar campos.

En **Custom fields** (solo admins) defines atributos extra por tipo de registro.

### Tipos disponibles

| Tipo          | Uso |
|---------------|-----|
| Text          | Texto corto |
| Long text     | Texto largo |
| Number        | Número |
| Currency      | Importe |
| Date          | Fecha |
| Boolean       | Sí / No |
| Select        | Una opción de una lista |
| Multi select  | Varias opciones |
| URL           | Enlace |
| Email         | Dirección de email |
| Record reference | Enlace a otra persona, empresa o deal del workspace |
| Formula       | Valor calculado automáticamente |

Los campos **Formula** evalúan una expresión sobre otros campos del mismo registro (p. ej. sumas o condiciones). No se editan a mano en la ficha.

Los campos **Record reference** enlazan el registro actual con otra persona, empresa o deal del mismo workspace. Al crear el campo eliges el tipo de objeto destino; en formularios y listados aparece un selector con los registros disponibles, y en la ficha el valor se muestra como enlace con avatar.

Los campos aparecen en formularios de creación/edición, en el panel de atributos de la ficha y como columnas/filtros en los listados.

---

## 12. Columnas mágicas

En las tablas de personas, empresas y deals, Cream añade columnas calculadas automáticamente:

| Columna        | Personas / Empresas / Deals | Descripción |
|----------------|----------------------------|-------------|
| Last activity  | Todos                      | Fecha de la última actividad registrada |
| Notes          | Todos                      | Número de notas |
| Tasks          | Todos                      | Número total de tareas |
| Open tasks     | Todos                      | Tareas pendientes |
| Days in stage  | Solo deals                 | Días en la etapa actual |

> Las columnas mágicas están disponibles en las **tablas** de listado; aún no en las tarjetas del tablero kanban.

---

## 13. Ficha de un registro

### Personas

La cabecera muestra el nombre, la empresa y los datos principales de contacto. Usa **Send email**, **Add note**, **Create task** o **Add deal** cuando lo necesites: los editores se abren bajo demanda. **Edit** abre el formulario de contacto agrupado; **Merge duplicates** y **Delete contact** están en el menú **•••**.

- **Actividad** se abre por defecto. En la columna principal verás, en este orden: **Oportunidades** (las que puedes ver, con etapa, fecha y productos; cinco visibles y el resto en **Mostrar N oportunidades más**; si hay más de cinco, **Ver oportunidades (N)** abre la pestaña), **Próximas tareas** (primero vencidas y después las próximas; despliega las restantes o completadas cuando lo necesites) e **Histórico** (notas, correos, comentarios, cambios del contacto y **cambios de etapa de sus oportunidades**). Un cambio de etapa se lee como «Ana movió la oportunidad Nombre de Propuesta a Negociación»; si la etapa es de ganancia, «Ana ganó la oportunidad Nombre». El nombre de la oportunidad es un enlace. Esos cambios aparecen en los filtros **Todo** y **Cambios**. Usa **Más antiguas / Más recientes** para paginar. En la columna de contexto, **Campañas enviadas** lista las últimas campañas de marketing recibidas por el contacto; **Recorridos** muestra las inscripciones (activas, en espera, completadas o canceladas) con el paso actual. **Ver más** abre el historial completo (ver [§29](#29-marketing)).
- **Oportunidades** contiene la lista completa y el filtro **Todos los productos** cuando hay más de un producto, además de intereses por producto y formularios enviados cuando están habilitados. Despliega **Registrar interés** para añadir un interés.
- **Information** agrupa contacto, perfil profesional, responsable, relaciones, campos personalizados, preferencias de correo y, si hay envíos, **Formularios enviados** (enlace **Ver consentimiento** a la política y la frase aceptadas). Cada bloque editable tiene su enlace **Edit**. Despliega **Add relationship** para vincular a otra persona.
- **Files**, cuando está habilitado, contiene el formulario de subida y los archivos adjuntos.

Cerrar un editor o cambiar de sección conserva el borrador mientras sigas en la página. Si intentas salir con borradores sin guardar, aparece un aviso. Los borradores no se conservan al recargar. Editar un bloque solo envía sus campos; **Save changes** vuelve a Information y **Cancel** deja el contacto sin cambios.

En móvil, usa las pestañas en una sola columna; los editores de nota, tarea, comentario y correo ocupan la pantalla. Las pestañas también admiten las flechas, Inicio y Fin, y puedes cerrar los editores con Escape.

### Empresas y deals

Al abrir una empresa o deal verás:

**Panel izquierdo (atributos):** datos principales, campos personalizados, relaciones entre contactos (solo personas), listas a las que pertenece y (en deals) selector de pipeline y etapa. En **personas**, según las funcionalidades activas, también pueden aparecer **Suscripciones**, **Lead score**, **Lifecycle**, **Intereses por producto** y **Formularios enviados** (ver [§29 Marketing](#29-marketing)).

> **En móvil** la ficha muestra un panel a la vez: desliza el dedo hacia la izquierda o la derecha para pasar del panel de atributos a la columna principal y viceversa.

**Columna principal:**

| Sección      | Descripción |
|--------------|-------------|
| **Colaboradores** | Solo en deals: vendedores con acceso compartido (ver sección [Deals](#deals)) |
| **Products** | Solo en deals: líneas de producto |
| **Notes**    | Notas de texto libre; quedan en el historial |
| **Comments** | Comentarios del equipo; menciona con `@nombre` escrito a mano (genera notificación) |
| **Attachments** | Archivos adjuntos al registro |
| **Send email** | Enviar email desde la ficha (ver [Email](#15-email-desde-registros)) |
| **Tasks**    | Tareas vinculadas al registro; al crear, usa `@` en el título para autocompletar y asignar a un compañero |
| **Timeline** | Historial automático: creación, cambios de campos (con diff), cambios de etapa, contactos, productos, notas, tareas, **fusiones de contactos**, **fusiones de empresas**, **emails enviados**, aperturas, clics y respuestas |

### Historial de versiones (solo deals)

Desde la ficha de un deal, el botón **Version history** abre el registro de cambios del deal:

1. Aparecen **cambios de campos** (valor, nombre, probabilidad…), **notas**, **comentarios**, cambios de **etapa**, **contactos**, **productos**, tareas completadas, etc., ordenados por fecha.
2. Las filas de cambios de campos son enlaces: pulsa una para ver el **snapshot** del deal en ese instante (valor, etapa, probabilidad, fecha de cierre, etc.).
3. Desde ahí puedes volver al deal actual o recorrer el resto del historial.

El **Timeline** en la ficha del deal muestra el mismo tipo de eventos (últimas 50 entradas); **Version history** reúne todo el historial consultable y permite reconstruir el estado del deal en una fecha concreta.

---

## 14. Importar y exportar CSV

En los listados de **People**, **Companies** y **Deals** (vista tabla):

- **Import:** sube un archivo CSV para crear registros en bloque.
- **Export:** descarga un CSV con los registros visibles según los filtros actuales (en deals incluye etapa, producto, edición y rango de primer contacto si los tienes activos).

Usa la exportación como referencia del formato esperado para importaciones.

---

## 15. Email desde registros

Desde la ficha de una **persona**, **empresa** o **deal**, la sección **Send email** te permite escribir y enviar un correo al contacto sin salir de Cream. Cada envío queda asociado al registro y al historial del equipo.

### Cómo acceder

En una persona, pulsa **Send email** en la cabecera. En una empresa o deal, baja a la sección **Send email** de la columna principal.

### Enviar un email

1. Rellena **To** (destinatario) y **Subject** (asunto). El cuerpo puedes escribirlo con **editor enriquecido** o con **HTML** (tablas, imágenes, documento completo). Si pasas de HTML al editor enriquecido y el contenido tiene etiquetas que no se conservan, verás un aviso y podrás cancelar.
2. Pulsa **Send email**.
3. El correo queda en el historial con la etiqueta **Sending** hasta que sale (desde la dirección del workspace por SMTP, o desde **tu Gmail** si lo tienes conectado). Cuando la entrega termina, la etiqueta pasa a **Sent**. Si el envío falla, la etiqueta es **Failed to send**: abre el correo y pulsa **Reintentar envío** para volver a mandarlo. Si falta el destinatario, el asunto o el cuerpo, Cream lo indica y el borrador sigue en el editor.
4. En el **Timeline** del registro aparece una entrada del tipo *«Tu nombre sent “Asunto” to destinatario@…»*.

En una persona, consulta los correos en **Histórico → Emails**, con asunto, estado y cuerpo desplegable; usa **Más antiguas / Más recientes** para paginar. En empresas y deals aparecen los **últimos 10 emails** debajo del formulario. Al desplegar un correo se ve el mensaje con su formato: saltos de línea, listas y el HTML del original. Ambas vistas incluyen envíos y, con Gmail, respuestas recibidas.

### Seguimiento de aperturas y clics

Los emails enviados incluyen seguimiento automático:

- Cuando el destinatario **abre** el mensaje, el email muestra la etiqueta **Opened** en la lista de enviados, queda registrado en el **Timeline** del registro y recibes una **notificación** de apertura.
- Cuando el destinatario **hace clic** en un enlace del mensaje, el clic se registra también en el **Timeline**.

> **Notas**
> - El envío usa la configuración de correo (SMTP) del servidor; el seguimiento necesita que la aplicación sea accesible desde Internet (ya configurado en producción).
> - Si **Send emails from records through Gmail** está activo, el correo sale desde tu Gmail y aparece en Enviados, también en desarrollo. Si no, en desarrollo el correo no se envía de verdad: aparece en **Mailbin** (`/mailbin`).
> - El seguimiento depende de que el cliente de correo del destinatario cargue las imágenes; si las bloquea, la apertura puede no detectarse.

### Programar el envío (Send later)

Puedes dejar un email preparado para que salga **más tarde**:

1. Escribe el correo (o insértalo desde una plantilla).
2. En **Send later**, elige fecha y hora.
3. Pulsa **Send email**. El correo queda **programado** y se enviará automáticamente a esa hora.

En la lista de correos del registro, los programados muestran la etiqueta **Scheduled** con su fecha/hora y un botón **Cancel** para cancelarlos antes de que salgan. Si dejas **Send later** vacío (o eliges una hora pasada), el correo se envía al instante.

### Recordatorio de seguimiento (Follow up)

Para que no se te olvide insistir si no te responden:

1. Al enviar, en **Follow up** elige un plazo (p. ej. *in 2 days*, *in 1 week*).
2. Pasado ese plazo, si **no has marcado el correo como respondido**, recibirás una **notificación** recordándote que hagas seguimiento.

En la lista de correos, los que tienen recordatorio pendiente muestran la etiqueta **Follow up \<fecha\>** y un botón **Mark replied**: púlsalo cuando el contacto responda y el recordatorio se cancela (queda como **Replied**). El plazo se cuenta desde el momento real de envío (también para correos programados).

### Quién ve los emails

Los correos que envías **desde la ficha de un cliente** (persona, empresa o deal) quedan guardados en ese registro. Cualquier **miembro del workspace** que pueda abrir la ficha ve:

- la lista de emails (enviados y **Received** si aplica): asunto, destinatario o remitente, cuerpo y etiquetas como **Sending**, **Sent**, **Opened**, **Replied** o **Received**
- la actividad relacionada en el **Timeline** (envíos, aperturas, clics, respuestas detectadas)

Lo mismo aplica a los envíos de **Campañas** (cada destinatario queda registrado en su ficha cuando el envío es trazable desde el CRM).

**No hay emails privados por usuario** dentro del mismo workspace: lo enviado desde una ficha forma parte del historial compartido del equipo sobre ese cliente. La visibilidad de **deals** depende del rol (ver [Roles](#roles)); personas y empresas siguen siendo visibles para todo el workspace.

| Qué | ¿Lo ven los demás miembros del workspace? |
|-----|-------------------------------------------|
| Email enviado desde la ficha del cliente | Sí |
| Estado **Opened**, **Replied**, **Follow up** | Sí |
| Actividad en el **Timeline** del registro | Sí — envío, apertura, clic, respuesta |
| Tu bandeja de Gmail personal | No |
| Correos enviados **fuera de Cream** | No |
| Texto completo de la respuesta del cliente (con **full reply logging**) | Sí — aparece como email **Received** en la ficha |
| Texto de respuesta sin permiso de cuerpo completo | No — solo queda marcado **Replied** |
| Datos de **otros workspaces** | No |

**Gmail conectado:** cada persona conecta **su propia** cuenta en **Gmail** (menú lateral). Cream **no** muestra la bandeja de un compañero. La detección de respuestas lee cabeceras de tu Gmail solo para marcar respuestas en registros donde **tú** enviaste el correo; el resultado (**Replied**, timeline) sí lo ve el equipo en la ficha del cliente.

### Gmail conectado

Si conectas tu cuenta en **Gmail** (menú lateral), puedes elegir el nivel de permisos:

- **Connect for sending only** — solo envío desde registros.
- **Connect for sending and reply detection** — envío + detección de respuestas (cabeceras del hilo).
- **Connect with full reply logging** — envío + detección + guardar el **texto** de las respuestas en la ficha.
- Si conectaste con menos permisos, **Enable reply detection** o **Enable full reply logging** amplían los permisos **sin desconectar**.

Al pulsar **Connect with full reply logging** (o **Enable full reply logging**), Google suele pedir **dos permisos**: *Enviar correo en tu nombre* y *Consultar tus mensajes y la configuración*. Es lo esperado: el segundo cubre la lectura necesaria para guardar el cuerpo de las respuestas.

> **Importante — texto de respuestas (Received):** si antes activaste solo la detección por cabeceras y luego el logging completo, Google puede mezclar permisos incompatibles. En **Gmail connection**, si ves un aviso en naranja, pulsa otra vez **Enable full reply logging**, acepta en Google y después **Sync now**. Sin ese paso puede aparecer **Replied** pero no el email **Received** con el texto.

Opciones tras conectar:

- **Send emails from records through Gmail** — los correos que envías desde una ficha salen desde tu dirección de Gmail y aparecen en tu carpeta Enviados.
- **Detect replies in your inbox** — Cream revisa los hilos de Gmail de los correos que enviaste. Cuando alguien responde, el email pasa a **Replied** automáticamente, se cancela el recordatorio de follow-up, recibes una **notificación** y queda registrado en el **Timeline**.
- **Enable full reply logging** (si aún no lo concediste al conectar) — re-autoriza con Google para leer el cuerpo de las respuestas y guardarlas en la ficha.
- **Sync now** — fuerza una sincronización inmediata (requiere permiso de lectura de bandeja); en producción también hay un sync automático periódico.

Cuando tienes **full reply logging** activo y la conexión es correcta, las respuestas del cliente aparecen en la lista de emails de la ficha con la etiqueta **Received**, el remitente en **From:** y el cuerpo expandible — visible para todo el workspace en esa ficha (ver [Quién ve los emails](#quién-ve-los-emails)).

### Add-on de Gmail (vincular hilos a deals)

Desde el **add-on de CReaM en Gmail** (barra lateral al abrir un correo) puedes:

1. **Authorize** — si Google aún no ha permitido a CReaM leer el hilo, acepta ese permiso. Después **Connect with CReaM** para autorizar con tu cuenta de CReaM (OAuth).
2. Si el hilo **ya está vinculado** a un deal, verás una **ficha del deal** con
   etapa, pipeline, empresa, valor, propietario, contactos, fecha de cierre,
   tareas pendientes y productos, además de un enlace **Open in CReaM**. Desde
   esa ficha puedes **Edit deal** (etapa, valor y fecha de cierre), **Add note**,
   **Add task** y **Edit task** (título, fecha y marcar completada) sin salir de
   Gmail. Para vincular otro deal o crear uno nuevo, pulsa **Link another deal**.
3. Si el hilo **aún no está vinculado**, elige el **Workspace** y **Pipeline** de
   destino (se propone el workspace **Example** y tu pipeline predeterminado).
   Los deals nuevos se crean en la primera etapa del pipeline.
4. **Vincular el hilo** a un deal existente (sugerencias y búsqueda limitadas al
   workspace seleccionado).
5. **Crear un deal nuevo** desde el hilo. Escribe el **nombre del deal** y la
   **empresa**. Si el dominio del correo (por ejemplo `ing.es`) coincide con
   una empresa, el add-on la **sugiere** para usarla. Si el nombre no existe,
   pregunta si la **crea** y guarda ese dominio en la empresa. Se importan
   todos los mensajes a su sección **Emails** y la tarjeta pasa a mostrar la
   ficha del deal.

Para instalarlo (usuarios):

1. Abre el enlace interno de **CReaM Gmail** que te facilite el administrador de Example,
   o entra en [Apps internas de Marketplace](https://workspace.google.com/marketplace/mydomainapps).
2. Pulsa **Instalar** y acepta los permisos de Gmail solicitados.
3. Abre Gmail, selecciona un hilo y pulsa el icono **CReaM** de la barra lateral derecha.
4. Si el add-on muestra **Authorize**, acepta el permiso de Gmail y vuelve a Gmail.
5. Pulsa **Connect with CReaM**, inicia sesión en `crm.example.com` y autoriza el acceso.

**Administradores de Example:** la guía completa para publicar el add-on en Marketplace,
instalarlo para todo el dominio y resolver incidencias está en
[`deploy/GMAIL_ADDON_SETUP.md`](deploy/GMAIL_ADDON_SETUP.md).

El add-on es privado para el dominio de Example. Cada persona conecta su propia
cuenta; no compartas enlaces de autorización ni tokens.

### Plantillas de email

Las **plantillas** te ahorran reescribir correos frecuentes (presentación, seguimiento, etc.).

- **Crear y gestionar:** entra en **Plantillas** desde el menú lateral. Cada plantilla tiene **nombre**, **asunto** y **cuerpo**, y puedes marcarla como **compartida** con todo el workspace o dejarla personal. El **cuerpo** puedes editarlo con **editor enriquecido** (negrita, cursiva, color, listas, enlaces, etc.) o con **HTML** (tablas, imágenes, documento completo). Si pasas de HTML al editor enriquecido y el contenido tiene etiquetas que Quill no conserva, verás un aviso y podrás cancelar antes de perder formato.
- **Layouts:** en la misma pantalla puedes crear **layouts** reutilizables (cabecera, pie, estilos). Un layout es HTML con `{{ content }}` o `{content}` donde se insertará el cuerpo de cada plantilla. Al crear o editar una plantilla, elige un layout opcional en el desplegable **Layout**.
- **Plantillas predefinidas (Example):** el workspace de organización incluye ocho plantillas del ciclo de curso (primer contacto, reserva confirmada, recordatorios de pago, cierre, etc.). Puedes editarlas desde **Plantillas** si eres administrador.
- **Variables:** usa `{first_name}`, `{last_name}`, `{name}`, `{company}` y `{email}` en el asunto o el cuerpo; al insertarlas se sustituyen por los datos del registro. Los textos entre corchetes como `[Nombre del curso]` o `[fechas]` son marcadores que debes completar manualmente tras cargar la plantilla.
- **Vista previa:** al crear o editar una plantilla o layout, y también al redactar un email en una ficha, verás un bloque **Vista previa** con variables opcionales (`{first_name}`, `{name}`, etc.). Déjalas vacías para usar valores de ejemplo o rellénalas para comprobar el resultado. Pulsa **Vista previa** para abrir el correo renderizado en una pestaña nueva (sin enviarlo).
- **Usar en un email:** en la sección **Send email** de una ficha (Person, Company o Deal), el desplegable empieza en **Sin plantilla**: escribes asunto y cuerpo tú. Si eliges una plantilla, el asunto y el cuerpo se rellenan con las variables ya sustituidas para ese contacto. Una plantilla HTML o con layout se abre en el modo **HTML** para no perder tablas ni el documento. Puedes volver a **Sin plantilla** para vaciarlos y redactar el correo a mano. Si aún no hay plantillas, verás un enlace para crearlas.

### Envío masivo

Para comunicaciones masivas con consentimiento y métricas usa **Campañas** + **Segmentos** ([§29](#29-marketing)): eliges audiencia, tipo de suscripción, plantilla, programación y prueba A/B.

> **Mail merge** (envío manual a vista guardada, lista o IDs) está **desactivado** en el menú; ver [Próximamente](#30-próximamente). Los envíos desde **Send email** en una ficha siguen disponibles registro a registro.

---

## 16. Automatizaciones

Las **automatizaciones** ejecutan una acción automáticamente cuando ocurre un evento, opcionalmente solo si se cumplen ciertas condiciones.

### Cómo acceder

Entrada **Automations** en el menú lateral; pulsa **New automation**.

### Configurar una automatización

1. **Name:** un nombre descriptivo.
2. **When this happens** — el evento que la dispara:
   - *Deal stage changed* — un deal cambia de etapa.
   - *Record created* — se crea una persona, empresa o deal.
   - *Task completed* — se completa una tarea.
3. **Only if** (opcional) — añade condiciones `campo = valor` que deben cumplirse para ejecutarse. Por ejemplo, en «deal cambia de etapa» puedes exigir `to = Won` (solo al pasar a esa etapa). Sin condiciones, se ejecuta siempre.
4. **Do this** — la acción:
   - *Create task* — crea una tarea (título y fecha límite) en el registro.
   - *Send email* — envía un email al registro (asunto y cuerpo); requiere que el registro tenga email.
   - *Notify Slack* — publica un mensaje en Slack.
5. Marca **Active** y guarda.

### Notas

- Las automatizaciones **inactivas** no se ejecutan.
- *Notify Slack* no hace nada hasta que se habilite la integración de Slack (ver [Próximamente](#30-próximamente)).

### Disparadores de etapa (IA)

Además de las automatizaciones, cada **etapa de un pipeline** puede tener **disparadores** que se ejecutan cuando un deal entra en ella (da igual si lo mueves en el kanban, con los botones de etapa de la ficha o editando el deal). A diferencia de las automatizaciones, sus acciones se muestran **en tu navegador**: una notificación breve (toast), un aviso modal, una confirmación con acción de seguimiento o un **panel informativo dentro de la ficha del deal**.

**Configurarlos:** en **Pipelines → editar pipeline**, cada etapa guardada muestra un icono de rayo (⚡) con el número de disparadores; púlsalo para gestionar los de esa etapa. Una etapa puede tener varios disparadores.

Cada disparador tiene un nombre, un interruptor **Activo** y un modo de ejecución:

- **Agente IA:** escribe una instrucción en lenguaje natural (p. ej. *«Resume el estado del deal y muéstralo en el panel; si el valor supera 10.000 €, avísame con un toast»*). La IA consulta el deal, su empresa y sus contactos (solo lectura, nunca modifica datos) y responde con las acciones de interfaz. Requiere que el asistente de IA esté configurado.
- **Función nativa:** elige una función predefinida del catálogo (p. ej. *Mostrar toast* o *Celebración de deal ganado*). No consume IA y funciona sin clave de API. Algunas funciones tienen **parámetros**: al elegirlas, el formulario muestra sus campos (p. ej. *Mostrar toast* pide el texto y el estilo del aviso). Los campos marcados con * son obligatorios.

**Historial:** pulsando el nombre de un disparador (o **Runs**) ves sus últimas ejecuciones, con estado, deal, duración, errores y el detalle de lo que hizo la IA.

Los avisos solo los ve **el usuario que movió el deal**; si el cambio de etapa lo hace una integración (API/MCP), la ejecución queda registrada en el historial sin mostrar nada en pantalla. El panel del deal queda guardado y visible en la ficha hasta que otro disparador lo sustituya.

---

## 17. Alertas configurables

Las **alertas** avisan automáticamente cuando se cumple una **fecha** (p. ej. fin de la edición de un producto en un deal) y, opcionalmente, **condiciones adicionales** sobre el deal o su empresa. Solo los **administradores** pueden crearlas y editarlas.

### Cómo acceder

Entrada **Alertas** en el menú lateral; pulsa **Nueva alerta**.

### Configurar una alerta

1. **Nombre:** texto descriptivo (aparece en la notificación).
2. **Campo de fecha:** cuándo evaluar la regla:
   - *Fin de edición* — alguna línea del deal con edición cuya fecha de fin se ha alcanzado.
   - *Inicio de edición* — fecha de inicio de la edición en una línea del deal.
   - *Fecha de cierre esperada del deal* — campo del deal.
3. **Desfase (días):** `0` = el mismo día; valores negativos avisan con antelación (p. ej. `-7` = una semana antes).
4. **Condiciones adicionales** (opcional; todas deben cumplirse): en la misma pantalla de creación o edición, pulsa **Añadir condición** y define reglas sobre campos del deal, la empresa o los contactos (mismo sistema que las condiciones de entrada a una etapa del pipeline: campo, operador y valor). Ejemplos habituales:
   - *Información fiscal de la empresa* → *está vacío*
   - *Abierto (no ganado ni perdido)* → *es igual a* → `true`
5. **Destinatario:** *Owner del deal* o *Administradores del workspace*.
6. Marca **Activa** y guarda.

### Canales de aviso (cada usuario)

En **Settings → Profile**, sección **Alertas**, cada miembro elige:

- **Notificación in-app (campana)** — activada por defecto.
- **Email** — desactivado por defecto.

Estos canales se usan para las **alertas** configuradas por el administrador, los **envíos de formularios** (el responsable) y las **reservas de calendario** (el anfitrión). Si desactivas ambos, no recibirás ninguno de esos avisos.

### Notas

- Cada regla avisa **una sola vez** por deal y destinatario; no se repite en días siguientes.
- Las alertas se evalúan **una vez al día** en el servidor.
- Las alertas aparecen en **Notifications** con enlace al deal.

---

## 18. Webhooks

Esta sección está **oculta por defecto**. Actívala en **Ajustes → Funcionalidades** para ver **Webhooks** en el menú.

En **Webhooks** configuras URLs que Cream llamará cuando ocurran eventos (p. ej. creación o cambio de un deal).

- **New webhook:** URL de destino y eventos suscritos.
- Puedes **activar/desactivar**, **editar** o **eliminar** cada webhook.

Útil para integrar Cream con otros sistemas (Zapier, scripts propios, etc.).

---

## 19. Notificaciones

**Notifications** en el menú lateral muestra avisos del workspace: menciones en **comentarios**, **alertas** configuradas por el administrador, leads de formularios, **reservas de calendario** (el anfitrión), etc. Las menciones en el título de una **tarea** asignan la tarea pero no generan aviso por ahora. Los avisos de **alertas**, **formularios** y **reservas** respetan tus canales en **Settings → Profile → Alertas** (campana y/o email).

- El contador en el menú indica notificaciones sin leer.
- **Mark read** en cada aviso o **Mark all read** para limpiar la bandeja.
- Si el aviso incluye enlace **View**, te lleva al registro relacionado.

---

## 20. Equipo e invitaciones

**Team** está disponible para todos los miembros del workspace. Usa el buscador para encontrar miembros por nombre o email; el listado está paginado.

### Para todos los miembros

- Consultar el listado de **Members** con nombre, email y rol de cada persona.

### Solo para admins

En **Team**, los administradores además pueden:

#### Invitar miembros

1. Email del compañero.
2. Rol: **Admin**, **Director comercial** o **Vendedor**.
3. **Send invitation** — se envía un email con enlace (o se muestra el enlace para copiar).

#### Gestionar miembros

- Cambiar el rol de un miembro (selector desplegable).
- Eliminar un miembro del workspace.
- Ver **Pending invitations**, reenviar o cancelar invitaciones.

Los invitados aceptan con el enlace recibido y crean cuenta o inician sesión si ya existen.

---

## 21. Ajustes del workspace

### Mi perfil (Profile)

Disponible para **todos los miembros** en **Perfil** (grupo **Mi perfil** del menú, o clic en tu nombre abajo del sidebar). Ajusta preferencias **personales en el workspace activo**:

1. **Datos personales** — tu **nombre** (visible en menciones y actividad), **idioma** (Español / English) y **zona horaria** (opcional). Si no eliges zona horaria, Cream usa la del workspace. Las fechas con hora (actividad, correos, etc.) se muestran en tu zona; los días de calendario (fecha límite de tarea, cierre previsto) no cambian. El email de cuenta es solo lectura.
2. **Pipeline predeterminado** — pipeline que se selecciona al iniciar sesión, en el selector del sidebar y en el add-on de Gmail ([§3](#3-navegación)).
3. **Briefing del director de ventas** — casilla para mostrar u ocultar el bloque de IA en el dashboard ([§4](#4-dashboard)). Solo aparece si el admin lo activó en **Settings** del workspace y la IA está configurada en el servidor.
4. **Alertas** — canales **Notificación in-app (campana)** y **Email** para alertas configuradas, **envíos de formularios** (si eres responsable) y **reservas de calendario** (si eres anfitrión). Si desactivas ambos, no recibirás esos avisos ([§17](#17-alertas-configurables), [§19](#19-notificaciones)).

### Ajustes del workspace (Settings)

En **Settings** (solo **admins**):

### General

- Cambiar el **nombre del workspace**.
- **Zona horaria del workspace** — predeterminada para miembros sin zona personal y para el «día de hoy» en alertas y briefings (por defecto `Europe/Madrid`).
- **Los vendedores pueden ver los deals de otros** — si está activo, los vendedores ven todos los deals del workspace en listados, tablero y ficha (no solo los propios ni los compartidos como colaboradores).
- **Los vendedores pueden editar los deals de otros** — si está activo, los vendedores pueden actualizar, mover y eliminar cualquier deal del workspace. Activar editar también permite ver esos deals.

Por defecto ambas opciones están desactivadas: los vendedores solo ven y editan sus propios deals y los que se les comparten explícitamente como colaboradores.

- **Briefing del director de ventas (IA)** — activa el briefing diario del equipo en el dashboard (requiere `CREAM_AI_API_KEY` en el servidor).

### Funcionalidades

Activa las secciones opcionales del menú y la configuración para este workspace (desactivadas por defecto):

- **Reports** — informes y exportación CSV.
- **Atribución** — informe UTM de campañas.
- **Puntuación de leads** — reglas de scoring y lifecycle en fichas de contacto.
- **Webhooks** — integraciones salientes HTTP.
- **Campos personalizados** — gestión de campos extra en personas, empresas y deals.
- **ID de medición GA4** (`G-…`) — propiedad de Google Analytics 4 de este workspace; lo usa el partial `{% google_analytics %}` en plantillas (p. ej. acuse de reserva). Si se deja vacío, el tag no inserta script.

### OKM

Conecta la base de conocimiento corporativa (Google Shared Drive) para el chat contextual y los briefings de IA:

1. Activa **Habilitar chat OKM en este workspace**.
2. Indica el **ID del Google Shared Drive** (desde la URL de Drive).
3. Pega el **JSON de la service account** con acceso de lectura a ese drive. Una vez guardado, el JSON no se vuelve a mostrar; se indica el email de la cuenta configurada. Deja el campo en blanco en ediciones posteriores para conservar la clave actual.

Cada workspace puede usar un drive y una service account distintos.

### Mailjet

Conecta la cuenta de Mailjet **de este workspace** para campañas y recorridos (solo admins):

1. En Mailjet, copia la **API Key** y la **Secret Key** (Account settings → SMTP and SEND API settings).
2. En **Settings**, sección **Mailjet**, pega las claves, el **email remitente** verificado en Mailjet y, si quieres, el nombre del remitente.
3. Si quieres que invitaciones, alertas, reservas, informes y emails de ficha salgan también por Mailjet, activa **Usar Mailjet para el correo transaccional**.
4. Pulsa **Conectar Mailjet**. Las claves no se vuelven a mostrar; deja los campos en blanco para conservarlas.
5. Al guardar, Cream registra automáticamente en Mailjet los eventos sent, open, click, bounce, spam, unsub y blocked (Version 2). La **URL del webhook** que aparece abajo es de referencia por si necesitas revisarla en Mailjet.

Cada workspace tiene su propia URL (incluye un token). Sin Mailjet conectado, las campañas usan SMTP/Mailbin. El correo transaccional usa Mailjet solo con la casilla activada; si no, SMTP/Mailbin.

- **Desconectar** elimina las credenciales de este workspace.

### Beehiiv

Sincroniza publicaciones de Beehiiv con tipos de suscripción de Cream (solo admins). Beehiiv sigue enviando cada newsletter; Cream refleja altas y bajas en el pool MQL. Cada publicación Beehiiv tiene su propia URL de webhook.

1. En Beehiiv, copia la **API Key** de la cuenta.
2. En **Settings**, sección **Beehiiv**, pega la clave y pulsa **Conectar Beehiiv** o **Guardar Beehiiv**. La API key no se vuelve a mostrar; deja el campo en blanco para conservarla.
3. En **Añadir publicación**, elige el **tipo de suscripción Cream** (p. ej. Newsletter), el **Publication ID** (`pub_…`) y, opcionalmente, el **Webhook signing secret** (`whsec_…`) de esa publicación en Beehiiv → Settings → Webhooks (plan Scale+).
4. Copia la **URL del webhook** de esa publicación y regístrala en Beehiiv con los eventos `subscription.created`, `subscription.confirmed` y `subscription.deleted`.
5. Repite los pasos 3–4 por cada publicación Beehiiv que quieras sincronizar (p. ej. otra newsletter o lista distinta).
6. Pulsa **Sincronizar ahora** para importar suscriptores existentes. La sync automática se repite cada hora si está activada.

**Bidireccional:** si alguien se suscribe o se da de baja en Cream de un tipo enlazado a Beehiiv (formulario, ficha de persona o centro de preferencias), el cambio se empuja a la publicación correspondiente. Los cambios originados en Beehiiv no se reenvían.

- **Desconectar** elimina la configuración de Beehiiv en este workspace (no borra personas ni suscripciones ya importadas).

---

## 22. Tokens de API y MCP

En **API tokens** generas tokens de acceso para conectar clientes **MCP** (Claude, Cursor y otros agentes IA) o la **API REST v1** a tu workspace.

### Cómo acceder

**Mi perfil → Tokens de API** en el menú lateral.

### Crear un token

1. En **Token name**, indica un nombre descriptivo (por ejemplo `My MCP client`).
2. Pulsa **Create token**.
3. Copia el valor de **Your new token (copy it now):** — se muestra **una sola vez**. Empieza por `cream_`.
4. Guárdalo en un sitio seguro. No lo compartas ni lo pegues en chats públicos.

Cada token está ligado a **tu usuario** y al **workspace activo** cuando lo creaste. El agente verá y podrá cambiar solo lo que tú puedes en ese workspace.

**Revoke token** (icono papelera) invalida un token. Úsalo si se ha filtrado o ya no usas ese cliente.

### Conectar un cliente MCP

La dirección del servidor MCP es la URL de Cream seguida de `/mcp`. Si entras a Cream en `https://tu-dominio/`, la ruta es:

```
https://tu-dominio/mcp
```

En desarrollo local suele ser `http://localhost:3030/mcp`.

#### Con token de API (recomendado)

1. Crea un token como arriba y cópialo.
2. En el cliente (Cursor, Claude Desktop, etc.) añade un servidor MCP remoto con esa URL y el token en la cabecera de autorización.

Ejemplo para Cursor (`~/.cursor/mcp.json` o `.cursor/mcp.json` del proyecto):

```json
{
  "mcpServers": {
    "cream": {
      "url": "https://tu-dominio/mcp",
      "headers": {
        "Authorization": "Bearer cream_TU_TOKEN"
      }
    }
  }
}
```

Sustituye `https://tu-dominio/mcp` por la URL de tu instancia y `cream_TU_TOKEN` por el valor copiado.

En Claude Desktop la configuración es la misma (`mcpServers` en el fichero de ajustes de Claude).

3. Recarga los servidores MCP o reinicia el cliente. Deberías ver las herramientas de Cream (listar deals, crear tareas, resumir fichas, etc.).

#### Sin pegar el token (inicio de sesión)

Algunos clientes pueden conectarse **solo con la URL** (`https://tu-dominio/mcp`). Te pedirán iniciar sesión en Cream y autorizar el acceso. El token de API no hace falta en ese caso.

### Notas

- El token da el mismo acceso que tu usuario en ese workspace. Trátalo como una contraseña.
- Si cambias de workspace, crea un token nuevo con ese workspace activo.
- Las herramientas de IA del MCP (`summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search`, `enrich_record`) requieren que el asistente IA esté habilitado; ver [Asistente IA](#24-asistente-ia).

---

## 23. Reports

Esta sección está **oculta por defecto**. Actívala en **Ajustes → Funcionalidades** para ver **Reports** en el menú.

Los **informes** te dejan medir tu actividad combinando una métrica, un agrupamiento y un periodo, y guardar las combinaciones que más uses.

### Cómo acceder

Entrada **Reports** en el menú lateral (si está activa en **Ajustes → Funcionalidades**).

### Construir un informe

1. **Record** — sobre qué datos: *Deal*, *Person* o *Company*.
2. **Measure** — qué medir: *Count* (recuento) y, para deals, *Total value* o *Average value*.
3. **Group by** — cómo agrupar: por etapa, propietario, empresa, industria o mes de creación (las opciones se ajustan al tipo elegido).
4. **Period** — *All time*, este mes, trimestre o año.

El informe se recalcula al momento y se muestra como tabla con barras y un total.

### Guardar y reutilizar

Escribe un nombre y pulsa **Save** para guardar la combinación actual. Los informes guardados aparecen al final de la página: ábrelos con un clic o elimínalos con **Delete**.

### Exportar a CSV

Pulsa **Export CSV** para descargar el informe actual (etiqueta y valor de cada fila) como archivo CSV.

### Envío por email programado

Puedes recibir un informe por email de forma periódica:

- Al **guardar**, elige en el selector *Email daily / weekly / monthly* (o *Don't email*).
- En cada informe guardado, el desplegable de periodicidad te deja **cambiarlo** en cualquier momento (*Not emailed / Daily / Weekly / Monthly*).

Cream te enviará el informe por correo según esa frecuencia. *(El envío programado se ejecuta en producción; en desarrollo puedes probar el correo desde Mailbin.)*

---

## 24. Asistente IA

Cuando el asistente IA está habilitado y configurado (`CREAM_AI_API_KEY`), puedes usarlo en las fichas de **personas**, **empresas** y **deals**, y también vía MCP/API.

### En la ficha de un registro

En la parte superior de la columna principal verás la sección **AI Assistant**:

| Acción | Qué hace |
|--------|----------|
| **Summarize** | Resume el registro usando notas, comentarios, emails, tareas y actividad reciente. Muestra riesgos, próximos pasos y datos faltantes. |
| **Next steps** | Propone acciones concretas. Las sugerencias de tipo tarea incluyen un botón **Create task**. |
| **Draft email** | Genera un borrador de asunto y cuerpo e inserta el texto en el compositor **Send email** (no envía automáticamente). |
| **Suggest fields** | Sugiere mejoras en campos del registro a partir del contexto existente (sin datos externos). |

Opcionalmente puedes indicar un **Email goal** antes de generar un borrador (p. ej. «Follow up after demo»).

> **Notas**
> - Las generaciones descartadas no se guardan en el registro.
> - Si aceptas una sugerencia de tarea, queda registrada en el **Timeline** como tarea sugerida por IA.
> - Requiere un proveedor compatible con la OpenAI Responses API (`CREAM_AI_API_KEY`; por defecto `https://api.openai.com/v1/responses`).

### Búsqueda natural

En **`/ai_search`** puedes usar frases como:

- `stalled deals` — deals abiertos llevan 7+ días en la misma etapa
- `overdue tasks` — tareas vencidas pendientes
- `pending follow up` — emails con recordatorio de seguimiento activo
- `won deals` — deals ganados
- `no contact` — registros sin actividad en 14 días

Si la frase no coincide con un patrón conocido, se usa búsqueda por palabras clave.

### MCP / integraciones

Las herramientas MCP `summarize_record`, `suggest_next_steps`, `draft_email`, `natural_language_search` y `enrich_record` reutilizan la misma lógica que la interfaz.

---

## 25. Chat de conocimiento

En el workspace **Example** (cuando está habilitado y configurado en el servidor), verás un **botón flotante de chat** en la esquina inferior derecha de cualquier pantalla.

### Qué hace

El chat es un **asistente con agente** que combina:

- El **contexto de la página** en la que estás (si aplica).
- El **conocimiento corporativo OKM** de Example (clientes, ventas, estrategia, empresas y personas en Google Drive).
- Los **datos del CRM** (búsqueda de registros, tareas, pipeline).
- **Memoria persistente** de preferencias y hechos relevantes entre conversaciones.

Además, puede **proponer cambios en Cream** (crear tareas, añadir notas, actualizar registros, mover deals, completar tareas). Esos cambios **no se aplican solos**: el chat muestra una tarjeta de confirmación y debes pulsar **Confirmar** para ejecutarlos.

### Contexto según la página

| Página | Contexto que usa |
|--------|------------------|
| **Empresa** | Ficha CRM de la empresa + búsqueda en OKM por ese cliente |
| **Persona** | Ficha de la persona, su empresa y material relacionado en OKM |
| **Deal** | Ficha del deal, empresa, contactos y material de ventas en OKM |
| **Resto** (dashboard, listados, etc.) | Conocimiento general de Example según tu pregunta |

La cabecera del panel indica el contexto activo (p. ej. *Contexto: Acme Corp*) o *Conocimiento general de Example* si no hay registro asociado.

### Uso

1. Pulsa el botón de chat para abrir el panel.
2. Escribe tu pregunta y pulsa **Enviar** (o Enter).
3. El asistente responde usando el CRM, el OKM y la memoria guardada.
4. Si propone una acción en Cream, aparecerá una tarjeta con **Confirmar** / **Cancelar**.
5. **Nueva** borra la conversación actual.
6. Puedes **expandir** el panel a pantalla completa con el icono de la cabecera.
7. La conversación se conserva al navegar entre páginas (misma sesión del navegador); al recargar la pestaña se pierde.

### Requisitos

- Workspace con **chat OKM** activado en **Settings** y configuración OKM válida (ID del Shared Drive + service account).
- `CREAM_AI_API_KEY` configurada en el servidor.
- Base de datos con extensión **pgvector** (para memoria del agente con llmemory).

---

## 26. Pagos de Stripe

Si tu organización cobra a través de Stripe (por ejemplo desde otra aplicación), Cream puede importar esos pagos y ayudarte a **conciliarlos con tus deals**: cada pago se relaciona con un deal existente o te propone crear uno nuevo.

### Cómo acceder

Menú lateral → **Stripe**. Se abre la bandeja de pagos; desde ahí, el botón **Stripe settings** lleva a la configuración de la conexión.

### Conectar Stripe (solo admins)

1. En el panel de Stripe crea una **restricted key** con permiso de solo lectura sobre *Charges* (recomendado frente a la secret key completa).
2. En **Stripe settings**, pega la key en **API key**, pon una etiqueta si quieres y pulsa **Connect Stripe**. Cream valida la key contra Stripe antes de guardarla.
3. Activa **Import new payments automatically** para que los pagos nuevos se importen cada 15 minutos, o usa **Sync now** en cualquier momento. La primera sincronización trae todo el histórico de pagos.

Si una sincronización falla (por ejemplo, key revocada), el error aparece en la página de configuración. **Disconnect** elimina la conexión y los pagos importados (las actividades ya anotadas en los deals se conservan).

### La bandeja de pagos

La página **Stripe payments** tiene tres pestañas:

| Pestaña | Contenido |
|---------|-----------|
| **To review** | Pagos pendientes de conciliar |
| **Matched** | Pagos ya vinculados a un deal |
| **Ignored** | Pagos descartados (se pueden recuperar con **Restore**) |

Cada fila muestra fecha, importe, cliente (nombre y email), descripción y la **sugerencia de deal** con su nivel de confianza. Al hacer clic en una fila se abre el **detalle del pago**, con toda la información que Stripe proporciona: teléfono y dirección de facturación, método de pago (tarjeta con marca y últimos 4 dígitos, Bizum, Link…), resultado del control de riesgo, la metadata del pago, un enlace al **recibo de Stripe** y un desplegable «Full Stripe data» con el objeto completo tal como lo devuelve Stripe. Desde el detalle también puedes conciliar, ignorar o crear el deal.

Niveles de confianza de la sugerencia:

- **high** — el pago trae la referencia del deal en la metadata, o el importe y la moneda coinciden con un único deal (abierto o ganado; en caso de empate gana el abierto) de esa persona.
- **medium** — la persona tiene un único deal candidato (abierto o ganado), pero el importe no coincide.
- **low** — se identificó a la persona pero hay varios deals candidatos (o ninguno). Los deals perdidos nunca se sugieren.
- Sin sugerencia — el email del pago no corresponde a ninguna persona del CRM.

### Conciliar un pago

Para cada pago pendiente puedes:

- **Accept** — aceptar el deal sugerido.
- **Search deal…** — buscador con autocompletado para vincular a mano: escribe parte del nombre del deal o de la empresa y elige entre los resultados (deals **abiertos y ganados**; los perdidos no aparecen). Al elegir uno se activa el botón **Link**.
- **Create deal** — abre el formulario de nuevo deal ya prefijado con los datos del pago (nombre, empresa y contacto si se identificó a la persona); al guardarlo, el pago queda vinculado automáticamente.
- **Ignore** — descartar el pago (propinas, pagos de prueba, etc.).

Al conciliar, el deal registra en su timeline la actividad de **pago recibido** con el importe. Cream no cambia la etapa del deal automáticamente: si el pago cierra la venta, muévelo tú a la etapa ganadora.

### Notas

- Ver la bandeja y conciliar pagos está al alcance de cualquier miembro; configurar la conexión es de **admins**.
- Para que el match sea infalible, la aplicación que cobra puede escribir el id del deal en la metadata del pago de Stripe con la clave `cream_deal_id`.
- Los reembolsos hechos **después** de importar un pago no se reflejan; solo se marca *Refunded* si el pago ya estaba reembolsado al importarlo.

---

## 27. Formularios de captación

Los **formularios de captación** permiten recibir leads desde páginas externas. Cada formulario es una página pública de Cream que puedes enlazar o embeber en un `<iframe>`.

### Cómo acceder

En el menú lateral, abre **Formularios**.

### Configurar un formulario

1. Pulsa **Nuevo formulario**.
2. Indica el **nombre**, el **slug** (aparecerá en la URL pública `/f/slug`), la **plantilla** del formulario y si el formulario está **Activo**.
3. En **Destino del envío**, elige **Deal (ventas)** o **MQL (marketing)**. Deal crea o reutiliza una oportunidad (flujo descrito abajo). MQL captura persona, consentimiento e historial de envíos **sin crear deal** (ver [§29 Pool MQL](#pool-mql)). Para destino MQL puedes indicar el **tipo de suscripción** (define la clave del checkbox esperada) y el **texto de permiso de marketing** que sobrescribe la etiqueta por defecto del tipo. Cream avisa si la plantilla del formulario no incluye ese campo.
4. En **CRM y asignación** (solo destino Deal): el **pipeline** donde se creará el deal, la **etapa** opcional, el **responsable** (recibe la notificación y la tarea de seguimiento), el **producto** opcional y rutas de pipeline por valor de campo.
5. Configura la **primera tarea** (texto y días hasta vencimiento; 0 = el mismo día) y la **plantilla de email** al lead (o **Sin email**).
6. Opcional: indica la **URL de redirección tras envío** (p. ej. `https://entaina.com/gracias`) para llevar al visitante a una página de tu web. Si se deja vacía, se muestra la página de gracias de Cream (`/f/slug/success`).
7. Opcional: define **campos ocultos adicionales** (uno por línea, p. ej. `producto`, `landing`). Sus valores se pasan como query params en la URL pública o del iframe, p. ej. `/f/slug?producto=curso-ia`. Se guardan con el envío y aparecen en **Formulario de origen** del deal o en el historial del contacto.
8. Marca **Recoger datos de empresa** si el formulario debe pedir nombre y CIF de la empresa. Con esta opción, un envío sin nombre de empresa sigue aceptándose en servidor (se usa una empresa placeholder); marca el campo `required: true` en la plantilla si quieres exigirlo en el navegador.
9. Opcional: marca **Exigir email corporativo** en lead magnets u otros formularios donde quieras rechazar correos personales (Gmail, Hotmail, Yahoo, Outlook, iCloud, etc.). El visitante verá un aviso y no podrá enviar hasta usar un email de dominio que no esté en la lista de proveedores gratuitos. Cream no comprueba que la empresa exista; solo descarta dominios conocidos de correo personal.
10. Guarda. En el listado verás la **URL pública**, la **política de privacidad** (`/f/slug/privacy`) y el **código iframe** listos para copiar.

### Ficha del formulario (Ver)

Desde el listado, **Ver** abre el detalle del formulario:

- Badge **Destino Deal** o **Destino MQL** y enlace a la URL pública.
- **MQL captados** — personas que enviaron con destino MQL desde este formulario: número de envíos, primera y última captura, y si son **elegibles** ahora para marketing.
- **Envíos recientes** — todos los envíos (Deal o MQL) con enlace **Detalle** al registro completo del envío, incluido el bloque **Consentimiento aceptado** (política, hash y textos versionados).

### Plantillas de formulario (administradores)

La **apariencia y los campos** de cada página pública se definen en plantillas **Liquid** guardadas en el workspace, no en el propio registro del formulario.

1. Desde **Formularios**, pulsa **Plantillas de formulario** (solo administradores).
2. Filtra por **Páginas** (formularios completos), **Reservas** (acuse tras confirmar una cita en `/b/…`), **Parciales** (bloques reutilizables: contacto, consentimiento RGPD, analítica…) o **Landing page** (páginas de marketing en `/p/slug-workspace/slug-landing`; ver [§29](#29-marketing)). Cada workspace guarda sus propias plantillas en la base de datos; no dependen del código fuente del servidor.
3. **Editar** abre un editor con resaltado Liquid. Las páginas de formulario usan etiquetas como `{% field %}`, `{% partial 'contact_fields' %}`, `{% form_open %}` y variables como `{{ lead_form.name }}`. Las plantillas de **acuse de reserva** pueden usar `{% partial 'google_analytics' %}` (o `{% google_analytics %}`) para medición en GA4 si el workspace tiene configurado el **ID de medición GA4** en **Settings → Workspace** ([§21](#21-ajustes-del-workspace)); la variable `{{ evento }}` lleva el slug del tipo de cita (sin datos personales).
4. **Nueva plantilla**: indica un **nombre** corto, el **tipo** (formulario de lead, acuse de reserva o landing) y, si aplica, marca **Es un parcial**.
5. Tras crear o cambiar una plantilla de **página** de formulario, elige ese nombre en **Plantilla del formulario** al configurar un formulario de captación. La plantilla `privacy` define la política enlazada desde cada formulario público. Las plantillas de tipo **acuse de reserva** se eligen en **Reservas** ([§28](#28-reservas-de-calendario)).

Si la plantilla de una página no existe en el workspace, la URL pública `/f/slug` responderá con error.

### Política de privacidad y consentimiento

- Cada formulario público incluye un enlace a la **política de privacidad** (`/f/slug/privacy`). El contenido se define en **Plantillas de formulario** → plantilla `privacy` (editable por administradores).
- El visitante debe marcar la casilla de **consentimiento de protección de datos** (RGPD) para enviar. Opcionalmente la plantilla puede incluir casillas de marketing con `{% subscription_opt_in slug: "newsletter" %}` (u otro slug de tipo de suscripción); si el contacto las acepta, se registra la suscripción al tipo cuya **clave de checkbox** coincida (ver [§29](#29-marketing)). También puedes añadir `{% subscription_opt_in_all %}` (o el parcial `subscribe_all_opt_in`) para ofrecer **suscribirse a todos los tipos activos** del workspace con un solo checkbox (`lead[subscribe_all]`).
- Al cargar el formulario, Cream guarda una **versión inmutable** de la política y de la frase del checkbox. Cada envío queda enlazado a esa versión (fecha, URL, hash y textos aceptados). El detalle completo se consulta con **Ver consentimiento** desde la ficha del contacto (**Information** → **Formularios enviados**), desde el deal (**Information** → **Formulario de origen**), desde **MQLs** (columna Formularios) o en **Formularios → Ver → Envíos recientes → Detalle**. En el deal, al desplegar el envío también aparece el bloque **Consentimiento aceptado**.

### Qué ocurre al enviar un formulario (destino Deal)

- Se crea o reutiliza una **persona** por email (origen «Formulario web»). Si la persona ya existía, solo se rellenan los campos que estuvieran vacíos (nombre, apellidos, teléfono, cargo…).
- Si esa persona ya tiene un **deal abierto** en el pipeline del formulario, se **reutiliza** ese deal: se añaden al envío los datos nuevos del formulario (sin crear otro deal ni otra tarea de seguimiento). Si has configurado una **etapa**, el deal avanza hasta ella solo si está en una etapa anterior (nunca retrocede). Si no hay deal abierto en ese pipeline (por ejemplo, solo deals ganados o perdidos, o deals en otro pipeline), se crea un deal nuevo en la etapa configurada o, si no hay etapa, en la **primera etapa** del pipeline, con la **primera tarea** configurada en el formulario (por defecto «Contactar lead» al día siguiente) asignada al responsable.
- Los datos del envío (campos del formulario, página de origen, UTM, navegador, IP…) quedan guardados y visibles en la ficha del deal, en **Formulario de origen**.
- El lead recibe el email configurado; el responsable recibe aviso según sus canales en **Settings → Profile → Alertas** (campana y/o email), con los datos y un enlace al deal.

### Qué ocurre al enviar un formulario (destino MQL)

- Se crea o actualiza la **persona** y se guarda el **envío** con destino MQL (sin deal).
- Si el visitante acepta el permiso de marketing configurado en el formulario, se crea o actualiza la **suscripción** al tipo elegido, con trazabilidad de la misma versión de política que el envío.
- El historial de envíos e intereses por producto aparece en la ficha del contacto. Desde ahí puedes **Convertir a SQL** cuando haya interés comercial (ver [§29](#29-marketing)).

### Notas

- Los formularios inactivos no aceptan envíos.
- Si la etapa configurada tiene **condiciones de entrada** y el deal no las cumple, se queda en su etapa actual y el envío se guarda igualmente.
- Si el formulario no pide empresa, la persona se asocia a la empresa genérica **Particulares** del workspace (salvo que ya existiera con otra empresa).
**Formularios de ejemplo (solo workspace de demo tras `db:seed`):**

- **Contacto** (`/f/contacto`) — contacto estándar, tipo de ayuda, mensaje, newsletter opcional y RGPD; enruta deals por `help_type`.
- **Solicitar demo** (`/f/demo`) — contacto + empresa (si el formulario recoge empresa), mensaje y newsletter opcional.
- **Newsletter** (`/f/newsletter`) — captación mínima con suscripción opcional.
- **Reserva** (`/f/reserva`) — edición de producto, contacto, mensaje y RGPD (patrón de reserva con ediciones abiertas).

En un workspace real, los administradores crean y editan plantillas en **Formularios → Plantillas de formulario**; no hay lista fija en el servidor.
- Cualquier miembro del workspace puede gestionar los formularios; **editar plantillas Liquid** es solo para administradores.

---

## 28. Reservas de calendario

Las **reservas de calendario** permiten ofrecer una experiencia tipo Calendly en una página pública de Cream: el visitante elige un tipo de reunión, consulta huecos reales en Google Calendar, reserva y recibe invitación por email (con Google Meet si aplica).

### Conectar Google Calendar

En el menú lateral, abre **Reservas** y pulsa **Conectar Google Calendar** (o **Google Calendar** si ya estás conectado). Autoriza el acceso a calendario (`calendar.readonly` y `calendar.events`). Cada anfitrión conecta su propia cuenta; las citas se crean en su calendario.

Si cambian los permisos en Google o dejan de cargarse tus calendarios, entra en **Google Calendar** desde Reservas y pulsa **Reconectar Google Calendar** (o **Actualizar permisos** si falta algún permiso). No hace falta desconectar la cuenta.

**Google Cloud (administrador):** en el mismo proyecto OAuth que usa Gmail, activa también la **Google Calendar API** (`calendar-json.googleapis.com`). Sin eso, la conexión OAuth puede completarse pero fallará al listar calendarios.

### Configurar una página pública

Toda la configuración se hace desde **Reservas** (no hace falta usar seeds ni datos precargados).

**Página pública**

| Campo | Descripción |
|-------|-------------|
| Nombre | Título interno de la página |
| Slug | Identificador en la URL pública (`/b/slug`) |
| Anfitrión | Usuario cuyo Google Calendar consulta disponibilidad y recibe las citas |
| Pipeline CRM | Pipeline donde se crean persona y deal al reservar |
| Reutilizar deal existente | Si la persona ya tiene un deal en la primera etapa de este pipeline, la reserva se asocia a ese deal; si no, se crea uno nuevo |
| Mensaje de bienvenida | Texto en la cabecera de la página pública |
| Avatar URL / Logo URL | Imágenes opcionales del perfil |
| Zona horaria | Zona de las **franjas horarias** del anfitrión. Quien reserva ve los huecos convertidos a su zona; Google Calendar guarda el mismo instante. |
| Ventana de reserva (días) | Cuántos días hacia adelante se pueden elegir fechas |
| Calendarios | Calendarios de Google donde comprobar huecos; arrastra para ordenarlos — el primero marcado con escritura recibe las reservas (badge «Recibe nuevas citas») |
| Plantilla de acuse | Opcional. Tras confirmar, abre `/b/slug/recibido?evento=slug-tipo` con esa plantilla Liquid (sin nombre, email ni teléfono en la URL). Si se deja vacía, la confirmación sigue en Cream (Meet, `.ics`) |
| Página activa | Si está desmarcada, la URL pública no acepta reservas |

**Tipos de evento** (al menos uno obligatorio; arrastra el asa ⋮⋮ para cambiar el orden)

| Campo | Descripción |
|-------|-------------|
| Slug | Identificador del tipo en la URL directa (`/b/slug-página/slug-tipo`) y la API |
| Duración (min) | Duración de la cita |
| Nombre / Descripción (ES y EN) | Textos en la página pública según idioma del visitante |
| Franjas horarias semanales | Tramos reservables por día; «+ Franja» añade bloques; «Horario laboral por defecto» rellena un ejemplo |
| Incremento de slots (min) | Separación entre huecos ofrecidos |
| Antelación mínima (h) | Horas mínimas antes de la cita para poder reservar |
| Buffer antes / después (min) | Tiempo libre alrededor de cada cita |
| Tipo de ubicación | Google Meet, Presencial o A coordinar |
| Dirección (presencial) | Lugar si la ubicación es presencial |
| Color en calendario | Color del evento en Google Calendar |
| Visible | Si aparece en la página pública |
| Plantilla de acuse | Opcional. Sustituye la plantilla de la página para este tipo concreto |

Usa **Añadir tipo** para crear tipos nuevos o el icono de papelera para eliminarlos. Guarda la página para aplicar los cambios.

Copia la **URL pública** y compártela con clientes. Si la página tiene varios tipos, usa la **URL directa del tipo** (en el listado de **Reservas** o al editar el tipo en **URL directa del tipo**) para que el visitante vaya al calendario de ese tipo sin pasar por la pantalla de selección.

### Qué ocurre al reservar

- Se consulta la **disponibilidad real** contra los calendarios configurados (por defecto `primary`).
- Al confirmar, se crea el **evento en Google Calendar** con quien reserva, los invitados opcionales (hasta 5) y el anfitrión como asistentes.
- En Cream se crea o reutiliza la **persona** (por email) y se crea o reutiliza el **deal** en el pipeline indicado según la opción **Reutilizar deal existente**, con tarea de seguimiento para el anfitrión cuando el deal es nuevo.
- El anfitrión recibe aviso según sus canales en **Settings → Profile → Alertas** (campana y/o email), con los datos de la reserva y un enlace al deal.
- En la ficha del **deal** y del **contacto**, el timeline de **Actividad** registra la reserva (invitado, tipo de cita y fecha/hora), también cuando se reutiliza un deal existente.

### Página pública (visitante)

Flujo en tres pasos: elegir tipo de evento → calendario y hora (el selector de zona horaria convierte los huecos del anfitrión a la zona del visitante; fecha y hora se muestran siempre con el identificador IANA, p. ej. `Europe/Madrid`) → formulario y confirmación. Si hay **plantilla de acuse** configurada, al confirmar se abre esa página (`/b/slug/recibido?evento=slug-tipo`); si no, la confirmación en Cream incluye enlace Meet y descarga `.ics` (hora en UTC). Con una **URL directa de tipo** (`/b/slug-página/slug-tipo`), el visitante salta el primer paso y entra directamente en el calendario de ese tipo.

---

## 29. Marketing

El **hub de marketing** conecta captación web, consentimiento por email, envíos masivos, segmentación, recorridos automatizados, puntuación de leads, tracking y atribución UTM. Se apoya en los **formularios de captación** ([§27](#27-formularios-de-captación)) y en la configuración de **Mailjet** en **Settings** ([§21](#21-ajustes-del-workspace)) para campañas y métricas de apertura/clic.

### Cómo acceder

En el menú lateral (según funcionalidades activas en tu workspace). **Atribución** y **Puntuación de leads** son opcionales y están ocultas por defecto — actívalas en **Ajustes → Funcionalidades**:

| Menú | Uso |
|------|-----|
| **Suscripciones** | Tipos de lista (newsletter, general, etc.) |
| **Campañas** | Envíos masivos a segmentos |
| **Segmentos** | Audiencias filtradas de personas |
| **Atribución** *(opcional)* | Informe por parámetros UTM |
| **Recorridos** | Secuencias automatizadas |
| **Puntuación de leads** *(opcional)* | Reglas de scoring y lifecycle |
| **Formularios** | Captación pública (Deal o MQL) |
| **MQLs** | Pool de contactos con permiso de marketing |

### Pool MQL

Contactos con **permiso de marketing vigente** (al menos una suscripción activa a un tipo activo, email principal válido y sin supresión). Por defecto aparecen suscriptores de cualquier tipo (p. ej. **General** o **Newsletter** importados desde Beehiiv). Puedes acotar con el filtro **tipo de suscripción**. El pool es independiente del lifecycle de scoring: un cliente con permiso puede seguir en el pool mientras tenga oportunidades abiertas en otros productos.

**Cómo acceder:** menú **MQLs**.

**Pasos:**

1. Abre **MQLs**. La tabla muestra persona, lifecycle (scoring), puntuación, formularios de origen (con **Ver consentimiento**), intereses pendientes y oportunidades visibles.
2. Filtra por búsqueda, **tipo de suscripción**, **oportunidad abierta** (cualquiera / sí / no), **producto** (de la oportunidad), **interés en producto** o **formulario de origen**.
3. Desde una fila con interés pendiente, pulsa **Convertir a SQL** para crear o vincular una oportunidad con ese producto (pipeline, tarea y responsable).

**En la ficha de una persona:**

- **Intereses por producto** — registra manualmente una señal comercial (producto + descripción) o proviene de un formulario MQL con producto. Estados: pendiente, convertido o descartado.
- **Formularios enviados** — historial de envíos agrupados por formulario, en **Deals** y en **Information**, con enlace **Ver consentimiento** (respuestas, destino, política y frase aceptadas).
- **Campañas enviadas** — en **Activity**, las últimas campañas de marketing recibidas y **Ver más** para el historial con eventos de entrega.
- **Recorridos** — en **Activity**, las inscripciones de este contacto (activas, en espera, completadas o canceladas), con el paso actual y la fecha de inscripción. **Ver más** abre el historial completo.

**Notas:**

- **Convertir a SQL** exige permiso para crear deals. Si ya hay una oportunidad abierta del mismo producto, Cream ofrece vincular en lugar de duplicar.
- El lifecycle de scoring (*mql*, *sql*, etc.) **no** indica si hay deal abierto; mira la columna **Oportunidades visibles** o la ficha del contacto.
- Los recorridos pueden configurarse con **Salir del recorrido si hay oportunidad abierta del producto** para pausar el nurturing comercial.

### Suscripciones y consentimiento

**Tipos de suscripción** (menú **Suscripciones**):

1. Pulsa **Nuevo tipo**.
2. Indica **nombre**, **identificador (slug)**, **descripción** (visible en el centro de preferencias del contacto) y **orden**.
3. Opcional: **Clave del checkbox en formularios** — nombre del campo `lead[clave]` que activará esta suscripción cuando el visitante lo marque (p. ej. `newsletter_opt_in`). Debe ser única en el workspace.
4. Opcional: **Texto por defecto del checkbox** — etiqueta mostrada en plantillas Liquid salvo que la plantilla o el formulario MQL la sobrescriban.
5. Opcional: **Excluir de «suscribir a todas»** — el tipo no se incluye en `{% subscription_opt_in_all %}` (sigue pudiendo activarse con su checkbox individual).
6. Marca **Activo** y guarda. Cream crea por defecto tipos como *general* (`marketing_consent`) y *newsletter* (`newsletter_opt_in`) al usar el módulo.

**En la ficha de una persona** (**Information** → **Email preferences**):

- Cada tipo muestra su estado: **Suscrito**, **Dado de baja** o **Pendiente**.
- **Suscribir** / **Dar de baja** cambia el permiso manualmente (con confirmación).
- Copia la URL del **centro de preferencias** y compártela con el contacto.

**Centro de preferencias (página pública del contacto):**

- El contacto marca qué listas quiere recibir y pulsa **Guardar preferencias**.
- **Darse de baja de todas las comunicaciones** suprime el email para marketing (sin afectar emails transaccionales de CRM salvo que estén suprimidos por rebote/spam).

**Dos consentimientos distintos en formularios:**

| Consentimiento | Qué es | Dónde se configura |
|----------------|--------|-------------------|
| **Protección de datos (RGPD)** | Obligatorio para enviar cualquier formulario | Partial `consent_fields` en plantillas |
| **Marketing / newsletter** | Opcional; activa una suscripción | Tag `{% subscription_opt_in slug: "…" %}` en plantillas (usa la clave del tipo) + tipo en formulario MQL |
| **Todas las suscripciones** | Opcional; activa los tipos activos no excluidos | Tag `{% subscription_opt_in_all %}` o parcial `subscribe_all_opt_in` (campo `lead[subscribe_all]`). Excluye tipos marcados en **Suscripciones** o con `exclude: "slug1, slug2"` en la plantilla |

Las suscripciones creadas desde un formulario guardan la misma **versión de política de privacidad** que el envío (ver [§27](#27-formularios-de-captación)).

### Campañas

1. Menú **Campañas** → **Nueva campaña**: nombre, objetivo, fecha de inicio, parámetros **UTM** y, en **Contenido del email**, redacta el envío o elige una **plantilla base (opcional)** para copiar asunto y cuerpo como punto de partida. El contenido se guarda en la campaña, no como plantilla global nueva.
2. En el mismo bloque puedes elegir un **layout**, alternar **editor enriquecido** / **HTML**, usar variables `{first_name}`, `{name}`, `{company}`, `{email}` o Liquid `{{ name }}`, y abrir **Vista previa** antes de guardar.
3. Abre la campaña creada. En **Enviar campaña** elige:
   - **Segmento de personas** (obligatorio; muestra cuántos destinatarios coinciden).
   - **Tipo de suscripción**: solo recibirán el envío contactos **suscritos** a ese tipo.
   - **Programar envío** (opcional): fecha y hora; vacío = envío inmediato al pulsar **Encolar envío**.
4. **Prueba A/B (opcional):** asunto y cuerpo de variantes A y B con pesos (%). Si rellenas asuntos A/B, sustituyen al asunto del contenido de la campaña.
5. **Enviar prueba a tu email:** usa el contenido guardado en la campaña; opcionalmente prueba otro asunto o cuerpo.
6. Tras el envío, revisa **Historial de envíos** (estado, omitidos, fallidos). Con A/B puedes **Marcar ganadora** y **Enviar ganadora al resto** a quienes no la recibieron.

Las **Plantillas** del menú lateral siguen disponibles como bases reutilizables para campañas, fichas y formularios.

**En la ficha de una persona** (**Activity** → **Campañas enviadas**):

- Verás las **últimas 5** campañas enviadas a ese contacto (fecha, nombre de campaña, asunto y si se abrió o se hizo clic).
- **Ver más** abre el historial completo con el detalle de eventos de entrega (apertura, clic, rebote…).
- El listado usa el mismo registro de envíos que la campaña; no incluye correos uno a uno ni pasos de recorrido sin campaña.

**Requisitos:** Mailjet conectado en **Settings → Mailjet** (Cream registra el Event Tracking al guardar; ver [§21](#21-ajustes-del-workspace)). Sin Mailjet, los envíos usan SMTP/Mailbin del servidor.

### Segmentos

1. Menú **Segmentos** → **Nuevo segmento**.
2. Elige **tipo de registro** (personas) y define **filtros**: búsqueda, ciclo de vida, email, puntuación, emails abiertos recientes, formulario enviado, URL visitada, oportunidad abierta, interés por producto, historial comercial, formulario de origen, etc.
3. Marca **Excluir direcciones suprimidas** para respetar rebotes y bajas globales.
4. Tras guardar, la **vista previa** muestra cuántos registros coinciden (actualiza al guardar cambios).
5. Opcional: **Compartido con el equipo** para que otros miembros lo usen en campañas.

Los segmentos alimentan **Campañas** y pueden usarse como disparador de **Recorridos**.

### Recorridos

Secuencias automatizadas por contacto.

1. Menú **Recorridos** → **Nuevo recorrido**: nombre, **disparador de entrada**, reinscripciones máximas (0 = una sola vez) y si está **Activo**.
2. **Disparadores de entrada:** formulario enviado, entrada en segmento, cambio de ciclo de vida, clic en email de marketing, reserva creada o **manual**.
3. Configura la **condición de entrada** según el disparador (formulario concreto, segmento, página de reservas, transición de lifecycle…).
4. Opcional: **Producto (salida comercial)** y **Salir del recorrido si hay oportunidad abierta del producto** — cancela el nurturing cuando ya hay deal abierto con ese producto.
5. Añade **pasos** (ordenados por posición):

| Paso | Qué hace |
|------|----------|
| **Enviar email** | Redacta el email del paso (plantilla base opcional, layout, Quill/HTML, vista previa) + tipo de suscripción (respeta consentimiento) |
| **Esperar** | Pausa N minutos desde que el contacto llega al paso (60 = 1 h, 1440 = 1 día). Opcional: **Hasta las HH:MM** (hora del workspace) retiene al contacto hasta la próxima vez que sea esa hora; **Solo días laborables** pasa sábados y domingos al lunes a la misma hora |
| **Condición** | Rama según campo del contacto |
| **Establecer campo** | Cambia ciclo de vida |
| **Añadir a lista** | Añade el contacto a una lista del CRM |
| **Crear tarea** | Tarea comercial con vencimiento en N días naturales, contados en la zona horaria del workspace |
| **Ajustar puntuación** | Suma o resta puntos |
| **Notificar** | Aviso a un usuario del equipo |

> **Cuándo se ejecuta cada paso.** Los pasos corren en orden y de inmediato en cuanto el contacto entra en el recorrido (o termina una espera), en ciclos de 10 minutos, a cualquier hora y cualquier día de la semana; no hay horario laboral salvo que lo fijes con un paso **Esperar**. Ejemplos: **Esperar 1440** = un día después, a la misma hora; **Esperar 1440 + Hasta las 10:00** = al día siguiente a las 10:00; **Esperar 0 + Hasta las 09:30 + Solo días laborables** = el próximo día laborable a las 09:30 (hoy mismo si aún no son las 09:30). Coloca el paso justo antes del **Enviar email**. En la ficha del recorrido, **Próxima ejecución** muestra fecha y hora en tu zona horaria (ver [§20](#20-equipo-e-invitaciones)).

6. En recorridos **manuales**, abre la ficha del recorrido → **Inscribir contacto manualmente**.
7. Desde la ficha del recorrido puedes **Pausar** / **Activar**, ver inscripciones activas, el paso actual de cada contacto y la **próxima ejecución** (fecha y hora).
8. En inscripciones **Activo** o **En espera**, usa **Cambiar paso** para mover al contacto a otro paso. El recorrido continúa desde ahí y ejecutará ese paso (puede reenviar un email o reiniciar una espera). Solo administradores.

**En la ficha de una persona** (**Activity** → **Recorridos**):

- Verás las **últimas 5** inscripciones de ese contacto (recorrido, estado, paso actual y fecha de inscripción).
- **Ver más** abre el historial completo, incluidas las completadas o canceladas, y la próxima ejecución si está en espera.
- El nombre del recorrido enlaza a su ficha (solo administradores).

### Puntuación de leads

1. Menú **Puntuación de leads** → **Nueva regla**: nombre, tipo de evento (email abierto, clic, formulario, visita web, deal creado…), puntos (+/-), decaimiento en días (0 = sin decaimiento) y condiciones adicionales.
2. Las reglas **activas** se evalúan con los eventos de marketing; el **lead score** y el **lifecycle** del contacto se actualizan (recálculo completo también de noche).
3. Etapas de lifecycle visibles en la ficha persona: *subscriber* → *lead* → *mql* → *sql* → *opportunity* → *customer* → *evangelist*.

> **Importante:** el lifecycle de scoring **no** indica si hay una oportunidad (deal) abierta. Para ventas operativas mira los **Deals** del contacto.

### Tracking web y landing pages

**Snippet de tracking:** incluye en tu web un script servido por Cream:

```html
<script src="https://TU-DOMINIO-CREAM/cream.js" async></script>
```

Registra visitas y parámetros UTM; al enviar un formulario de captación, Cream intenta vincular la actividad anónima previa al contacto identificado.

**Landing pages:** en **Formularios → Plantillas de formulario**, crea una plantilla con tipo **Landing page** e indica el **slug público**. La URL será `/p/slug-del-workspace/slug-de-la-landing`. El contenido es Liquid, como los formularios.

### Atribución

Menú **Atribución**:

1. Filtra por **UTM source**, **UTM medium**, **UTM campaign** y **periodo** (mes, trimestre, año).
2. La tabla agrupa por canal: **Visitas**, **Leads**, **MQL**, **Deals** e **Ingresos**.
3. Pulsa los números de **Leads**, **MQL** o **Deals** para abrir listados filtrados por ese canal.

Las campañas pueden definir UTMs que se propagan a los enlaces del email; los formularios y el tracking web alimentan el mismo informe.

### Notas

- Cualquier miembro puede usar campañas, segmentos, recorridos y atribución; **Settings → Mailjet** es solo **admins**.
- Los envíos de campaña y recorridos **no llegan** a contactos dados de baja del tipo elegido ni a direcciones **suprimidas** (rebote, spam, baja global).
- **Formularios** y captación detallada: [§27](#27-formularios-de-captación).

---

## 30. Próximamente

Estas funcionalidades existen en el código pero **no están disponibles** en la interfaz hasta completar su implementación (controladas por `CreamFeatures`):

| Funcionalidad   | Estado actual |
|-----------------|---------------|
| **Mail merge**  | Envío masivo clásico a vista guardada, lista o IDs manuales; sustituido en la práctica por **Campañas** + **Segmentos** |
| Slack           | Notificaciones parciales (solo cambio de etapa en deals) |
| AI automations  | Hooks proactivos en automatizaciones (resumir al cerrar deal, scoring, etc.) |

Cuando se habiliten, aparecerán en el menú lateral y las secciones correspondientes de este manual deben actualizarse.

---

## Mantenimiento de este manual

Este archivo lo mantienen los desarrolladores al cambiar funcionalidad visible. Ver la skill `cream-user-manual` en `.claude/skills/cream-user-manual/SKILL.md`.
