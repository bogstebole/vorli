"""Dodaje naslov iznad ekrana: raw/*.png → framed/ (6,9″) i framed-6.5/ (6,5″).
Pokretanje: python3 frame.py  (iz ovog foldera; treba Pillow i SF Mono iz Terminal.app)."""
from PIL import Image, ImageDraw, ImageFont
import os

FONTS = "/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/"
SHOTS = [  # raw fajl, naslov, podnaslov — redosled = redosled u App Store-u
    ("01-pocetna", "Gde odoše pare?", "Ceo mesec na jednom ekranu."),
    ("04-racun", "Skeniraj QR sa računa.", "Svaki artikal, za dve sekunde."),
    ("05-istorija-cena", "Vidi šta je poskupelo.", "Istorija cene svakog artikla."),
    ("03-kategorije", "Gde ide plata.", "Potrošnja po kategorijama."),
    ("02-racuni", "Svi računi na okupu.", "Po danima, sa zbirom dana."),
    ("06-lista-zelja", "Štedi za ono što želiš.", "Vidiš kad stižeš do cilja."),
]
SIZES = {"framed": (1320, 2868), "framed-6.5": (1284, 2778)}

for folder, (W, H) in SIZES.items():
    k = W / 1320
    title_font = ImageFont.truetype(FONTS + "SF-Mono-Medium.otf", round(76 * k))
    sub_font = ImageFont.truetype(FONTS + "SF-Mono-Regular.otf", round(44 * k))
    os.makedirs(folder, exist_ok=True)
    for i, (name, title, sub) in enumerate(SHOTS, 1):
        canvas = Image.new("RGB", (W, H), (10, 10, 10))
        d = ImageDraw.Draw(canvas)
        top = round(180 * k)
        d.text(((W - d.textlength(title, font=title_font)) / 2, top), title, font=title_font, fill=(245, 245, 245))
        d.text(((W - d.textlength(sub, font=sub_font)) / 2, top + round(124 * k)), sub, font=sub_font, fill=(150, 150, 150))
        y = round(490 * k)
        sh = H - y - round(56 * k)
        sw = round(sh * 1320 / 2868)
        shot = Image.open(f"raw/{name}.png").convert("RGB").resize((sw, sh), Image.LANCZOS)
        x = (W - sw) // 2
        r = round(96 * sh / 2294)
        mask = Image.new("L", (sw, sh), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=r, fill=255)
        canvas.paste(shot, (x, y), mask)
        d.rounded_rectangle((x - 1, y - 1, x + sw, y + sh), radius=r + 1, outline=(58, 58, 58), width=3)
        canvas.save(f"{folder}/{i:02d}-{name.split('-', 1)[1]}.png")
