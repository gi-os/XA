# Film box faces

Gio's box designs (the StockBoxes board) as SVG, rendered to one JPEG face per stock and speed
into `XA/Resources/Boxes`. The app draws the DX strip and the lab tape on top.

    pip install resvg-py pillow
    # fonts used only for rendering (not shipped): Archivo (variable), Marcellus, Tinos, from google/fonts
    python render.py ../../XA/Resources/Boxes

`faces.py` holds the eight faces; `{ei}` is the speed and `{fit}` shrinks it to fit its slot.
