# Plan: alarmas confiables y despliegue en Vercel

Estado: **Fases A, A2 y B completas y probadas con la app cerrada en un dispositivo real (9-oct-2026). El cron diario también quedó verificado.** Basado en `../ncs-app`, que ya resuelve en Vercel + Upstash Redis problemas parecidos (código de sync, namespaces, TTL).

## Contexto y alcance

- La app la usarán 2 o 3 personas cercanas, nadie más.
- No guarda datos sensibles (títulos de tareas, grupos, fechas).
- Consecuencias: el código de sync como única credencial es suficiente, no hace falta login ni autenticación real, y `privacidad.html` puede ser corto. No hay que sobreingenierizar.
- Objetivo a corto plazo (no inmediato): **alarmas que suenan con la app cerrada**. Es lo único que arregla un fallo real de la función principal.

## Problema

Las alarmas usan la Notification API y un chequeo cada 20 s (`index.html`). Solo suenan si la app está abierta o en segundo plano reciente.

## Fases

### Fase A: mejoras sin backend (ahora)
- [x] Marcar cada alarma como disparada.
- [x] Al abrir o volver a la app, mostrar las alarmas vencidas no disparadas (banner o modal).
- [x] Botón "Importar JSON" (hoy solo existe exportar).
- [x] `sw.js`: `CACHE_NAME` versionado, `APP_SHELL` con manifiesto e íconos.
- [x] `manifest.json`: separar `purpose` de los íconos en `any` y `maskable`.
- [x] README: documentar `tareas_username` en la tabla de almacenamiento.

### Fase A2: rediseño a lista minimalista (implementado en lo esencial)
Mockup de referencia: [diseno/mockup.html](diseno/mockup.html). La app pasa a ser una lista simple por grupo, como el papel de la persona usuaria, con detalles opcionales.

**Decisiones de diseño**
- **Sin tarjetas.** Cada tarea es una línea: círculo, título y, solo si existe, un indicador a la derecha. Sin sombras, franjas ni botones por tarea.
- **Grupos como secciones**, siempre ordenadas por grupo: título en versalitas con punto de color, contador de pendientes, plegables (▾ / ▸). El estado plegado se recuerda entre sesiones.
- **Agregar**: botón flotante + abajo a la derecha (uso con una mano). Abre una hoja con el teclado activo y chips de grupo; el grupo actual (o el último usado) queda preseleccionado, así que toda tarea tiene grupo.
- **Detalle opcional** al tocar la línea (se despliega en el lugar), en este orden: **Alarma, Plazo, Urgencia**. Lo no configurado se ve como "+ agregar". Ningún detalle se pide por defecto.
- **HOY**: marca por tarea, rotulada solo "HOY" en mayúscula (también en el filtro Todas / HOY). **Las tareas nuevas entran en HOY por defecto y poner un Plazo no la quita** (se cambió el 9-oct-2026: la regla "HOY solo si no hay Plazo" no funcionó en el uso real; quitar HOY es siempre manual).
- **Urgencia**: punto de color a la derecha (rojo, amarillo, verde); sin punto = sin urgencia.
- **Orden dentro de cada grupo**: manual (arrastrar). Las urgentes suben solas por regla, pero **cualquier orden manual prevalece sobre la regla**: las tareas nuevas se ubican según urgencia, y una tarea movida a mano conserva su posición aunque cambie su urgencia. Pendiente de confirmar: el arrastre solo se limita si el usuario no lo ha fijado antes.
- **Completar**: círculo relleno y texto tachado en gris, al final del grupo. **Desaparecen al terminar el día y se borran de verdad** (no hay archivo): al abrir la app un día distinto al que se completaron, se eliminan. Sin temporizador.
- **Modo oscuro** automático según el sistema, con opción manual en Ajustes. Misma paleta (coral de acento, urgencia rojo / amarillo / verde) con los tonos ajustados.
- El botón + queda a la derecha; no es configurable.
- Etiqueta "Fecha" renombrada a **"Plazo"** en toda la app.

**Tareas**
- [x] Reescribir `renderTasks` / la vista como lista por secciones (sin `.task-card`).
- [x] Hoja de captura con chips de grupo.
- [x] Detalle expandible en línea (Alarma, Plazo, Urgencia, HOY, Eliminar).
- [x] Regla de orden: urgentes arriba salvo orden manual; guardar si una tarea tiene posición manual.
- [x] Borrado de completadas al cambiar de día.
- [x] Tema claro/oscuro con variables CSS y `prefers-color-scheme`.
- [x] HOY por defecto en las tareas nuevas (sin importar el Plazo); renombrar "Fecha" a "Plazo" (también en README).
- [x] Migración de datos: las tareas existentes conservan campos; las completadas viejas se borran en la primera carga.

### Fase B: alarmas con la app cerrada (futuro cercano)
Requiere backend, así que incluye la migración a Vercel.

1. **Migración a Vercel**
   - [x] Proyecto en Vercel, `vercel.json` copiado de ncs-app (`cleanUrls`, rewrite `/api/*`, headers de seguridad).
   - [x] `manifest.json`: `start_url` y `scope` a `/`.
   - [x] ~~Migrar los datos de cada persona~~: no es necesario (decisión del usuario, 9-oct-2026). Exportar/Importar JSON sigue disponible en Ajustes.
   - [x] GitHub Pages redirige a la app: rama `gh-pages` (solo `index.html`/`404.html` de redirección) y fuente de Pages apuntada a ella. `main` solo se despliega en Vercel.
   - [x] `CLAUDE.md` y un `privacidad.html` breve.
2. **Backend de alarmas**, sin dependencias npm, igual que ncs-app: Upstash por REST con `fetch`, helpers en `api/_store.js`.
   - [x] Claves VAPID (script en `tools/`).
   - [x] `api/push/subscribe.js`: guarda la suscripción de cada persona.
   - [x] `api/alarms/schedule.js`: POST guarda la alarma y la programa en QStash (`Upstash-Not-Before`); DELETE la cancela al editar o borrar la tarea.
   - [x] `api/alarms/fire.js`: lo llama QStash; valida el secreto (`Upstash-Forward-Authorization` + `secretsMatch()`), comprueba que la alarma siga vigente y envía un push vacío firmado con VAPID (JWT ES256 con `crypto.subtle`).
   - [x] `api/cron/queue.js` + `crons` en `vercel.json` (ventana de 24 h de QStash).
   - [x] `api/alarms/due.js`: lo llama el service worker tras el push; devuelve las alarmas vencidas y las marca como disparadas.
3. **Cliente**
   - [x] Suscribirse con `pushManager.subscribe`; llamar a `schedule` al guardar o editar y a DELETE al borrar.
   - [x] `sw.js`: handler `push` (fetch a `due` y `showNotification`; si falla, notificación genérica "Tienes una alarma". En iOS cada push debe mostrar una notificación).
4. **Variables de entorno en Vercel**: `UPSTASH_REDIS_REST_*`, `QSTASH_TOKEN`, claves VAPID, `ALARM_SECRET`, `CRON_SECRET`, `TAREAS_ORIGIN`.

### Mejoras posteriores a la Fase B (hechas)
- [x] Posponer alarmas: botón *Posponer 10 min* en la notificación (no iOS) y hoja al tocarla con *Posponer 10 min*, *Elegir hora* y *Hecho*.
- [x] Vibración y `requireInteraction` en las notificaciones. El sonido no es configurable desde la web: lo decide el teléfono.

### Fase D: widget de escritorio para Mac (completa, 14-oct-2026)
Widget de **solo lectura** con la lista de HOY, al fondo del escritorio. Marcar tareas se sigue haciendo en el celular. Reabre el sync de forma reducida: el celular publica una instantánea, el Mac solo lee (sin merge ni conflictos).
- [x] Prototipo de la ventana (`widget/`, Swift/AppKit, solo Command Line Tools): nivel de escritorio, en todos los Spaces, fuera de Cmd-Tab, arrastrable. Probado con datos falsos.
- [x] `widget/install.sh` y `uninstall.sh`: LaunchAgent con `RunAtLoad` y `KeepAlive`.
- [x] Servidor: `POST` de la instantánea y `GET` de lectura, con token de solo lectura derivado del código. Clave `tareas:snapshot:<code>`.
- [x] Celular: subir la instantánea de HOY tras cada cambio (retraso 1–2 s), marca de pendiente y reintento al abrir, al volver al primer plano y al recuperar la red.
- [x] Widget: leer cada 2–5 min, mostrar "actualizado hace X" y atenuar si la instantánea es de otro día. Sin la hora de la alarma.
- [x] Arranque automático instalado (`widget/install.sh`, 14-oct-2026). Escala por defecto 80 % (menú de clic derecho); clic en una fila la tacha solo en el Mac.
- Para actualizar el widget tras cambiar `widget/main.swift`: `./widget/install.sh` (recompila si falta `build/`; borra `widget/build` para forzarlo).
- Descartado para el widget: marcar tareas, notificaciones propias en el Mac. El espejo de notificaciones de iOS no funcionó en las pruebas (problema del sistema); si se quiere, la alternativa es guardar varias suscripciones push por código.

### Fase E: programar tareas y vista de Mañana (construida el 14-oct-2026)
Hecho, un commit por cambio y cada uno sobre el anterior:
- [x] Programar: campo `dia` + hora opcional, migración de alarmas, regla de HOY y entrada automática (reemplaza Alarma).
- [x] Vista **Próximos** (HOY + cada día con tareas programadas; Mañana siempre visible).
- [x] Aviso diario de **plazos por planificar** (primera apertura del día, hasta el siguiente día hábil) y su banner en Próximos.
- [x] Detector de duplicados v1 (puntaje logístico con pesos a mano, umbral 0.7, memoria de pares descartados).
- [x] Detector v2: aprendizaje en línea con las respuestas, señal de título idéntico y reinicio en Ajustes.
- [x] Widget: sección de lo programado hasta el siguiente día hábil.
- Sin probar en dispositivo real: la interfaz nueva se probó con pruebas de lógica en Node (modelo, reglas, detector, instantánea), no en el iPhone. Para actualizar el widget: `./widget/install.sh`.
- Pendiente de decidir (sin construir): detector al *programar* una tarea existente (hoy solo al crear), feriados en los días hábiles, y mostrar en Próximos las tareas que solo tienen Plazo.

Texto original de la idea, para referencia:
Inspirada en Things 3. Nada de esto está construido; son decisiones por tomar antes de tocar código.

**1. «Programar» en lugar de «Alarma».** El fin de la alarma es decidir *cuándo* se hace una tarea. En vez de una hora de aviso, la tarea se programa para un día (y opcionalmente una hora, que es la que dispara la notificación).
- Atajos de un toque: *Hoy*, *Esta noche*, *Mañana*, *En 3 días*, *Otra…* (los de hoy de Alarma se reaprovechan).
- El día programado la tarea entra sola en HOY (`enHoy = true` al empezar ese día). Si tiene hora, además suena el push de siempre.
- Una tarea programada para el futuro no ocupa la lista de HOY hasta su día. Dónde se ve mientras tanto es una decisión abierta (ver abajo).
- Plazo sigue siendo distinto de Programar: Plazo = cuándo vence; Programar = cuándo la voy a hacer.

**2. Vista con Mañana (y próximos días).** Además de Todas y HOY, una vista tipo calendario con HOY arriba y debajo Mañana y los días siguientes, con lo programado.

**3. Rollover.** Lo que no se termina hoy debe quedar en HOY mañana. Hoy ya ocurre sin hacer nada: `enHoy` es manual y solo se quita a mano, así que no hay que construirlo. Lo que sí falta es lo contrario: que lo programado para mañana *entre* en HOY ese día.

**Decisiones tomadas (14-oct-2026)**
- **Un solo campo de fecha** con hora opcional («programada»). Las alarmas existentes se migran a «programada con hora».
- **Lo programado a futuro queda visible** en Todas (con su fecha) y en la vista de próximos; no se oculta como en Things.
- **Regla de HOY con prioridad:** una tarea nueva o editada con fecha programada *futura* no entra en HOY; en cualquier otro caso (sin fecha, o fecha de hoy) sí entra automáticamente. El día programado entra sola en HOY. Quitar la fecha no cambia si está en HOY.
- **Detector de duplicados:** al crear o programar una tarea, estimar la probabilidad de que sea duplicado de otra pendiente y avisar si supera un umbral, sobre todo si está programada en otra fecha. Solo avisa, no bloquea, y se puede descartar. Cada respuesta del usuario («es duplicado» / «no lo es») es una etiqueta para mejorar la estimación.
  - v1: puntaje a mano (palabras en común sin tildes ni mayúsculas, similitud de letras, mismo grupo, fechas cercanas) con umbral estricto y memoria de las parejas ya descartadas.
  - v2: el mismo puntaje como **regresión logística** entrenada en el propio dispositivo con las etiquetas (pocos parámetros, unas decenas de líneas de JS, sin dependencias). Parte de pesos a mano y los ajusta poco a poco.
  - Descartado por ahora: red neuronal o modelo de embeddings. Con un solo usuario habrá cientos de etiquetas al año, muy pocas para entrenarla, y un modelo de lenguaje en el navegador pesa decenas de MB y rompe el «sin dependencias».
- **Aviso diario de plazos sin planificar:** solo la primera apertura de cada día (no vuelve a salir al reabrir), listar las tareas que tienen Plazo en la ventana de «mañana» y no están programadas ni en HOY, para elegir cuáles activar hoy.
  - La ventana de «mañana» es hasta el *siguiente día hábil*, con días hábiles de lunes a viernes fijos: si hoy es viernes (o sábado/domingo), incluye sábado a lunes; el resto de la semana, solo mañana. El fin de semana solo se trabaja para ponerse al día, no se programa.
  - Cada tarea del aviso se activa con un toque (entra en HOY) o se descarta por hoy.

**Decisiones abiertas**
- Los feriados quedan fuera de esta fase.
- Umbral inicial del detector y qué señales entran en el puntaje de v1.
- Dónde se vuelve a consultar el aviso diario ya descartado (propuesta: desde la vista de próximos).
- Impacto: `sw.js` y `api/alarms/*` siguen igual (la hora sigue siendo un push); cambian el modelo de datos de `index.html`, el README y, opcionalmente, el widget (la instantánea podría llevar también lo de mañana).

### Fase C: pendiente de uso real
- ~~Sync de tareas entre dispositivos~~: **descartado** (decisión del usuario, 9-oct-2026). Cada dispositivo guarda sus propias tareas.
- ~~Probar en iPhone~~: **hecho**. Todas las pruebas se hicieron en iPhone (instalada en la pantalla de inicio).
- [x] Cron diario de las 07:00 UTC verificado con una alarma a más de 24 h (sonó correctamente; confirmado por el usuario el 14-oct-2026).

## Decisiones

- **Identidad por código** (32 hex, `crypto.getRandomValues`), como en ncs-app. Cada persona tiene el suyo; con 2 o 3 usuarios no hace falta más. El código identifica sus suscripciones y alarmas.
- **Push sin payload**: cifrar el payload exige `aes128gcm` a mano o `web-push`. En su lugar el servidor envía un push vacío y el service worker pide los títulos a `/api/alarms/due`. Mantiene el repo sin `package.json`.
- **QStash por REST, sin SDK.**
- **Descartado**: Notification Triggers (abandonado por Chrome), Periodic Background Sync (timing de horas, solo Chrome), ntfy.sh (depende de un tercero y de otra app), exportar `.ics` (manual).

## Esquema de datos en Redis

```
tareas:push:<code>    suscripción(es) push                                   TTL 2 años
tareas:alarm:<code>   hash taskId → { at, titulo, msgId, shown, fired }         TTL 2 años
tareas:pending        set de códigos con alarmas sin encolar (lo recorre el cron)
tareas:sync:<code>    (solo Fase C) blob con tareas + grupos                 TTL 2 años
```

Los datos de `push` y `alarm` nunca viajan al cliente tal cual; el cliente solo recibe lo que `due` le devuelve.

## Riesgos y puntos abiertos

- **iOS**: Web Push solo funciona con la app instalada en la pantalla de inicio (iOS 16.4+). Conviene saber qué dispositivos usan las 2 o 3 personas.
- **QStash gratuito: retraso máximo de 24 h** (dato confirmado por el usuario; 1000 mensajes por día). Las alarmas más lejanas se guardan sin encolar y un **cron diario de Vercel** (`api/cron/queue.js`, 07:00 UTC) las encola al entrar en la ventana (24 h menos 5 min, para no dejar huecos entre corridas). El plan Hobby corre el cron con hasta una hora de jitter; si una alarma venció sin encolarse, el cron manda el push de inmediato como rescate.
- **Código de sync como credencial**: quien lo tenga puede ver y programar alarmas. Aceptable aquí por el alcance y la ausencia de datos sensibles.
- **Plan Hobby de Vercel**: solo uso no comercial; encaja con un grupo cercano.
- **Permisos**: cada persona debe aceptar notificaciones y reinstalar la PWA en el dominio nuevo.
- **¿Misma base Upstash que ncs-app o una nueva?** Recomendado: una nueva, para poder rotar credenciales por separado. Pendiente de decidir.

## Requisitos previos del usuario (Fase B)

- Proyecto en Vercel con el repo conectado.
- Base Upstash Redis y token de QStash (cuenta gratuita de Upstash).
