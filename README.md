# Tareas

Aplicación de gestión de tareas personales construida como PWA (Progressive Web App). Una sola página HTML con JavaScript vanilla, sin dependencias externas.

## Características

### Gestión de tareas
- Crear, editar y eliminar tareas
- Propiedades por tarea:
  - Título
  - Grupo (categoría)
  - Nivel de urgencia: Alta (rojo), Media (amarillo), Baja (verde)
  - Deadline con fecha y hora
  - Alarma opcional (inactiva por defecto): al activarla, pide fecha/hora y dispara una notificación del navegador/teléfono en ese momento

### Vistas y filtros
- **Hoy**: tareas marcadas para el día actual (permanecen hasta completarlas o quitarlas)
- **Todas**: todas las tareas
- **Por grupo**: tabs por categoría con contador de pendientes

### Ordenamiento
- Orden manual (arrastrar y soltar)
- Por urgencia
- Por deadline
- Por grupo

### Grupos personalizados
- 5 categorías predefinidas: Casa, Personal, Julieta, Investigación, Proyectos
- Crear grupos con nombre, emoji y color personalizado
- Eliminar grupos sin tareas asignadas

### Alarmas y notificaciones
- Notificación del navegador (Notification API) al llegar la hora programada
- Se revisa cada 20 segundos y también al volver a la pestaña/app
- Funciona de forma confiable mientras la app esté abierta o en segundo plano reciente; no está garantizado si el navegador o la app están completamente cerrados (limitación inherente a una PWA sin backend)

### Exportación
- **Exportar JSON**: descarga el archivo con todos los datos (`tareas_YYYY-MM-DD.json`)

### PWA / Offline
- Service Worker con estrategia network-first y fallback a caché
- Instalable como app nativa en móvil y escritorio
- Soporte completo para iOS (meta tags de Apple)

## Almacenamiento

Datos guardados en `localStorage`, aislados por dispositivo/navegador (no se sincronizan entre usuarios ni dispositivos):

| Clave | Contenido |
|---|---|
| `tareas_v2` | Array de tareas en JSON |
| `tareas_ambitos_v1` | Configuración de grupos |

## Estructura del proyecto

```
tareas/
├── index.html      # App completa (HTML + CSS + JS)
├── manifest.json   # Manifiesto PWA
├── sw.js           # Service Worker
├── icon-192.png    # Ícono PWA 192×192
└── icon-512.png    # Ícono PWA 512×512
```

## Uso

Servir el directorio desde cualquier servidor estático con HTTPS (o `localhost`) — necesario para que el Service Worker y las notificaciones funcionen. Abrir la URL en el navegador del teléfono y usar "Agregar a pantalla de inicio" para instalarla como app.

La app está disponible en producción en `/tareas/` según la configuración del manifiesto.
