# Tareas

Lista de tareas personal construida como PWA (Progressive Web App): una sola página HTML con JavaScript vanilla, sin dependencias externas. Pensada para parecerse a una lista en papel: una línea por tarea, separadas por grupo, con detalles opcionales.

## Características

### Lista por grupos
- Todas las tareas se muestran ordenadas por grupo, en secciones plegables (el estado plegado se recuerda).
- Cada tarea es una línea. A la derecha solo aparece lo que hayas configurado: punto de urgencia, plazo y alarma.
- Completar una tarea la tacha y la baja al final de su grupo. **Al terminar el día las completadas se borran** (no hay archivo).
- Filtro **Todas / HOY**.

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
- Notificación del navegador (Notification API) a la hora programada.
- Se revisa cada 20 segundos y también al volver a la app.
- Funciona mientras la app esté abierta o en segundo plano reciente; no está garantizado con la app cerrada (limitación de una PWA sin backend). Ver [PLAN.md](PLAN.md) para la hoja de ruta.

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

## Estructura del proyecto

```
tareas/
├── index.html      # App completa (HTML + CSS + JS)
├── manifest.json   # Manifiesto PWA
├── sw.js           # Service Worker
├── icon-192.png    # Ícono PWA 192×192
├── icon-512.png    # Ícono PWA 512×512
├── PLAN.md         # Hoja de ruta (alarmas con la app cerrada, Vercel)
└── diseno/
    └── mockup.html # Mockup estático del diseño
```

## Uso

Servir el directorio desde un servidor estático con HTTPS (o `localhost`), necesario para el Service Worker y las notificaciones. Por ejemplo, `python3 -m http.server 8080` y abrir `http://localhost:8080`. En el teléfono, usar "Agregar a pantalla de inicio" para instalarla.

La app está disponible en producción en `/tareas/` según la configuración del manifiesto.
