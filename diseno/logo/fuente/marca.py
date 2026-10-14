# Marca ToDoi en serif: pares To y Do apretados, 'a' cursiva escrita con pluma sobre la segunda 'o'
# e 'i' minúscula final. Ver generar.py.
from fontTools.ttLib import TTFont, TTCollection
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.basePen import BasePen
from fontTools.varLib import instancer

def abrir(spec):
    if spec.get('idx') is not None:
        return TTCollection(spec['ruta']).fonts[spec['idx']]
    f = TTFont(spec['ruta'])
    if 'fvar' in f:
        f = instancer.instantiateVariableFont(f, spec['ejes'])
    return f

class Plano(BasePen):          # aplana el contorno para medir con una línea horizontal
    def __init__(self, gs): super().__init__(gs); self.cs = []; self.cur = []
    def _moveTo(self, p): self.cur = [p]
    def _lineTo(self, p): self.cur.append(p)
    def _curveToOne(self, a, b, c):
        p0 = self.cur[-1]
        for i in range(1, 13):
            t = i / 12; u = 1 - t
            self.cur.append((u**3*p0[0]+3*u*u*t*a[0]+3*u*t*t*b[0]+t**3*c[0], u**3*p0[1]+3*u*u*t*a[1]+3*u*t*t*b[1]+t**3*c[1]))
    def _qCurveToOne(self, a, c):
        p0 = self.cur[-1]
        for i in range(1, 13):
            t = i / 12; u = 1 - t
            self.cur.append((u*u*p0[0]+2*u*t*a[0]+t*t*c[0], u*u*p0[1]+2*u*t*a[1]+t*t*c[1]))
    def _closePath(self): self.cs.append(self.cur); self.cur = []
    _endPath = _closePath

def grosor_asta(gs, name, y):
    """Ancho del trazo más cercano al centro de la letra en la altura y (unidades de la fuente)."""
    p = Plano(gs); gs[name].draw(p)
    xs = []
    for c in p.cs:
        for (x0, y0), (x1, y1) in zip(c, c[1:] + c[:1]):
            if (y0 <= y < y1) or (y1 <= y < y0):
                xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
    xs.sort()
    seg = [(xs[i], xs[i+1]) for i in range(0, len(xs) - 1, 2)]
    return min(seg, key=lambda a: abs((a[0]+a[1])/2 - sum(map(sum, seg))/ (2*len(seg))) )[1] - min(seg, key=lambda a: abs((a[0]+a[1])/2 - sum(map(sum, seg))/ (2*len(seg))) )[0] if seg else 0

def asta(gs, name, y):
    """(x0, x1) del trazo más cercano al centro de la letra en la altura y (unidades de la fuente)."""
    p = Plano(gs); gs[name].draw(p)
    xs = []
    for c in p.cs:
        for (x0, y0), (x1, y1) in zip(c, c[1:] + c[:1]):
            if (y0 <= y < y1) or (y1 <= y < y0):
                xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
    xs.sort()
    seg = [(xs[i], xs[i+1]) for i in range(0, len(xs) - 1, 2)]
    return max(seg, key=lambda a: a[1] - a[0])

def contornos(gs, name):
    from fontTools.pens.recordingPen import RecordingPen
    r = RecordingPen(); gs[name].draw(r)
    out, cur = [], []
    for op, args in r.value:
        cur.append((op, args))
        if op in ('closePath', 'endPath'): out.append(cur); cur = []
    return out

def dibujar(ops, gs, s, x, y0, base):
    """Dibuja operaciones grabadas con escala s, desplazadas x (px) y subidas y0 (unidades de la fuente)."""
    from fontTools.pens.recordingPen import replayRecording
    pen, bp = SVGPathPen(gs), BoundsPen(gs)
    for p_ in (pen, bp):
        replayRecording(ops, TransformPen(p_, (s, 0, 0, -s, x, base - y0 * s)))
    return pen.getCommands(), bp.bounds

def glifo(gs, name, s, x, base):
    pen, bp = SVGPathPen(gs), BoundsPen(gs)
    gs[name].draw(TransformPen(pen, (s, 0, 0, -s, x, base)))
    gs[name].draw(TransformPen(bp, (s, 0, 0, -s, x, base)))
    return pen.getCommands(), bp.bounds

def marca(font, fg, accent, bg=None, trazo=True, g_To=-8.0, g_oD=8.0, g_Do=1.0, g_I=0.04, H=200, final='i', aire=1.5):
    gs, cmap = font.getGlyphSet(), font.getBestCmap()
    cap = font['OS/2'].sCapHeight or 700
    s, base = 100.0 / cap, 150.0
    bx = BoundsPen(gs); gs[cmap[ord('x')]].draw(bx); xh = bx.bounds[3]
    sw = grosor_asta(gs, cmap[ord('I')], cap / 2) * s       # grosor del trazo = asta de la I
    # Colocación por bordes: cada letra queda a una distancia fija (en px) de la anterior
    gaps = {'o1': g_To, 'D': g_oD, 'o2': g_Do}
    items, prev_x1 = [], None
    for ch, key in (('T', None), ('o', 'o1'), ('D', 'D'), ('o', 'o2')):
        name = cmap[ord(ch)]
        d0, b0 = glifo(gs, name, s, 0, base)
        x = 24.0 - b0[0] if key is None else prev_x1 + gaps[key] - b0[0]
        d, b = glifo(gs, name, s, x, base)
        items.append((d, b)); prev_x1 = b[2]
    o2 = items[3][1]; wo = o2[2] - o2[0]
    # El trazo cubre toda la altura de la 'o': parte un poco por encima y su curva toca la base de la 'o'
    xc, ytop, yb = o2[2] - sw / 2, o2[1] + 0.10 * sw, o2[3] - 0.22 * sw
    import pluma
    pd, gotas, tail_end = pluma.trazo(xc, ytop, yb, 0.88 * sw)     # un poco más fino que la asta de la fuente
    # Letra final. La distancia del borde de la 'o' al asta se toma de la I con la separación de la D
    # (g_Do) y se multiplica por `aire`.
    nI = cmap[ord('I')]
    _, bI0 = glifo(gs, nI, s, 0, base)
    sI = asta(gs, nI, cap / 2)
    dist = ((sI[0] * s - bI0[0]) + g_Do) * aire                     # px desde la 'o' hasta el asta
    objetivo = prev_x1 + dist                                          # borde izquierdo del asta
    if final == 'I':
        xI = objetivo - sI[0] * s
        dI, bI = glifo(gs, nI, s, xI, base)
    else:
        ni = cmap[ord('i')]
        si = asta(gs, ni, xh / 2)
        cs = contornos(gs, ni)
        def tope(c):
            bp = BoundsPen(gs)
            from fontTools.pens.recordingPen import replayRecording
            replayRecording(c, bp); return bp.bounds
        punto = max(cs, key=lambda c: tope(c)[3])                      # el punto es el contorno más alto
        cuerpo = [op for c in cs if c is not punto for op in c]
        xi = objetivo - si[0] * s
        if final == 'i':        # la 'i' minúscula de la fuente
            d1, b1 = dibujar(cuerpo, gs, s, xi, 0, base)
            d2, b2 = dibujar(punto, gs, s, xi, 0, base)
        else:                   # 'i' alta: el cuerpo estirado hasta la altura de las mayúsculas y el punto encima
            nl = cmap[ord('l')]
            sl = asta(gs, nl, xh / 2)
            xl = objetivo - sl[0] * s
            d1, b1 = dibujar(contornos(gs, nl) and [op for c in contornos(gs, nl) for op in c], gs, s, xl, 0, base)
            bpl = BoundsPen(gs); gs[nl].draw(bpl)
            bpp = tope(punto); bpc = BoundsPen(gs)
            sube = (bpl.bounds[3] - xh) + 0                                 # el punto sube lo mismo que el asta
            cx_l = (sl[0] + sl[1]) / 2; cx_i = (si[0] + si[1]) / 2
            d2, b2 = dibujar(punto, gs, s, xl + (cx_l - cx_i) * s, sube, base)
        dI = d1 + d2
        bI = (min(b1[0], b2[0]), min(b1[1], b2[1]), max(b1[2], b2[2]), max(b1[3], b2[3]))
    W = max(bI[2], tail_end) + 24
    body = ''.join(f'<path d="{d}"/>' for d, _ in items) + f'<path d="{dI}"/>'
    rect = f'<rect width="{W:.0f}" height="{H}" fill="{bg}"/>' if bg else ''
    extra = ''
    if trazo:
        if bg:   # halo del color del fondo, recortado a la I: separa el trazo de la I sin despegarlo de la 'o'
            extra += (f'<clipPath id="soloI"><rect x="{bI[0]-2:.1f}" y="0" width="{bI[2]-bI[0]+40:.1f}" height="{H}"/></clipPath>'
                      f'<g clip-path="url(#soloI)">{pluma.svg(pd, gotas, bg, halo=bg, halo_w=0.24 * sw)}</g>')
        extra += pluma.svg(pd, gotas, accent)
    info = dict(o_d=items[3][0], o2=o2, pd=pd, gotas=gotas, sw=sw, tail_end=tail_end, ytop=ytop)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H}" width="{W:.0f}" height="{H}">{rect}'
            f'<g fill="{fg}">{body}</g>{extra}</svg>'), W, info

def icono(info, stem, accent='#e05a5a', size=512):
    import pluma
    o2, sw = info['o2'], info['sw']
    x0, x1 = o2[0], info['tail_end']
    y0, y1 = min(o2[1], info['ytop'] - sw / 2), o2[3]
    sc = 0.56 * size / (x1 - x0)
    tx, ty = size / 2 - sc * (x0 + x1) / 2, size / 2 - sc * (y0 + y1) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'<rect width="{size}" height="{size}" rx="{size*0.225}" fill="{accent}"/>'
            f'<g transform="translate({tx:.1f} {ty:.1f}) scale({sc:.4f})"><path d="{info["o_d"]}" fill="#fff"/>'
            f'{pluma.svg(info["pd"], info["gotas"], stem)}</g></svg>')
