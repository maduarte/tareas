# Marca ToDoI con contornos de una fuente + 'a' cursiva (trazo con cola) sobre la segunda 'o'.
from fontTools.ttLib import TTFont, TTCollection
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.varLib import instancer

def abrir(spec):
    if spec.get('idx') is not None:
        return TTCollection(spec['ruta']).fonts[spec['idx']]
    f = TTFont(spec['ruta'])
    if 'fvar' in f:
        f = instancer.instantiateVariableFont(f, spec['ejes'])
    return f

def glifo(gs, name, s, x, base):
    pen, bp = SVGPathPen(gs), BoundsPen(gs)
    gs[name].draw(TransformPen(pen, (s, 0, 0, -s, x, base)))
    gs[name].draw(TransformPen(bp, (s, 0, 0, -s, x, base)))
    return pen.getCommands(), bp.bounds

def marca(font, fg, accent, bg=None, track=3.0, trazo=True, gap_I=0.20, H=200):
    gs, cmap, hmtx, os2 = font.getGlyphSet(), font.getBestCmap(), font['hmtx'], font['OS/2']
    cap, xh = (os2.sCapHeight or 700), (os2.sxHeight or 500)
    s, base = 100.0 / cap, 150.0
    x, items = 24.0, []
    for ch in 'ToDo':
        name = cmap[ord(ch)]
        d, b = glifo(gs, name, s, x, base)
        items.append((d, b))
        x += hmtx[name][0] * s + track
    o2 = items[3][1]
    nI = cmap[ord('I')]
    _, bI0 = glifo(gs, nI, s, 0, base)
    sw = bI0[2] - bI0[0]                               # grosor del trazo = grosor de la I
    wo = o2[2] - o2[0]; k = wo / 74.0
    xc, ytop, yb = o2[2] - sw / 2, base - xh * s + sw / 2, base - sw / 2
    # Cola de la 'a' cursiva: baja por el borde derecho de la 'o', curva con radio R y sale hacia la derecha subiendo un poco
    R = 0.95 * sw
    cola = (f'M{xc:.1f} {ytop:.1f}V{yb-R:.1f}'
            f'C{xc:.1f} {yb-0.42*R:.1f} {xc+0.42*R:.1f} {yb:.1f} {xc+R:.1f} {yb:.1f}'
            f'C{xc+1.55*R:.1f} {yb:.1f} {xc+2.0*R:.1f} {yb-0.2*R:.1f} {xc+2.4*R:.1f} {yb-0.85*R:.1f}')
    tail_end = xc + 2.4 * R + sw / 2
    # I mayúscula con remates (así no se lee como una 'l'): barra del grosor de la fuente, remates de 2.7 sw
    wI, tI = 2.7 * sw, 0.78 * sw
    xI0 = max(x, tail_end + gap_I * wo)                  # borde izquierdo del remate
    cx = xI0 + wI / 2; top = base - 100.0
    dI = (f'M{xI0:.1f} {top:.1f}H{xI0+wI:.1f}V{top+tI:.1f}H{cx+sw/2:.1f}V{base-tI:.1f}H{xI0+wI:.1f}V{base:.1f}H{xI0:.1f}'
          f'V{base-tI:.1f}H{cx-sw/2:.1f}V{top+tI:.1f}H{xI0:.1f}Z')
    bI = (xI0, top, xI0 + wI, base)
    W = bI[2] + 24
    body = ''.join(f'<path d="{d}"/>' for d, _ in items)
    body += f'<path d="{dI}"/>'
    rect = f'<rect width="{W:.0f}" height="{H}" fill="{bg}"/>' if bg else ''
    extra = f'<path d="{cola}" fill="none" stroke="{accent}" stroke-width="{sw:.1f}" stroke-linecap="round" stroke-linejoin="round"/>' if trazo else ''
    info = dict(o_d=items[3][0], o2=o2, cola=cola, sw=sw, tail_end=tail_end, base=base, ytop=ytop)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H}" width="{W:.0f}" height="{H}">{rect}'
            f'<g fill="{fg}">{body}</g>{extra}</svg>'), W, info

def icono(info, stem, accent='#e05a5a', size=512):
    # La 'o' del fondo blanca + la cola, centradas en un cuadrado redondeado
    o2, sw = info['o2'], info['sw']
    x0, x1 = o2[0], info['tail_end']
    y0, y1 = min(o2[1], info['ytop'] - sw / 2), o2[3]
    sc = 0.56 * size / (x1 - x0)
    tx = size / 2 - sc * (x0 + x1) / 2
    ty = size / 2 - sc * (y0 + y1) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
            f'<rect width="{size}" height="{size}" rx="{size*0.225}" fill="{accent}"/>'
            f'<g transform="translate({tx:.1f} {ty:.1f}) scale({sc:.4f})"><path d="{info["o_d"]}" fill="#fff"/>'
            f'<path d="{info["cola"]}" fill="none" stroke="{stem}" stroke-width="{sw:.1f}" stroke-linecap="round" stroke-linejoin="round"/></g></svg>')
