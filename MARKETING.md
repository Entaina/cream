CReaM está diseñado en torno a la gestión de pipelines de venta: personas, empresas y deals con etapas. Es decir, gestiona bien los SQL (Sales Qualified Leads) y no tiene nada para los MQL (Marketing Qualified Leads). Conceptualmente en Entaina tenemos los dos tipos, y la mitad de marketing hoy no existe en la aplicación: no hay dónde guardar los contactos que nos dan permiso para comunicarnos con ellos, ni forma de segmentarlos, ni de lanzarles campañas o secuencias de correo.



La necesidad es inmediata: estamos preparando un montón de lead magnets y cada descarga o registro tiene que quedar guardada en una base de datos que hoy no existe como tal.



Qué hacen las herramientas del mercado


Síntesis de lo que ofrecen los CRM comerciales con módulo de marketing (HubSpot, ActiveCampaign, Brevo, Pipedrive+Campaigns):



Ciclo de vida del contacto como eje: HubSpot modela ocho etapas (Subscriber → Lead → MQL → SQL → Opportunity → Customer → Evangelist), donde el contacto es el mismo registro durante todo el viaje y solo cambia de etapa. Su gran ventaja competitiva es precisamente esa: marketing y ventas sobre la misma base de datos, sin sincronizaciones. Nosotros podemos replicar eso de serie, porque el módulo nace dentro de CReaM.
Segmentación por listas dinámicas: filtros guardados sobre atributos y comportamiento («descargó el PDF X y no tiene deal abierto») que se recalculan solos. Es la pieza sobre la que se montan campañas y secuencias.
Automatizaciones / secuencias: cadenas de correo disparadas por un evento (descarga, formulario, alta), con esperas, condiciones y ramificaciones. Es la funcionalidad estrella de ActiveCampaign; HubSpot la reserva para su tier Professional (~890 $/mes).
Lead scoring: puntuación numérica del contacto por comportamiento; al superar un umbral se convierte en MQL y entra en nurturing, y con más señal pasa a ventas. Los mejores lo tratan como complemento de las etapas, no sustituto: el score ordena dentro de una etapa, la etapa estructura el funnel.
Captura: formularios, landing pages y tracking web que alimentan la base de datos con atribución de origen.
Consentimiento: gestión de opt-in/opt-out, doble opt-in, motivo y fecha del permiso — imprescindible en Europa (es la especialidad de Brevo, el jugador europeo).


Lo que no vamos a copiar (adicional): constructores de landing pages, SMS/WhatsApp, scoring predictivo con IA. Son la razón de que esas herramientas cuesten cientos de euros al mes y no son nuestro cuello de botella.



Modelo conceptual propuesto


Un solo registro de persona, un ciclo de vida. No construimos «otra base de datos» separada: extendemos personas y empresas de CReaM con una dimensión de ciclo de vida. La base de datos de MQL es el subconjunto de contactos que (a) están en el ámbito de actuación de Entaina y (b) nos han dado permiso para comunicarnos con ellos.



El ciclo es circular: MQL → SQL → Cliente → MQL. No es un funnel que termina en Cliente: cuando el proyecto se entrega, el contacto vuelve al pool de MQL — seguimos comunicándonos con él, y el siguiente interés en un producto vuelve a abrir un SQL. La recurrencia no es un accidente del modelo, es el modelo.



Etapas:



Contacto — existe en la base, sin permiso de comunicación. Solo lo tocamos si él nos escribe. (Adicional: antesala del ciclo, no forma parte de él.)
MQL — nos ha dado permiso (suscripción, lead magnet, formulario). Podemos escribirle. La newsletter es un permiso más, no la definición: hay contactos a los que podemos escribir sin que reciban la newsletter.
SQL — el disparador es el interés en algún producto de Entaina: cuando un MQL muestra interés en un producto concreto (lo pregunta, se descarga su material, responde a una secuencia), se abre deal con ese producto y entra en los pipelines que ya existen. El paso debe quedar registrado: qué producto, qué señal, quién y cuándo.
Cliente — deal ganado y proyecto en marcha. Al terminar, vuelve a MQL: mismo registro, mismo permiso, nueva vuelta al ciclo. Un cliente puede estar a la vez en ambos estados — en ejecución de un proyecto y en el pool de MQL para los demás productos.
Requisitos funcionales
Base de datos MQL
Extender persona/empresa con: etapa de ciclo de vida, origen (qué acción de marketing lo trajo), permisos de comunicación (qué consintió, cuándo, cómo) y suscripciones (newsletter, otras listas).
Histórico de interacciones de marketing en la ficha: descargas, aperturas, clics — junto a la actividad comercial que ya existe.
Captura y nutrición
API/endpoint de captura para lead magnets: cada calculadora, PDF o formulario da de alta (o enriquece) un contacto con su origen y su consentimiento. Toda acción de marketing nutre la misma base.
Importación de la base actual de suscriptores de la newsletter con su consentimiento acreditado.
Deduplicación por email contra los contactos existentes (CReaM ya tiene detección de duplicados: reutilizarla).
Segmentación
Filtros combinables sobre atributos, origen y comportamiento («preguntó por el producto X», «descargó Y en los últimos 30 días», «sin deal abierto»).
Segmentos guardados y dinámicos: la lista se recalcula sola; las campañas y secuencias apuntan a segmentos, no a listas congeladas.
Campañas y secuencias
Campañas puntuales: redactar y enviar un correo a un segmento desde el propio CRM, con métricas de entrega, apertura y clic escritas en la ficha de cada contacto.
Secuencias automatizadas: cadenas de correos disparadas por un evento (descargó tal PDF → secuencia de nurturing de ese producto), con esperas y condición de salida (responde, pide reunión, se abre deal → sale de la secuencia). Empezar con secuencias lineales; las ramificaciones pueden esperar.
Baja y gestión de preferencias en un clic en todo correo saliente, con efecto inmediato en la base.
Paso a ventas (MQL → SQL)
El criterio es el interés en un producto: la señal que convierte a SQL siempre apunta a un producto del catálogo de CReaM, y el deal se crea con ese producto como línea.
Acción «convertir a SQL» desde la ficha (o automática ante señal fuerte): crea el deal en el pipeline correspondiente con el contexto de marketing colgando (origen, producto de interés, secuencias recibidas, interacciones).
Cierre del ciclo: al terminar el proyecto (o perderse el deal), el contacto vuelve al pool de MQL con su historial — elegible para secuencias y campañas de los demás productos.
(Adicional) Scoring simple por producto para ordenar la cola de MQLs: no predictivo, solo suma de señales (descargas, aperturas, visitas repetidas) asociadas a cada producto. Revisar los umbrales cada trimestre contra conversiones reales, no contra intuición.
Cumplimiento (RGPD)
Consentimiento con fecha, origen y texto aceptado; doble opt-in configurable por formulario.
Supresión: la baja no borra el contacto, lo marca inescribible (para no volver a darlo de alta por error desde otro lead magnet).
Relación con lo que ya existe
Beehiiv: hoy la newsletter de Entaina sale por Beehiiv. Decisión pendiente: si CReaM envía directamente (SMTP/API propia) o si CReaM es el cerebro (segmentos, disparadores) y Beehiiv el brazo que envía. Propuesta (adicional): empezar con CReaM como cerebro y el envío delegado, y decidir con datos de volumen. En cualquier caso, los suscriptores de Beehiiv tienen que existir como contactos MQL en CReaM (sync o importación periódica), o la «misma base de datos» se rompe el primer día.
Portal de cliente (borrador aparte): el login del portal con email es una fuente de captura más, y las etapas de ciclo de vida de este documento son las mismas que gobiernan los niveles de servicio del portal. Los dos módulos comparten el modelo.