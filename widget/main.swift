// Widget de escritorio de Tareas: ventana sin marco que vive en la capa del
// escritorio (debajo de todas las apps, encima de los íconos). Solo lectura.
// Prototipo: datos falsos. Ver PLAN.md.

import AppKit

struct Item {
    let titulo: String
    let grupo: String
    let urgencia: String?   // "alta" | "media" | "baja"
    let plazo: String?
}

let demo: [Item] = [
    Item(titulo: "Llamar al contador", grupo: "Trabajo", urgencia: "alta", plazo: "10:30"),
    Item(titulo: "Comprar pan y leche", grupo: "Casa", urgencia: nil, plazo: nil),
    Item(titulo: "Revisar el borrador del informe", grupo: "Trabajo", urgencia: "media", plazo: "18:00"),
    Item(titulo: "Pagar la cuenta de la luz", grupo: "Casa", urgencia: "alta", plazo: "mañana"),
    Item(titulo: "Reservar hora con el dentista", grupo: "Salud", urgencia: "baja", plazo: nil),
]

func color(_ u: String?) -> NSColor {
    switch u {
    case "alta": return NSColor(srgbRed: 0.88, green: 0.30, blue: 0.27, alpha: 1)
    case "media": return NSColor(srgbRed: 0.93, green: 0.69, blue: 0.20, alpha: 1)
    case "baja": return NSColor(srgbRed: 0.35, green: 0.70, blue: 0.40, alpha: 1)
    default: return NSColor.tertiaryLabelColor
    }
}

func label(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let t = NSTextField(labelWithString: s)
    t.font = NSFont.systemFont(ofSize: size, weight: weight)
    t.textColor = color
    t.lineBreakMode = .byTruncatingTail
    t.maximumNumberOfLines = 1
    return t
}

func row(_ it: Item) -> NSView {
    let dot = NSView()
    dot.wantsLayer = true
    dot.layer?.cornerRadius = 4
    dot.layer?.backgroundColor = color(it.urgencia).cgColor
    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
    dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

    let title = label(it.titulo, size: 13, weight: .medium)
    title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let sub = label(it.grupo, size: 11, color: .secondaryLabelColor)
    let col = NSStackView(views: [title, sub])
    col.orientation = .vertical
    col.alignment = .leading
    col.spacing = 1

    var views: [NSView] = [dot, col]
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    views.append(spacer)
    if let p = it.plazo { views.append(label(p, size: 11, weight: .medium, color: .secondaryLabelColor)) }
    let h = NSStackView(views: views)
    h.orientation = .horizontal
    h.alignment = .centerY
    h.spacing = 10
    return h
}

final class Panel: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class Delegate: NSObject, NSApplicationDelegate {
    var win: Panel!

    func applicationDidFinishLaunching(_ n: Notification) {
        let width: CGFloat = 300
        let fx = NSVisualEffectView()
        fx.material = .popover
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 16
        fx.layer?.masksToBounds = true

        let head = NSStackView(views: [label("HOY", size: 11, weight: .bold, color: .secondaryLabelColor), NSView(), label("\(demo.count)", size: 11, weight: .medium, color: .tertiaryLabelColor)])
        head.orientation = .horizontal
        let stack = NSStackView(views: [head] + demo.map(row))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            stack.topAnchor.constraint(equalTo: fx.topAnchor),
            stack.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
            fx.widthAnchor.constraint(equalToConstant: width),
        ])
        for v in stack.arrangedSubviews { v.translatesAutoresizingMaskIntoConstraints = false; v.widthAnchor.constraint(equalToConstant: width - 32).isActive = true }

        let size = fx.fittingSize
        let screen = NSScreen.main!.visibleFrame
        let origin = NSPoint(x: screen.maxX - size.width - 24, y: screen.maxY - size.height - 24)
        win = Panel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = fx
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        // Encima de los íconos del escritorio, debajo de cualquier ventana normal
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.isMovableByWindowBackground = true
        win.setFrameAutosaveName("TareasWidget")
        win.orderFront(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // sin ícono en el Dock ni en Cmd-Tab
let delegate = Delegate()
app.delegate = delegate
app.run()
