# Trazo de pluma de punta ancha: se barre una plumilla inclinada a lo largo de la línea central.
# El grosor sale solo de la dirección (bajada gruesa, salida hacia arriba casi un pelo) y de una presión suave.
import math

def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return (u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
            u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1])

def muestras(segs, n=260):
    largos = []
    for s in segs:
        pts = [bez(*s, i / 40) for i in range(41)]
        largos.append(sum(math.dist(a, b) for a, b in zip(pts, pts[1:])))
    tot = sum(largos); out = []
    for s, L in zip(segs, largos):
        k = max(4, round(n * L / tot))
        out += [bez(*s, i / k) for i in range(k if out else 0, k + 1)] if not out else [bez(*s, i / k) for i in range(1, k + 1)]
    return out

def trazo(xc, ytop, yb, sw, angulo=34, inclinacion=80):
    R = 1.1 * sw
    B = (xc, yb - R)                                  # aquí la bajada ya es vertical y empieza la curva
    alto = B[1] - ytop
    A0 = (xc + alto / math.tan(math.radians(inclinacion)), ytop)   # arranca arriba, inclinada ~80°
    C = (xc + R, yb)
    D = (xc + 2.6 * R, yb - 0.82 * R)                # salida a ~27°, siempre más plana que la plumilla (34°)
    segs = [
        (A0, (A0[0] - (A0[0] - xc) * 0.45, ytop + alto * 0.33), (xc, ytop + alto * 0.72), B),
        (B, (xc, yb - 0.4 * R), (xc + 0.4 * R, yb + 0.03 * R), C),
        (C, (xc + 1.45 * R, yb - 0.02 * R), (xc + 2.0 * R, yb - 0.5 * R), D),
    ]
    pts = muestras(segs)
    n = len(pts)
    phi = math.radians(angulo)
    w0 = sw / math.cos(phi)                          # la bajada vertical queda con el grosor de la asta de la fuente
    def presion(s):
        if s < 0.07: p = 0.82 + 0.18 * (s / 0.07)                      # la pluma se carga al apoyarse
        elif s < 0.50: p = 1.0
        elif s < 0.68: p = 1.0 - 0.14 * (s - 0.50) / 0.18              # alivia la presión en la curva
        else: p = 0.86 - 0.50 * ((s - 0.68) / 0.32) ** 1.6             # y se levanta al salir
        return p * (1 + 0.006 * math.sin(19 * s + 0.7))                  # pulso apenas perceptible
    quads = []
    prev = None
    for i, (x, y) in enumerate(pts):
        w = w0 * presion(i / (n - 1)) / 2
        v = (w * math.cos(phi), -w * math.sin(phi))
        a, b = (x + v[0], y + v[1]), (x - v[0], y - v[1])
        if prev:
            pa, pb = prev
            quads.append(f'M{pa[0]:.2f} {pa[1]:.2f}L{a[0]:.2f} {a[1]:.2f}L{b[0]:.2f} {b[1]:.2f}L{pb[0]:.2f} {pb[1]:.2f}Z')
        prev = (a, b)
    d = ''.join(quads)
    # Dos gotas pequeñas que salta la pluma al levantarse, en la dirección de la salida
    (x1, y1), (x2, y2) = pts[-6], pts[-1]
    L = math.dist((x1, y1), (x2, y2)); ux, uy = (x2 - x1) / L, (y2 - y1) / L
    px, py = -uy, ux
    rot = math.degrees(math.atan2(uy, ux))
    gotas = [
        (x2 + ux * 0.62 * sw - px * 0.10 * sw, y2 + uy * 0.62 * sw - py * 0.10 * sw, 0.12 * sw, 0.095 * sw, rot),
        (x2 + ux * 1.12 * sw + px * 0.06 * sw, y2 + uy * 1.12 * sw + py * 0.06 * sw, 0.065 * sw, 0.055 * sw, rot + 25),
    ]
    # Arranque suave: la tinta se redondea donde la pluma se apoya (en vez del corte recto de la plumilla)
    w_ini = w0 * presion(0) / 2
    gotas.append((pts[0][0], pts[0][1] + 0.02 * sw, w_ini * 1.1, 0.19 * sw, -angulo))
    x_fin = max(max(p[0] for p in pts) + w0 / 2, max(g[0] + g[2] for g in gotas))
    return d, gotas, x_fin

def elipse_d(cx, cy, rx, ry, rot):
    a = math.radians(rot); ex, ey = rx * math.cos(a), rx * math.sin(a)
    return (f'M{cx-ex:.2f} {cy-ey:.2f}A{rx:.2f} {ry:.2f} {rot:.1f} 1 0 {cx+ex:.2f} {cy+ey:.2f}'
            f'A{rx:.2f} {ry:.2f} {rot:.1f} 1 0 {cx-ex:.2f} {cy-ey:.2f}Z')

def svg(d, gotas, color, halo=None, halo_w=0):
    g = ''.join(f'<ellipse cx="{cx:.2f}" cy="{cy:.2f}" rx="{rx:.2f}" ry="{ry:.2f}" transform="rotate({r:.1f} {cx:.2f} {cy:.2f})"/>' for cx, cy, rx, ry, r in gotas)
    # halo: contorno del color del fondo, para separar el trazo de lo que tiene debajo (la I)
    h = f' stroke="{halo}" stroke-width="{halo_w:.1f}" stroke-linejoin="round" paint-order="stroke"' if halo else ''
    return f'<g fill="{color}"{h}><path d="{d}"/>{g}</g>'
