// Ícono de macOS para el widget (lo llama generar.py: swiftc icono_mac.swift; ./icono_mac entrada.png salida.png).
// Toma el cuadrado completo y lo deja en 824/1024 con esquinas redondeadas y fondo transparente (rejilla de Apple).
import AppKit
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
let n = 1024, m: CGFloat = 100, r: CGFloat = 185
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let caja = NSRect(x: m, y: m, width: CGFloat(n) - 2 * m, height: CGFloat(n) - 2 * m)
NSBezierPath(roundedRect: caja, xRadius: r, yRadius: r).addClip()
img.draw(in: caja)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
