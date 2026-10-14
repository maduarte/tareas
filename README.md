# ToDoi

Lista de tareas personal construida como PWA (Progressive Web App): una sola página HTML con JavaScript vanilla, sin dependencias externas. Pensada para parecerse a una lista en papel: una línea por tarea, separadas por grupo, con detalles opcionales.

## Características

### Lista por grupos
- Todas las tareas se muestran ordenadas por grupo, en secciones plegables (el estado plegado se recuerda).
- Cada tarea es una línea. A la derecha solo aparece lo que hayas configurado: punto de urgencia, plazo y alarma.
- Completar una tarea la tacha y la baja al final de su grupo. **Al terminar el día las completadas se borran** (no hay archivo).
- Filtro **Todas / HOY / Próximos**. Al abrir la app se muestra HOY.
- **Próximos**: HOY y, debajo, cada día con tareas programadas (Mañana siempre aparece). Cada fila muestra además su grupo.

### Detalle opcional
Al tocar una línea se despliega en el mismo lugar, en este orden:
- **Programar**: el día en que piensas hacer la tarea, con una hora opcional que dispara la notificación. Atajos de un toque: *En 10 min*, *Hoy 18:00* (si aún no pasó), *Mañana*, *Lunes* (si mañana no es día hábil) y *En 1 semana*; *Otra…* abre el día y la hora (opcional) y se confirma con OK.
  - Si la fecha es futura, la tarea **sale de HOY y entra sola ese día**; si es hoy, entra a HOY de inmediato. Quitarla de HOY después es manual. Las programadas a futuro siguen visibles en Todas con su día (📅).
- **Plazo**: fecha y hora límite (se marca en rojo si venció). Atajos: *Mañana 18:00*, *En 3 días* y *En 1 semana* (a las 18:00); *Otra…* abre el selector.
- **Urgencia**: alta (rojo), media (amarillo) o baja (verde). Sin urgencia por defecto.
- **Grupo**: cambiar la tarea de grupo.
- **HOY**: marca la tarea para el filtro HOY. Las tareas nuevas entran en HOY por defecto, y ponerles un plazo no lo cambia: solo la quitas tú.
- Eliminar.

### Orden dentro del grupo
- Las urgentes suben solas a la parte alta del grupo.
- Mantén presionada una tarea y arrástrala para ordenar a mano. **El orden manual siempre prevalece sobre la regla**: una tarea que moviste conserva su lugar aunque cambie su urgencia.

### Agregar tareas
- Botón **+** (abajo a la derecha, para usar con una mano): escribe, elige el grupo con los chips (queda el último usado) y Enter. La hoja sigue abierta para agregar varias seguidas.
- Se pueden crear grupos desde esa misma hoja.

### Primer uso
Al abrir la app por primera vez pregunta el nombre, el modo (automático / claro / oscuro) y el color de acento, y si quieres crear algunos grupos ahora o definirlos al agregar tareas.

### Apariencia
Modo claro y oscuro (automático según el sistema, o fijo), con cinco colores de acento. Se cambian en Ajustes (⚙).

### Plazos por planificar
La primera vez que abres la app cada día, si hay tareas con **Plazo hasta el siguiente día hábil** (o ya vencido) que no están programadas ni en HOY, se ofrece una hoja para elegir cuáles activar hoy. Los días hábiles son lunes a viernes: un viernes la ventana llega hasta el lunes. Después se consulta desde el aviso 📌 de la vista Próximos.

### Duplicados
Al agregar una tarea parecida a otra pendiente, la app avisa («No es duplicada» / «Es duplicada»). Estima la probabilidad con una regresión logística sobre pocas señales (palabras en común, contención, letras, mismo grupo, fecha cercana, título idéntico) y **aprende de tus respuestas**, solo en el dispositivo. «Reiniciar aprendizaje» está en Ajustes.

### Alarmas
- Notificación del navegador a la hora programada. Se revisa cada 20 segundos y al volver a la app.
- **Con la app cerrada**: Web Push programado desde el servidor (QStash). Se activa en Ajustes → «Alarmas con la app cerrada», o al poner la primera alarma. En iPhone hay que instalar antes la app en la pantalla de inicio (iOS 16.4+).
- Una alarma que no sonó a tiempo no se pierde en silencio: queda en un aviso arriba de la lista.
- **Posponer:** al tocar la notificación se abre una hoja con *Posponer 10 min*, *Elegir hora* y *Hecho*. En Android y Chrome de escritorio la notificación trae además un botón *Posponer 10 min* que funciona sin abrir la app (iOS no muestra botones en notificaciones web).
- **Sonido:** lo decide el teléfono, no la app. En iPhone: Ajustes → Notificaciones → ToDoi; en Android: ajustes de notificaciones del navegador o de la app instalada. Desde la web solo se controla la vibración (Android) y que la notificación no se cierre sola (escritorio).

### Widget del Mac (opcional)
Ajustes → «Widget del Mac» publica la lista de HOY (título, grupo, urgencia y plazo) con cada cambio. El widget de escritorio ([widget/](widget/)) la lee con un código de solo lectura que se copia desde ahí; no permite marcar tareas.

### Datos
- **Exportar** e **Importar** un respaldo JSON desde Ajustes.

### PWA / Offline
- Service Worker con estrategia network-first y fallback a caché.
- Instalable en móvil y escritorio; incluye meta tags para iOS.

## Almacenamiento

Datos guardados en `localStorage`, aislados por dispositivo y navegador (no se sincronizan):

| Clave | Contenido |
|---|---|
| `tareas_v2` | Array de tareas |
| `tareas_ambitos_v1` | Grupos (`id`, `nombre`, `color`) |
| `tareas_username` | Nombre de la persona |
| `tareas_tema` | `sistema`, `claro` u `oscuro` |
| `tareas_acento` | Color de acento |
| `tareas_plegados` | Grupos plegados |
| `tareas_ultimo_grupo` | Último grupo usado al agregar |
| `tareas_onboarded` | El primer uso ya se completó |
| `tareas_codigo` | Código aleatorio del dispositivo (identifica sus alarmas en el servidor) |
| `tareas_push` | `1` si este dispositivo activó el push |
| `tareas_aviso` | Día (`AAAA-MM-DD`) del último aviso de plazos por planificar |
| `tareas_dup_no` | Pares de títulos ya descartados como no duplicados |
| `tareas_dup_w` | Pesos aprendidos del detector de duplicados |
| `tareas_widget` | `1` si este dispositivo publica la lista de HOY para el widget del Mac |
| `tareas_widget_pend` | `1` si hay una instantánea sin subir (se reintenta) |

## Estructura del proyecto

```
tareas/
├── index.html      # App completa (HTML + CSS + JS)
├── manifest.json   # Manifiesto PWA
├── sw.js           # Service Worker (caché + push)
├── vercel.json     # Headers de seguridad
├── privacidad.html # Qué se guarda y por cuánto tiempo
├── api/            # Funciones serverless (alarmas y push)
├── tools/          # vapid-keys.mjs
├── CLAUDE.md       # Contexto para trabajar en el repo
├── .env.example    # Nombres de las variables de entorno
├── icon-192.png    # Ícono PWA 192×192
├── icon-512.png    # Ícono PWA 512×512
├── PLAN.md         # Hoja de ruta (alarmas con la app cerrada, Vercel)
└── diseno/
    └── mockup.html # Mockup estático del diseño
```

## Uso

Servir el directorio desde un servidor estático con HTTPS (o `localhost`), necesario para el Service Worker y las notificaciones. Por ejemplo, `python3 -m http.server 8080` y abrir `http://localhost:8080`. En el teléfono, usar "Agregar a pantalla de inicio" para instalarla.

## Despliegue

Vercel, desde `main`. Para las alarmas con la app cerrada hacen falta una base Upstash Redis, un token de QStash y las claves VAPID; los nombres de las variables están en [.env.example](.env.example) y las claves se generan con `node tools/vapid-keys.mjs`. Detalles en [CLAUDE.md](CLAUDE.md).
