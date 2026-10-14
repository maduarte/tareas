#!/usr/bin/env python3
# Regenera los SVG del logo en diseno/logo/ (necesita fontTools: pip install fonttools).
#   python3 diseno/logo/fuente/generar.py
# La marca principal usa DM Serif Display (OFL, incluida aquí). Las alternativas usan fuentes
# de macOS (Hoefler Text, Baskerville, Avenir Next): se omiten si no están instaladas.
import os, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import marca, marca_sans

OUT = os.path.dirname(AQUI) + '/'
SU = '/System/Library/Fonts/Supplemental/'
SERIF = {
    '': {'ruta': os.path.join(AQUI, 'DMSerifDisplay-Regular.ttf')},
    '-hoefler': {'ruta': SU + 'Hoefler Text.ttc', 'idx': 0},
    '-baskerville': {'ruta': SU + 'Baskerville.ttc', 'idx': 4},
}
CLARO, OSCURO = ('#2a2a2a', '#e05a5a', '#f8f7f5'), ('#ecebe8', '#ec6f6f', '#1b1a19')

for suf, spec in SERIF.items():
    if not os.path.exists(spec['ruta']):
        print('omitida (no instalada):', spec['ruta']); continue
    f = marca.abrir(spec)
    open(OUT + f'wordmark{suf}.svg', 'w').write(marca.marca(f, *CLARO)[0])
    open(OUT + f'wordmark{suf}-oscuro.svg', 'w').write(marca.marca(f, *OSCURO)[0])
    open(OUT + f'wordmark{suf}-sin-trazo.svg', 'w').write(marca.marca(f, *CLARO, trazo=False)[0])
    info = marca.marca(f, '#2a2a2a', '#e05a5a')[2]
    open(OUT + f'icono{suf}-tinta.svg', 'w').write(marca.icono(info, '#2a2a2a'))
    open(OUT + f'icono{suf}-blanco.svg', 'w').write(marca.icono(info, '#fff'))

# ── Para la app ──────────────────────────────────────────────────
import re, shutil, subprocess, tempfile
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))
f = marca.abrir(SERIF[''])

# Marca para el encabezado de index.html: colores por CSS (letras = currentColor, trazo = --accent,
# halo = --bg), sin fondo y recortada a las letras. Se inserta entre <!--marca--> y <!--/marca-->.
svg, W, _ = marca.marca(f, 'currentColor', '#010204', '#010203')
svg = re.sub(r'<rect [^>]*/>', '', svg, count=1)
svg = svg.replace('fill="#010203" stroke="#010203"', 'class="hal"').replace('fill="#010204"', 'class="acc"')
svg = svg.replace('soloI', 'marcaI')
svg = re.sub(r'viewBox="[^"]*" width="\d+" height="\d+"', f'viewBox="18 40 {W-36:.0f} 122" role="img" aria-label="ToDoi"', svg, count=1)
open(OUT + 'marca-web.svg', 'w').write(svg)
idx = os.path.join(RAIZ, 'index.html')
html = open(idx, encoding='utf-8').read()
if '<!--marca-->' in html:
    html = re.sub(r'<!--marca-->.*?<!--/marca-->', lambda _: '<!--marca-->' + svg + '<!--/marca-->', html, count=1, flags=re.S)
    open(idx, 'w', encoding='utf-8').write(html)

# Íconos PNG de la PWA: cuadrado completo (iOS y Android aplican su propia máscara). Solo en macOS.
info = marca.marca(f, '#2a2a2a', '#e05a5a')[2]
if shutil.which('qlmanage') and shutil.which('sips'):
    tmp = tempfile.mkdtemp()
    src = os.path.join(tmp, 'icono.svg')
    open(src, 'w').write(marca.icono(info, '#fff', size=1024, rx=0))
    subprocess.run(['qlmanage', '-t', '-s', '1024', '-o', tmp, src], capture_output=True)
    png = src + '.png'
    for nombre, lado in (('icon-512.png', 512), ('icon-192.png', 192), ('apple-touch-icon.png', 180)):
        destino = os.path.join(RAIZ, nombre)
        shutil.copy(png, destino)
        subprocess.run(['sips', '-z', str(lado), str(lado), destino], capture_output=True)

avenir = '/System/Library/Fonts/Avenir Next.ttc'

if os.path.exists(avenir):    # la versión sans anterior, como referencia
    f = marca_sans.abrir({'ruta': avenir, 'idx': 2})
    open(OUT + 'wordmark-sans.svg', 'w').write(marca_sans.marca(f, *CLARO)[0])
print('listo:', OUT)
