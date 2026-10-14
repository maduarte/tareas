// Widget de escritorio de Tareas: ventana sin marco que vive en la capa del
// escritorio (debajo de todas las apps, encima de los íconos). Solo lectura.
// Lee la instantánea de HOY de /api/snapshot con el token de ~/.tareas-widget
// (línea 1: dirección de la app; línea 2: código de lectura). Ver PLAN.md, Fase D.
// Un clic en una fila la tacha solo en este Mac (no se sincroniza, se olvida al cambiar el día).
// El aspecto copia el tema oscuro de index.html (colores, tipografía, medidas).

import AppKit

struct Item {
    let titulo: String
    let grupo: String
    let color: NSColor
    let urgencia: String?   // "alta" | "media" | "baja"
    let plazo: Date?
    let alarma: Date?
}

struct Config { let base: String; let token: String }

enum Estado {
    case sinConfig
    case cargando
    case ok(items: [Item], fecha: String, at: Date, nombre: String, acento: NSColor)
}

let configPath = NSString(string: "~/.tareas-widget").expandingTildeInPath
let refreshSeconds: TimeInterval = 180

// ─── Paleta de la app (tema oscuro) ──────────────────────────────
func hex(_ s: String?, fallback: NSColor) -> NSColor {
    guard let s = s, s.count == 7, s.hasPrefix("#"), let v = UInt32(s.dropFirst(), radix: 16) else { return fallback }
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}
let cText = hex("#ecebe8", fallback: .white)
let cMid = hex("#b9b6b1", fallback: .gray)
let cLight = hex("#8f8c87", fallback: .gray)
let cDone = hex("#5d5a55", fallback: .darkGray)
let cBorder = hex("#34322f", fallback: .darkGray)
let cBg = hex("#1b1a19", fallback: .black)
let cAlta = hex("#ec6f6f", fallback: .red)
let cMedia = hex("#f0c64a", fallback: .yellow)
let cBaja = hex("#5cc07e", fallback: .green)
let cAccent = hex("#e05a5a", fallback: .red)

func urgColor(_ u: String?) -> NSColor? {
    switch u { case "alta": return cAlta; case "media": return cMedia; case "baja": return cBaja; default: return nil }
}

// Helvetica Neue, como la app; sin semibold (como en el navegador, 600 cae en negrita)
func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
    let name = weight.rawValue >= NSFont.Weight.semibold.rawValue ? "HelveticaNeue-Bold" : (weight.rawValue >= NSFont.Weight.medium.rawValue ? "HelveticaNeue-Medium" : "HelveticaNeue")
    return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

// ─── Fechas ──────────────────────────────────────────────────────
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

// Igual que fmtShort de la app
func corto(_ d: Date) -> String {
    let cal = Calendar.current
    let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
    let f = DateFormatter(); f.locale = Locale(identifier: "es_CL")
    if diff == 0 { f.dateFormat = "HH:mm"; return f.string(from: d) }
    if diff == -1 { return "ayer" }
    if diff == 1 { return "mañana" }
    f.dateFormat = (diff > 1 && diff < 7) ? "EEE" : "d MMM"
    return f.string(from: d).replacingOccurrences(of: ".", with: "")
}

func hace(_ d: Date) -> String {
    let m = Int(Date().timeIntervalSince(d) / 60)
    if m < 1 { return "ahora" }
    if m < 60 { return "hace \(m) min" }
    if m < 1440 { return "hace \(m / 60) h" }
    return "hace \(m / 1440) d"
}

// ─── Tachados locales: "fecha|grupo|título", solo los de la fecha vigente ─
let tachadasKey = "tachadas"
func claveTachada(_ fecha: String, _ it: Item) -> String { fecha + "|" + it.grupo + "|" + it.titulo }
func leerTachadas(_ fecha: String) -> Set<String> {
    Set((UserDefaults.standard.stringArray(forKey: tachadasKey) ?? []).filter { $0.hasPrefix(fecha + "|") })
}
func alternarTachada(_ fecha: String, _ it: Item) {
    var set = leerTachadas(fecha)
    let k = claveTachada(fecha, it)
    if set.contains(k) { set.remove(k) } else { set.insert(k) }
    UserDefaults.standard.set(Array(set), forKey: tachadasKey)
}

// ─── Vistas ──────────────────────────────────────────────────────
func texto(_ s: String, _ f: NSFont, _ c: NSColor, kern: CGFloat = 0) -> NSTextField {
    let t = NSTextField(labelWithString: "")
    t.attributedStringValue = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern])
    t.lineBreakMode = .byTruncatingTail
    t.maximumNumberOfLines = 1
    return t
}

func circulo(_ d: CGFloat, _ c: NSColor) -> NSView {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.cornerRadius = d / 2
    v.layer?.backgroundColor = c.cgColor
    v.translatesAutoresizingMaskIntoConstraints = false
    v.widthAnchor.constraint(equalToConstant: d).isActive = true
    v.heightAnchor.constraint(equalToConstant: d).isActive = true
    return v
}

// Fila clicable. No arrastra la ventana, para que el clic sea un clic.
final class ClickRow: NSStackView {
    var onTap: (() -> Void)?
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ p: NSPoint) -> NSView? { onTap == nil ? super.hitTest(p) : (frame.contains(p) ? self : nil) }
    override func mouseDown(with event: NSEvent) { onTap?() }
}

// Círculo de completar de la app: 24 px, borde 1,8 px; hecho = relleno con ✓
func check(done: Bool) -> NSView {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.cornerRadius = 12
    v.layer?.borderWidth = 1.8
    v.layer?.borderColor = (done ? cDone : cLight).cgColor
    v.layer?.backgroundColor = (done ? cDone : NSColor.clear).cgColor
    v.translatesAutoresizingMaskIntoConstraints = false
    v.widthAnchor.constraint(equalToConstant: 24).isActive = true
    v.heightAnchor.constraint(equalToConstant: 24).isActive = true
    if done {
        let c = texto("✓", font(14), cBg)
        c.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(c)
        c.centerXAnchor.constraint(equalTo: v.centerXAnchor).isActive = true
        c.centerYAnchor.constraint(equalTo: v.centerYAnchor).isActive = true
    }
    return v
}

func fila(_ it: Item, width: CGFloat, crossed: Bool, onTap: (() -> Void)?) -> NSView {
    // Meta a la derecha: urgencia, plazo (rojo si venció), alarma. Una tarea hecha no muestra meta.
    var meta: [NSView] = []
    if !crossed {
        if let c = urgColor(it.urgencia) { meta.append(circulo(9, c)) }
        if let p = it.plazo { meta.append(texto(corto(p), font(12, p < Date() ? .semibold : .regular), p < Date() ? cAlta : cLight)) }
        if let a = it.alarma { meta.append(texto(it.plazo != nil ? "🔔" : "🔔 " + corto(a), font(12), cLight)) }
    }
    let metaStack = NSStackView(views: meta)
    metaStack.orientation = .horizontal
    metaStack.spacing = 8
    metaStack.setContentHuggingPriority(.required, for: .horizontal)
    metaStack.setContentCompressionResistancePriority(.required, for: .horizontal)

    let t = NSTextField(wrappingLabelWithString: "")
    t.isSelectable = false
    var attrs: [NSAttributedString.Key: Any] = [.font: font(16), .foregroundColor: crossed ? cDone : cText]
    if crossed { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
    t.attributedStringValue = NSAttributedString(string: it.titulo, attributes: attrs)
    let gap: CGFloat = 12
    let metaW = meta.isEmpty ? 0 : metaStack.fittingSize.width + gap
    t.preferredMaxLayoutWidth = width - 24 - gap - metaW
    t.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    var views: [NSView] = [check(done: crossed), t]
    let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    views.append(spacer)
    if !meta.isEmpty { views.append(metaStack) }
    let h = NSStackView(views: views)
    h.orientation = .horizontal
    h.alignment = .centerY
    h.spacing = gap
    h.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
    h.translatesAutoresizingMaskIntoConstraints = false
    h.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true

    let linea = NSView()
    linea.wantsLayer = true
    linea.layer?.backgroundColor = cBorder.cgColor
    linea.translatesAutoresizingMaskIntoConstraints = false
    linea.heightAnchor.constraint(equalToConstant: 1).isActive = true

    let r = ClickRow(views: [h, linea])
    r.orientation = .vertical
    r.alignment = .leading
    r.spacing = 0
    h.widthAnchor.constraint(equalToConstant: width).isActive = true
    linea.widthAnchor.constraint(equalToConstant: width).isActive = true
    r.onTap = onTap
    return r
}

func cabeceraGrupo(_ nombre: String, _ color: NSColor, pendientes: Int, width: CGFloat) -> NSView {
    var views: [NSView] = [circulo(8, color), texto(nombre.uppercased(), font(12, .bold), cMid, kern: 1.08)]
    if pendientes > 0 { views.append(texto("\(pendientes)", font(12), cLight)) }
    let h = NSStackView(views: views)
    h.orientation = .horizontal
    h.alignment = .centerY
    h.spacing = 8
    h.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
    return h
}

final class Panel: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class Delegate: NSObject, NSApplicationDelegate {
    var win: Panel!
    let fondo = NSView()
    let ancho: CGFloat = 340          // ventana
    let interior: CGFloat = 300       // contenido (20 px de margen a cada lado, como la app)
    var estado: Estado = .cargando
    var aviso: String? = nil          // p. ej. "sin conexión"
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        // Negro translúcido, sin desenfoque gris
        fondo.wantsLayer = true
        fondo.layer?.cornerRadius = 16
        fondo.layer?.masksToBounds = true
        fondo.layer?.backgroundColor = NSColor(white: 0, alpha: 0.62).cgColor

        win = Panel(contentRect: NSRect(x: 0, y: 0, width: ancho, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = fondo
        win.appearance = NSAppearance(named: .darkAqua)
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
            win.setFrameTopLeftPoint(NSPoint(x: screen.maxX - ancho - 24, y: screen.maxY - 24))
        }
        win.orderFront(nil)

        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: refreshSeconds, repeats: true) { [weak self] _ in self?.fetch() }
        timer?.tolerance = 20
        // Al despertar el Mac, actualizar de inmediato
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.fetch() }
        // Reloj de "actualizado hace X" y cambio de día sin tocar la red
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
                if code == 404 { self.estado = .ok(items: [], fecha: "", at: .distantPast, nombre: "", acento: cAccent); self.aviso = "sin datos: abre la app del celular"; self.rebuild(); return }
                guard code == 200, let data = data,
                      let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let arr = j["items"] as? [[String: Any]] else { self.aviso = "error del servidor"; self.rebuild(); return }
                let items = arr.map { d in
                    Item(titulo: d["titulo"] as? String ?? "", grupo: d["grupo"] as? String ?? "",
                         color: hex(d["color"] as? String, fallback: cLight), urgencia: d["urgencia"] as? String,
                         plazo: (d["plazo"] as? String).flatMap(isoDate), alarma: (d["alarma"] as? String).flatMap(isoDate))
                }
                self.estado = .ok(items: items, fecha: j["fecha"] as? String ?? "", at: (j["at"] as? String).flatMap(isoDate) ?? Date(),
                                  nombre: j["nombre"] as? String ?? "", acento: hex(j["acento"] as? String, fallback: cAccent))
                self.aviso = nil
                self.rebuild()
            }
        }.resume()
    }

    func rebuild() {
        var nombre = "", acento = cAccent
        var pie = ""
        var vistas: [(NSView, CGFloat)] = []   // vista y espacio previo
        var dim = false

        switch estado {
        case .sinConfig:
            vistas.append((texto("Falta el archivo ~/.tareas-widget", font(13), cLight), 14))
        case .cargando:
            vistas.append((texto("Cargando…", font(13), cLight), 14))
        case .ok(let items, let fecha, let at, let n, let ac):
            nombre = n; acento = ac
            dim = !fecha.isEmpty && fecha != hoyKey()   // instantánea de otro día
            let marca = fecha.isEmpty ? hoyKey() : fecha
            let tachadas = leerTachadas(marca)
            if items.isEmpty {
                vistas.append((texto(dim ? "Lista de otro día" : "Nada marcado para HOY", font(13), cLight), 14))
            }
            // Grupos en el orden recibido; dentro de cada uno, lo tachado va al final (como lo hecho en la app)
            var orden: [String] = []
            for it in items where !orden.contains(it.grupo) { orden.append(it.grupo) }
            for g in orden {
                let del = items.filter { $0.grupo == g }
                let pend = del.filter { !tachadas.contains(claveTachada(marca, $0)) }
                let hechas = del.filter { tachadas.contains(claveTachada(marca, $0)) }
                vistas.append((cabeceraGrupo(g, del[0].color, pendientes: pend.count, width: interior), 14))
                for (i, it) in (pend + hechas).enumerated() {
                    let cruzada = tachadas.contains(claveTachada(marca, it))
                    vistas.append((fila(it, width: interior, crossed: cruzada, onTap: dim ? nil : { [weak self] in
                        alternarTachada(marca, it); self?.rebuild()
                    }), i == 0 ? 0 : 0))
                }
            }
            if at != .distantPast { pie = "actualizado " + hace(at) }
            if dim { pie = "de otro día · " + pie }
        }
        if let a = aviso { pie = pie.isEmpty ? a : pie + " · " + a }

        // Encabezado: "Tareas · Nombre", como la marca de la app
        let marcaStr = NSMutableAttributedString(string: "Tareas", attributes: [.font: font(20, .bold), .foregroundColor: cText, .kern: -0.5])
        if !nombre.isEmpty {
            marcaStr.append(NSAttributedString(string: " · ", attributes: [.font: font(20, .medium), .foregroundColor: cMid, .kern: -0.5]))
            marcaStr.append(NSAttributedString(string: nombre, attributes: [.font: font(20, .medium), .foregroundColor: acento, .kern: -0.5]))
        }
        let marca = NSTextField(labelWithString: "")
        marca.attributedStringValue = marcaStr
        marca.lineBreakMode = .byTruncatingTail

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 14, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(marca)
        marca.translatesAutoresizingMaskIntoConstraints = false
        marca.widthAnchor.constraint(equalToConstant: interior).isActive = true
        for (v, antes) in vistas {
            stack.addArrangedSubview(v)
            if let prev = stack.arrangedSubviews.dropLast().last { stack.setCustomSpacing(antes, after: prev) }
        }
        if !pie.isEmpty {
            let p = texto(pie, font(11), cLight)
            stack.addArrangedSubview(p)
            if let prev = stack.arrangedSubviews.dropLast().last { stack.setCustomSpacing(14, after: prev) }
        }
        stack.alphaValue = dim ? 0.45 : 1

        fondo.subviews.forEach { $0.removeFromSuperview() }
        fondo.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fondo.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: fondo.trailingAnchor),
            stack.topAnchor.constraint(equalTo: fondo.topAnchor),
        ])
        fondo.layoutSubtreeIfNeeded()
        // Cambiar el alto manteniendo fija la esquina superior izquierda
        let h = stack.fittingSize.height
        var f = win.frame
        f.origin.y += f.size.height - h
        f.size = NSSize(width: ancho, height: h)
        win.setFrame(f, display: true)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // sin ícono en el Dock ni en Cmd-Tab
let delegate = Delegate()
app.delegate = delegate
app.run()
