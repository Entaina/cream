# frozen_string_literal: true

# Idempotent seed of example course email templates into the organization workspace.
module EmailTemplatesExample
  TEMPLATES = [
    {
      key: "primer_contacto",
      name: "Primer contacto",
      subject: "Example | [Nombre del curso]: toda la info para reservar",
      body: <<~BODY.strip
        Hola {first_name}:

        Gracias por tu interés en [Nombre del curso]. Nos alegra que quieras formar parte.

        Te adjunto un documento con todo lo que necesitas saber: precios, qué incluye el curso, fechas y condiciones de reserva. Lo hemos preparado para que puedas verlo de un vistazo y decidir con calma.

        Como trabajamos en grupos reducidos ([8-16] personas), las plazas son limitadas y se asignan por orden de reserva.

        ¿Cuál es el siguiente paso?

        Reservar tu plaza. Si ya tienes toda la información que necesitas, puedes formalizar tu reserva haciendo el pago de la reserva o el del total del curso mediante transferencia y enviarnos el justificante. Estos son los datos:

        IBAN: [IBAN]
        Concepto: "Curso [Nombre del curso] - [Mes]"
        Titular: Example SL

        Resolver tus dudas en una llamada. Si prefieres comentar los detalles o valorar una propuesta adaptada a tu caso, puedes agendar una llamada con nuestro equipo, quien te atenderá personalmente.

        Quedo a tu disposición para cualquier consulta; puedes responder directamente a este correo.

        Que tengas muy buen día,
      BODY
    },
    {
      key: "reserva_confirmada",
      name: "Reserva confirmada",
      subject: "Example | Reserva confirmada — [Nombre del curso]",
      body: <<~BODY.strip
        Hola {first_name}:

        ¡Tu plaza está confirmada! Hemos recibido el pago de tu reserva para [Nombre del curso]. Bienvenido/a.

        A continuación tienes toda la información práctica para que llegues con todo preparado.

        Detalles del curso
        Fechas: [fechas de las sesiones]
        Horario: [horas]
        Lugar: [dirección completa + indicaciones de acceso si aplica]

        Acceso a la plataforma (incluir solo en el curso que aplique)
        Trabajaremos a través de una plataforma online. En los próximos días recibirás una invitación en un correo aparte para crear tu acceso. Si no la ves, revisa la carpeta de spam y, si aún así no aparece, escríbeme y lo resolvemos.

        Requisitos técnicos
        Para aprovechar el curso al máximo, necesitarás tener listo lo siguiente:

        Documentación previa (incluir solo en el curso que aplique)
        Hemos preparado material para que leas antes de empezar. Lo encontrarás adjunto / en la plataforma. Te recomendamos revisarlo con antelación: te ayudará a sacar mucho más partido de las sesiones.

        Factura y datos fiscales
        Si vas a necesitar factura, envíanos tus datos fiscales respondiendo a este correo. Emitimos las facturas cuando se completa el segundo pago.

        Recordatorio del pago restante
        El importe restante deberá abonarse hasta [X] días antes del inicio. Te enviaremos un recordatorio cuando se acerque la fecha, así que no tienes que preocuparte por ello ahora.

        Cualquier duda, respóndeme directamente a este correo.

        Un cordial saludo,
      BODY
    },
    {
      key: "recordatorio_segundo_pago",
      name: "Recordatorio segundo pago",
      subject: "Example | Completa tu pago para [Nombre del curso]",
      body: <<~BODY.strip
        Hola {first_name}:

        Tu curso [Nombre del curso] se acerca y queremos asegurarnos de que tienes tu plaza completamente confirmada.

        Para ello, solo queda completar el pago restante antes del [fecha límite].

        Resumen de tu reserva
        Curso: [Nombre del curso]
        Fechas: [días]
        Importe pendiente: [importe]
        Fecha límite de pago: [fecha]

        Puedes realizar el pago a través de transferencia bancaria. Estos son los datos:

        IBAN: [IBAN]
        Concepto: "Curso [Nombre del curso] - [Mes]"
        Titular: Example SL

        Envía el justificante de la transferencia a este email.

        Si necesitas factura, recuerda enviarnos tus datos fiscales y la emitiremos una vez recibido este pago.

        Cualquier duda, quedo disponible.

        Un saludo,
      BODY
    },
    {
      key: "ultimo_recordatorio_pago",
      name: "Último recordatorio de pago",
      subject: "Example | Último día para confirmar tu plaza en [Nombre del curso]",
      body: <<~BODY.strip
        Hola {first_name}:

        Te escribo para recordarte que hoy es el último día para completar el pago de [Nombre del curso] y asegurar tu plaza.

        Importe pendiente: [importe]

        Datos para el pago:
        IBAN: [IBAN]
        Concepto: "Curso [Nombre del curso] - [Mes]"
        Titular: Example SL

        Puedes enviar el justificante de la transferencia a este email.

        Recuerda que, como las plazas son limitadas, conforme a nuestra política de reserva y cancelación, si no podemos confirmar el pago hoy tu plaza quedará liberada.

        Un saludo,
      BODY
    },
    {
      key: "ultimos_ajustes",
      name: "Últimos ajustes",
      subject: "Example | [Nombre del curso] — últimos ajustes",
      body: <<~BODY.strip
        Hola {first_name}:

        Ya queda muy poco para empezar [Nombre del curso]. Antes de vernos, necesitamos que dejes preparado tu equipo para que el primer día podamos arrancar sin contratiempos y aprovechar el curso al máximo.

        Revisa el material previo que te enviamos y comprueba que tienes todo listo según las indicaciones del curso.

        Recordatorio de fechas
        Días: [días]
        Horario: [horas]
        Lugar: [dirección / acceso]

        Si te encuentras con cualquier dificultad al prepararte, respóndeme a este correo y lo resolvemos juntos.

        ¡Nos vemos muy pronto!

        Un saludo,
      BODY
    },
    {
      key: "cierre",
      name: "Cierre",
      subject: "Example | Gracias por participar en [Nombre del curso]",
      body: <<~BODY.strip
        Hola de nuevo {first_name}:

        Queremos darte las gracias por haber formado parte de [Nombre del curso]. Ha sido un placer acompañarte estos días y esperamos de corazón que la experiencia te haya aportado y que vuelvas a tu día a día con ideas y herramientas nuevas para aplicar.

        Presentaciones de las clases
        Encontrarás adjuntas a este correo las presentaciones que hemos utilizado durante las sesiones, para que puedas repasarlas y consultarlas siempre que quieras.

        Facturas
        Te haremos llegar la factura en los próximos días. Si todavía no nos has enviado tus datos fiscales, te agradeceríamos que nos los hicieras llegar respondiendo a este correo para poder emitirla.

        Newsletter
        Te damos la bienvenida a nuestra newsletter. Recibirás noticias con información útil y, cuando organicemos sesiones de actualización, tendrás toda la información en tu correo.

        Para cualquier consulta, respóndeme directamente a este correo. Ha sido un gusto tenerte con nosotros.
      BODY
    },
    {
      key: "envio_formulario",
      name: "Envío de formulario",
      subject: "Example | ¿Cómo va la puesta en práctica de [Nombre del curso]?",
      body: <<~BODY.strip
        Hola {first_name}:

        Han pasado algunas semanas desde que terminaste [Nombre del curso] y nos encantaría saber cómo te está yendo.

        Ahora que has tenido tiempo de volver a tu día a día e ir aplicando lo que vimos, tu experiencia nos resulta muy valiosa: nos ayuda a mejorar y a entender qué funciona de verdad cuando lo aprendido se lleva a la práctica.

        ¿Te animas a dedicarnos unos minutos? Hemos preparado un breve formulario de seguimiento:
        [Enlace al formulario]

        Es corto y tus respuestas nos ayudan muchísimo.

        Gracias de nuevo por haber formado parte.
      BODY
    },
    {
      key: "proxima_edicion",
      name: "Próxima edición",
      subject: "Example - Próxima edición [nombre del curso], ¿te unes?",
      body: <<~BODY.strip
        Hola {first_name}:

        Te escribimos para compartir contigo las fechas de nuestro próximo curso de [nombre del curso], en el que nos dijiste que tenías interés.

        Los próximos [días, mes], en horario [horas] tendremos la siguiente edición.

        Recuerda que las plazas son limitadas, así que si finalmente quieres unirte, avísanos cuanto antes para indicarte cómo reservar la tuya.

        Te dejamos adjunto un documento con la información básica; si tienes cualquier consulta, no dudes en contactarnos.

        Esperamos que tengas un gran día.

        Hablamos pronto,
      BODY
    }
  ].freeze

  def self.seed!(workspace:, user:)
    TEMPLATES.each do |attrs|
      snippet = workspace.email_templates.find_or_initialize_by(key: attrs[:key])
      snippet.assign_attributes(
        user: user,
        name: attrs[:name],
        subject: attrs[:subject],
        body: attrs[:body],
        shared: true
      )
      snippet.save!
    end
  end
end
