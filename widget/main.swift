// Widget de escritorio de Tareas: ventana sin marco que vive en la capa del
// escritorio (debajo de todas las apps, encima de los íconos). Solo lectura.
// Lee la instantánea de HOY de /api/snapshot con el token de ~/.tareas-widget
// (línea 1: dirección de la app; línea 2: código de lectura). Ver PLAN.md, Fase D.

import AppKit

struct Item {
    let titulo: String
    let grupo: String
    let urgencia: String?   // "alta" | "media" | "baja"
    let plazo: Date?
}

struct Config { let base: String; let token: String }

enum Estado {
    case sinConfig
    case cargando
    case ok(items: [Item], fecha: String, at: Date)
}

let configPath = NSString(string: "~/.tareas-widget").expandingTildeInPath
let refreshSeconds: TimeInterval = 180

func readConfig() -> Config? {
    guard let raw = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
    let lines = raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    guard lines.count >= 2, lines[0].hasPrefix("http"), lines[1].count == 64 else { return nil }
    return Config(base: lines[0].hasSuffix("/") ? String(lines[0].dropLast()) : lines[0], token: lines[1])
}

func isoDate(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

func hoyKey() -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

func color(_ u: String?) -> NSColor {
    switch u {
    case "alta": return NSColor(srgbRed: 0.88, green: 0.30, blue: 0.27, alpha: 1)
    case "media": return NSColor(srgbRed: 0.93, green: 0.69, blue: 0.20, alpha: 1)
    case "baja": return NSColor(srgbRed: 0.35, green: 0.70, blue: 0.40, alpha: 1)
    default: return NSColor.tertiaryLabelColor
    }
}

func plazoTexto(_ d: Date) -> (String, Bool) {
    let cal = Calendar.current
    let late = d < Date()
    let f = DateFormatter(); f.locale = Locale(identifier: "es_CL")
    if cal.isDateInToday(d) { f.dateFormat = "HH:mm"; return (f.string(from: d), late) }
    if cal.isDateInTomorrow(d) { return ("mañana", false) }
    if cal.isDateInYesterday(d) { return ("ayer", true) }
    f.dateFormat = late ? "d MMM" : "EEE"
    return (f.string(from: d).replacingOccurrences(of: ".", with: ""), late)
}

func label(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let t = NSTextField(labelWithString: s)
    t.font = NSFont.systemFont(ofSize: size, weight: weight)
    t.textColor = color
    t.lineBreakMode = .byTruncatingTail
    t.maximumNumberOfLines = 1
    return t
}

func row(_ it: Item, dim: Bool) -> NSView {
    let dot = NSView()
    dot.wantsLayer = true
    dot.layer?.cornerRadius = 4
    dot.layer?.backgroundColor = color(it.urgencia).cgColor
    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
    dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

    let title = label(it.titulo, size: 13, weight: .medium)
    title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let col = NSStackView(views: [title, label(it.grupo, size: 11, color: .secondaryLabelColor)])
    col.orientation = .vertical
    col.alignment = .leading
    col.spacing = 1

    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    var views: [NSView] = [dot, col, spacer]
    if let p = it.plazo {
        let (txt, late) = plazoTexto(p)
        views.append(label(txt, size: 11, weight: .medium, color: late ? color("alta") : .secondaryLabelColor))
    }
    let h = NSStackView(views: views)
    h.orientation = .horizontal
    h.alignment = .centerY
    h.spacing = 10
    h.alphaValue = dim ? 0.45 : 1
    return h
}

func hace(_ d: Date) -> String {
    let m = Int(Date().timeIntervalSince(d) / 60)
    if m < 1 { return "ahora" }
    if m < 60 { return "hace \(m) min" }
    if m < 1440 { return "hace \(m / 60) h" }
    return "hace \(m / 1440) d"
}

final class Panel: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class Delegate: NSObject, NSApplicationDelegate {
    var win: Panel!
    let fx = NSVisualEffectView()
    let width: CGFloat = 300
    var estado: Estado = .cargando
    var aviso: String? = nil   // p. ej. "sin conexión"
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        fx.material = .popover
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 16
        fx.layer?.masksToBounds = true

        win = Panel(contentRect: NSRect(x: 0, y: 0, width: width, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = fx
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        // Encima de los íconos del escritorio, debajo de cualquier ventana normal
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.isMovableByWindowBackground = true
        let tieneGuardada = !(UserDefaults.standard.string(forKey: "NSWindow Frame TareasWidget") ?? "").isEmpty
        win.setFrameAutosaveName("TareasWidget")
        rebuild()
        if !tieneGuardada {
            let screen = NSScreen.main!.visibleFrame
            win.setFrameTopLeftPoint(NSPoint(x: screen.maxX - width - 24, y: screen.maxY - 24))
        }
        win.orderFront(nil)

        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: refreshSeconds, repeats: true) { [weak self] _ in self?.fetch() }
        timer?.tolerance = 20
        // Al despertar el Mac, actualizar de inmediato
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.fetch() }
        // Reloj de "hace X" y cambio de día sin tocar la red
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.rebuild() }
    }

    func fetch() {
        guard let cfg = readConfig() else { estado = .sinConfig; rebuild(); return }
        guard let url = URL(string: cfg.base + "/api/snapshot?token=" + cfg.token) else { return }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if err != nil || code == 0 { self.aviso = "sin conexión"; self.rebuild(); return }
                if code == 404 { self.estado = .ok(items: [], fecha: "", at: .distantPast); self.aviso = "sin datos: abre la app del celular"; self.rebuild(); return }
                guard code == 200, let data = data,
                      let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let arr = j["items"] as? [[String: Any]] else { self.aviso = "error del servidor"; self.rebuild(); return }
                let items = arr.map { Item(titulo: $0["titulo"] as? String ?? "", grupo: $0["grupo"] as? String ?? "",
                                           urgencia: $0["urgencia"] as? String, plazo: ($0["plazo"] as? String).flatMap(isoDate)) }
                self.estado = .ok(items: items, fecha: j["fecha"] as? String ?? "", at: (j["at"] as? String).flatMap(isoDate) ?? Date())
                self.aviso = nil
                self.rebuild()
            }
        }.resume()
    }

    func rebuild() {
        let titulo = label("HOY", size: 11, weight: .bold, color: .secondaryLabelColor)
        var rows: [NSView] = []
        var pie = ""
        var dim = false
        var count = ""
        switch estado {
        case .sinConfig:
            rows = [label("Falta el archivo ~/.tareas-widget", size: 12, color: .secondaryLabelColor)]
        case .cargando:
            rows = [label("Cargando…", size: 12, color: .secondaryLabelColor)]
        case .ok(let items, let fecha, let at):
            dim = !fecha.isEmpty && fecha != hoyKey()   // instantánea de otro día
            count = items.isEmpty ? "" : "\(items.count)"
            rows = items.map { row($0, dim: dim) }
            if items.isEmpty { rows = [label(dim ? "Lista de otro día" : "Nada para hoy", size: 12, color: .secondaryLabelColor)] }
            if at != .distantPast { pie = "actualizado " + hace(at) }
            if dim { pie = "de otro día · " + pie }
        }
        if let a = aviso { pie = pie.isEmpty ? a : pie + " · " + a }

        let head = NSStackView(views: [titulo, NSView(), label(count, size: 11, weight: .medium, color: .tertiaryLabelColor)])
        head.orientation = .horizontal
        var all: [NSView] = [head] + rows
        if !pie.isEmpty { all.append(label(pie, size: 10, color: .tertiaryLabelColor)) }
        let stack = NSStackView(views: all)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for v in all { v.translatesAutoresizingMaskIntoConstraints = false; v.widthAnchor.constraint(equalToConstant: width - 32).isActive = true }

        fx.subviews.forEach { $0.removeFromSuperview() }
        fx.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            stack.topAnchor.constraint(equalTo: fx.topAnchor),
        ])
        fx.layoutSubtreeIfNeeded()
        // Cambiar el alto manteniendo fija la esquina superior izquierda
        let h = stack.fittingSize.height
        var f = win.frame
        f.origin.y += f.size.height - h
        f.size = NSSize(width: width, height: h)
        win.setFrame(f, display: true)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // sin ícono en el Dock ni en Cmd-Tab
let delegate = Delegate()
app.delegate = delegate
app.run()
