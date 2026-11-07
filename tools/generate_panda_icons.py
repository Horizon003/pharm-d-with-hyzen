"""Deterministic launcher assets from the approved image. Requires Pillow.
Run from the repository root: python tools/generate_panda_icons.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'hyzen_flutter'
SOURCE = ROOT / 'docs/reference/account/panda_launcher_original.jpeg'
RES = ROOT / 'android/app/src/main/res'
image = Image.open(SOURCE).convert('RGB')
assert image.width == image.height, 'Keep the approved square artwork intact'
resample = Image.Resampling.LANCZOS
# All of the original square fits within Android's 66dp safe circle on a 108dp
# adaptive layer (46dp square diagonal < 66dp). Do not crop the cap or ears.
for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2),
                       ('xxhdpi', 3), ('xxxhdpi', 4)]:
    folder = RES / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    legacy = image.resize((round(48 * scale),) * 2, resample)
    legacy.save(folder / 'ic_launcher.png', optimize=True)
    # Keep the supplied square artwork at full legacy-icon size so the logo
    # does not appear undersized when Android applies the round mask.
    circle = Image.new('RGBA', legacy.size, (255, 255, 255, 0))
    ImageDraw.Draw(circle).ellipse((0, 0, legacy.width-1, legacy.height-1), fill='white')
    round_art = image.resize(legacy.size, resample)
    circle.paste(round_art, ((legacy.width-round_art.width)//2, (legacy.height-round_art.height)//2))
    circle.save(folder / 'ic_launcher_round.png', optimize=True)
    side = round(108 * scale)
    foreground = Image.new('RGBA', (side, side), (255, 255, 255, 0))
    # 64dp gives the adaptive foreground a readable size while keeping the
    # cap and ears inside Android's launcher safe zone in normal masks.
    artwork = image.resize((round(64 * scale),) * 2, resample)
    foreground.paste(artwork, ((side-artwork.width)//2, (side-artwork.height)//2))
    foreground.save(folder / 'ic_launcher_foreground.png', optimize=True)
for name, size in [('hyzen_icon_square.png', 512)]:
    image.resize((size, size), resample).save(ROOT / 'assets/brand' / name, optimize=True)
web = ROOT / 'web'
(web / 'icons').mkdir(parents=True, exist_ok=True)
image.resize((48, 48), resample).save(web / 'favicon.png', optimize=True)
for size in (192, 512):
    image.resize((size, size), resample).save(web / f'icons/Icon-{size}.png', optimize=True)
    # Maskable PWA icons have their own 80% diameter safe zone.
    maskable = Image.new('RGB', (size, size), 'white')
    art = image.resize((round(size * .56),) * 2, resample)
    maskable.paste(art, ((size-art.width)//2, (size-art.height)//2))
    maskable.save(web / f'icons/Icon-maskable-{size}.png', optimize=True)
