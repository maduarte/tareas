# Tareas

Lista de tareas personal construida como PWA (Progressive Web App): una sola página HTML con JavaScript vanilla, sin dependencias externas. Pensada para parecerse a una lista en papel: una línea por tarea, separadas por grupo, con detalles opcionales.

## Características

### Lista por grupos
- Todas las tareas se muestran ordenadas por grupo, en secciones plegables (el estado plegado se recuerda).
- Cada tarea es una línea. A la derecha solo aparece lo que hayas configurado: punto de urgencia, plazo y alarma.
- Completar una tarea la tacha y la baja al final de su grupo. **Al terminar el día las completadas se borran** (no hay archivo).
- Filtro **Todas / HOY**. Al abrir la app se muestra HOY.

### Detalle opcional
Al tocar una línea se despliega en el mismo lugar, en este orden:
- **Alarma**: notificación a la hora elegida.
- **Plazo**: fecha y hora límite (se marca en rojo si venció).
- **Urgencia**: alta (rojo), media (amarillo) o baja (verde). Sin urgencia por defecto.
- **Grupo**: cambiar la tarea de grupo.
- **HOY**: marca la tarea para el filtro HOY. Se activa por defecto en las tareas sin plazo; al ponerle plazo se desactiva, salvo que la hayas cambiado a mano.
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

### Alarmas
- Notificación del navegador a la hora programada. Se revisa cada 20 segundos y al volver a la app.
- **Con la app cerrada**: Web Push programado desde el servidor (QStash). Se activa en Ajustes → «Alarmas con la app cerrada», o al poner la primera alarma. En iPhone hay que instalar antes la app en la pantalla de inicio (iOS 16.4+).
- Una alarma que no sonó a tiempo no se pierde en silencio: queda en un aviso arriba de la lista.

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
