from PIL import Image, ImageDraw
import math

S = 512          # final size
SS = 4           # supersample factor for smooth edges
W = S * SS

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Rounded-square background with a subtle vertical gradient.
top = (74, 108, 247)
bot = (37, 62, 178)
grad = Image.new("RGBA", (1, W))
gd = ImageDraw.Draw(grad)
for y in range(W):
    t = y / (W - 1)
    gd.point((0, y), fill=(
        int(top[0] + (bot[0] - top[0]) * t),
        int(top[1] + (bot[1] - top[1]) * t),
        int(top[2] + (bot[2] - top[2]) * t),
        255,
    ))
grad = grad.resize((W, W))

mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    [0, 0, W - 1, W - 1], radius=int(W * 0.225), fill=255
)
img.paste(grad, (0, 0), mask)

# Key glyph: a ring plus a toothed shaft, drawn on its own layer.
key = Image.new("RGBA", (W, W), (0, 0, 0, 0))
kd = ImageDraw.Draw(key)
WHITE = (255, 255, 255, 255)

cx, cy = int(W * 0.375), int(W * 0.42)
r_out = int(W * 0.155)
ring_w = int(W * 0.062)

kd.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out],
           outline=WHITE, width=ring_w)

# Shaft running down-right at 45 degrees from the ring.
ang = math.radians(45)
sx = cx + int(r_out * math.cos(ang))
sy = cy + int(r_out * math.sin(ang))
ex = int(W * 0.775)
ey = int(W * 0.815)
kd.line([sx, sy, ex, ey], fill=WHITE, width=ring_w, joint="curve")

# Two teeth perpendicular to the shaft.
px, py = math.cos(ang - math.pi / 2), math.sin(ang - math.pi / 2)
for frac, length in ((0.62, 0.105), (0.82, 0.078)):
    bx = sx + (ex - sx) * frac
    by = sy + (ey - sy) * frac
    kd.line([bx, by, bx + px * W * length, by + py * W * length],
            fill=WHITE, width=ring_w, joint="curve")

img = Image.alpha_composite(img, key)
img = img.resize((S, S), Image.LANCZOS)
img.save("src/icon.png")
print("icon.png written:", img.size, img.mode)
