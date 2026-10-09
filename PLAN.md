# Plan: alarmas confiables y despliegue en Vercel

Estado: **Fases A y A2 implementadas; B y C pendientes**. Basado en `../ncs-app`, que ya resuelve en Vercel + Upstash Redis problemas parecidos (código de sync, namespaces, TTL).

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
- **HOY**: marca por tarea, rotulada solo "HOY" en mayúscula (también en el filtro Todas / HOY). **Se activa por defecto si la tarea no tiene Plazo.**
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
- [x] HOY por defecto cuando no hay Plazo; renombrar "Fecha" a "Plazo" (también en README).
- [x] Migración de datos: las tareas existentes conservan campos; las completadas viejas se borran en la primera carga.

### Fase B: alarmas con la app cerrada (futuro cercano)
Requiere backend, así que incluye la migración a Vercel.

1. **Migración a Vercel**
   - [x] Proyecto en Vercel, `vercel.json` copiado de ncs-app (`cleanUrls`, rewrite `/api/*`, headers de seguridad).
   - [x] `manifest.json`: `start_url` y `scope` a `/`.
   - [ ] Migrar los datos de cada persona: exportar JSON desde `maduarte.github.io`, importar en el dominio nuevo (otro origen, otro `localStorage`).
   - [ ] Retirar GitHub Pages o dejar una redirección con aviso.
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

### Fase C: solo si hace falta
- Sync de tareas entre dispositivos de la misma persona (`api/sync.js` por código, copiado de ncs-app) y badge de estado. Se hace si alguien usa la app en más de un dispositivo.

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
- **QStash gratuito: retraso máximo de 24 h** (dato confirmado por el usuario; 1000 mensajes por día). Las alarmas más lejanas se guardan sin encolar y un **cron diario de Vercel** (`api/cron/queue.js`, 07:00 UTC) las encola al entrar en la ventana. El plan Hobby corre el cron con hasta una hora de jitter; si una alarma venció sin encolarse, el cron manda el push de inmediato como rescate.
- **Código de sync como credencial**: quien lo tenga puede ver y programar alarmas. Aceptable aquí por el alcance y la ausencia de datos sensibles.
- **Plan Hobby de Vercel**: solo uso no comercial; encaja con un grupo cercano.
- **Permisos**: cada persona debe aceptar notificaciones y reinstalar la PWA en el dominio nuevo.
- **¿Misma base Upstash que ncs-app o una nueva?** Recomendado: una nueva, para poder rotar credenciales por separado. Pendiente de decidir.

## Requisitos previos del usuario (Fase B)

- Proyecto en Vercel con el repo conectado.
- Base Upstash Redis y token de QStash (cuenta gratuita de Upstash).
