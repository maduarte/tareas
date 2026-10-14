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

avenir = '/System/Library/Fonts/Avenir Next.ttc'
if os.path.exists(avenir):    # la versión sans anterior, como referencia
    f = marca_sans.abrir({'ruta': avenir, 'idx': 2})
    open(OUT + 'wordmark-sans.svg', 'w').write(marca_sans.marca(f, *CLARO)[0])
print('listo:', OUT)
