# Generador del logo

`generar.py` dibuja los SVG de `diseno/logo/` a partir de los contornos de la fuente:

- `marca.py`: compone **ToDoi** (pares To y Do apretados, «i» minúscula final con 50 % más de aire) y el ícono.
- `pluma.py`: la «a» cursiva. Barre una plumilla de punta ancha inclinada (34°) a lo largo del trazo; el grosor sale de la dirección y de una presión suave. Arranque redondeado, salida en pelo y dos gotas de tinta.
- `marca_sans.py`: la versión sans anterior (Avenir Next), solo como referencia.

Requiere `fontTools` (`pip install fonttools`). La fuente principal, **DM Serif Display**, se incluye bajo la SIL Open Font License (`OFL.txt`), que permite usarla en un logo comercial.
