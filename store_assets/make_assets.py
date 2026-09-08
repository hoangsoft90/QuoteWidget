"""Generate Play Store assets: icon.png (512x512) + feature_graphic.png (1024x500).

Brand: Your Words — seed #6750A4 (Material 3 primary from lib/main.dart).
Icon is upscaled from the app's xxxhdpi launcher icon (192x192).
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

BRAND = (103, 80, 164)        # #6750A4
BRAND_DARK = (76, 58, 128)    # #4C3A80
WHITE = (255, 255, 255)
FONT_DIR = "/usr/share/fonts/truetype/dejavu"
BOLD = f"{FONT_DIR}/DejaVuSans-Bold.ttf"
REG = f"{FONT_DIR}/DejaVuSans.ttf"

# ---------------------------------------------------------------- icon.png
src = Image.open(
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
).convert("RGBA")
icon = src.resize((512, 512), Image.LANCZOS)
# Play wants full-bleed: if the launcher source has transparent corners,
# fill them with the nearest edge colour so no alpha hole remains.
if icon.getextrema()[3][0] < 255:
    bg = icon.resize((1, 1), Image.LANCZOS).convert("RGBA")
    solid = Image.new("RGBA", icon.size, bg.getpixel((0, 0)))
    solid.alpha_composite(icon)
    icon = solid
icon.save("store_assets/icon.png", optimize=True)
print("icon.png", icon.size, "alpha-min:", icon.getextrema()[3][0])

# ---------------------------------------------------- feature_graphic.png
W, H = 1024, 500
M = 40  # safe margin per chplay.md brief

# diagonal gradient #6750A4 -> #4C3A80 via rotated linear gradient mask
grad = Image.linear_gradient("L").resize((W + H, W + H)).rotate(
    45, expand=False
)
mask = grad.crop((H // 2, H // 2 + W // 2 - 250, H // 2 + W, H // 2 + W // 2 + H - 250)).resize((W, H))
top = Image.new("RGB", (W, H), BRAND)
bot = Image.new("RGB", (W, H), BRAND_DARK)
fg = Image.composite(top, bot, mask)

draw = ImageDraw.Draw(fg)

# soft decorative giant quote mark, low alpha, top-left bleed
deco = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dd = ImageDraw.Draw(deco)
dd.text((M - 14, H // 2 - 210), "\u201C", font=ImageFont.truetype(BOLD, 420),
        fill=(255, 255, 255, 38))
fg = Image.alpha_composite(fg.convert("RGBA"), deco)
draw = ImageDraw.Draw(fg)

# headline + subtitle (left block)
title_font = ImageFont.truetype(BOLD, 92)
sub_font = ImageFont.truetype(REG, 26)
badge_font = ImageFont.truetype(BOLD, 22)
card_quote_font = ImageFont.truetype(REG, 22)
card_author_font = ImageFont.truetype(REG, 16)

tx, ty = M + 6, 128
draw.text((tx, ty), "Your Words", font=title_font, fill=WHITE)
tw = draw.textlength("Your Words", font=title_font)
draw.text((tx, ty + 118),
          "Quotes \u00b7 Vocabulary \u00b7 Reminders",
          font=sub_font, fill=(235, 230, 250))
draw.text((tx, ty + 156),
          "on your Home Screen",
          font=sub_font, fill=(235, 230, 250))
# underline accent
draw.rounded_rectangle([tx, ty + 208, tx + tw * 0.62, ty + 216],
                       radius=4, fill=(255, 255, 255, 200))

# widget mockup card (right side), tilted 6 degrees
cw, ch = 300, 168
card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
cd = ImageDraw.Draw(card)
cd.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=22, fill=WHITE)
quote = '"Discipline is choosing\nbetween what you want\nnow and what you want\nmost."'
cd.multiline_text((24, 20), quote, font=card_quote_font,
                  fill=(28, 27, 31), spacing=6)
cd.text((24, ch - 34), "\u2014  Abraham Lincoln",
        font=card_author_font, fill=(91, 87, 114))
# progress dots + tap hint
for i in range(5):
    color = BRAND if i == 0 else (210, 205, 222)
    cd.ellipse([cw - 96 + i * 16, ch - 28, cw - 88 + i * 16, ch - 20], fill=color)
card = card.rotate(6, expand=True, resample=Image.BICUBIC)
fg.alpha_composite(card, (W - card.width - M + 4, (H - card.height) // 2 + 6))

# badge bottom-right: One tap -> next quote
label = "One tap  \u2192  next quote"
bw = draw.textlength(label, font=badge_font)
pad = 14
bx1, by1 = W - M - bw - pad * 2, H - M - 44
draw.rounded_rectangle([bx1, by1, bx1 + bw + pad * 2, by1 + 40],
                       radius=20, fill=(28, 27, 31, 210))
draw.text((bx1 + pad, by1 + 8), label, font=badge_font, fill=WHITE)

fg.convert("RGB").save("store_assets/feature_graphic.png", optimize=True)
print("feature_graphic.png", fg.size)
