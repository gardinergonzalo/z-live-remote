#!/usr/bin/env python3
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("ZLiveIcon-1024.png")
SIZE = 1024
MAGENTA = (228, 0, 255)
WHITE = (242, 242, 240)

img = Image.new("RGB", (SIZE, SIZE), MAGENTA)
draw = ImageDraw.Draw(img)

for x0, x1 in [(116,168),(223,275),(330,381),(436,488)]:
    draw.rectangle((x0,147,x1,518), fill=WHITE)

for y0, y1 in [(147,198),(253,305),(360,412),(467,518)]:
    draw.rectangle((543,y0,915,y1), fill=WHITE)

font_candidates = [
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]
font_path = next((p for p in font_candidates if Path(p).exists()), None)
if font_path is None:
    raise SystemExit("No compatible system font found")

text = "Z LIVE"
target_width = 800
font_size = 280
while font_size > 100:
    font = ImageFont.truetype(font_path, font_size)
    box = draw.textbbox((0, 0), text, font=font)
    width = box[2] - box[0]
    height = box[3] - box[1]
    if width <= target_width and height <= 205:
        break
    font_size -= 2

box = draw.textbbox((0, 0), text, font=font)
width = box[2] - box[0]
x = (SIZE - width) / 2 - box[0]
y = 692 - box[1]
draw.text((x, y), text, font=font, fill=WHITE)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, "PNG", optimize=True)
print(OUT)
