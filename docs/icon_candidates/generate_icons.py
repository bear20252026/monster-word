"""
Launcher Icon Candidate Generator for Monster Word
Generates 4 concept mockups per launcher_icon_brief.md spec.
All icons: 1024x1024, flat design, no gradients/shadows.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024

GREEN_DARK = (0, 98, 65)       # #006241 Starbucks Green
GREEN_ACCENT = (0, 117, 74)    # #00754A Green Accent
WHITE = (255, 255, 255)
GREEN_PUPIL = (0, 60, 40)      # dark green for eye pupils

def new_canvas(color):
    img = Image.new("RGB", (SIZE, SIZE), color)
    return img, ImageDraw.Draw(img)

def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    print(f"  saved: {name} ({img.size[0]}x{img.size[1]})")

# ============================================================
# A1: Monster M with Eyes (亲和向)
# ============================================================
def draw_a1():
    img, draw = new_canvas(GREEN_DARK)
    cx, cy = SIZE // 2, SIZE // 2

    # M letter - bold rounded, centered in ~60% of canvas
    m_w = 520  # total width of M
    m_h = 480  # height
    stroke = 110  # stroke width
    left = cx - m_w // 2
    top = cy - m_h // 2 + 40  # shift down slightly for eyes

    # Two outer legs + two inner diagonal legs of M
    # Left vertical leg
    draw.rounded_rectangle(
        [left, top, left + stroke, top + m_h],
        radius=stroke // 2, fill=WHITE
    )
    # Right vertical leg
    draw.rounded_rectangle(
        [left + m_w - stroke, top, left + m_w, top + m_h],
        radius=stroke // 2, fill=WHITE
    )
    # Left diagonal (from top-left down to center valley)
    # Draw as a rotated rectangle approximation using polygon
    valley_x = cx
    valley_y = top + m_h * 0.7
    peak_y = top

    # Left diagonal
    pts_left = [
        (left + stroke * 0.2, peak_y),
        (left + stroke * 1.2, peak_y),
        (valley_x + stroke * 0.6, valley_y),
        (valley_x - stroke * 0.6, valley_y),
    ]
    draw.polygon(pts_left, fill=WHITE)

    # Right diagonal
    pts_right = [
        (left + m_w - stroke * 1.2, peak_y),
        (left + m_w - stroke * 0.2, peak_y),
        (valley_x + stroke * 0.6, valley_y),
        (valley_x - stroke * 0.6, valley_y),
    ]
    draw.polygon(pts_right, fill=WHITE)

    # Cap the valley with rounded bottom
    draw.rounded_rectangle(
        [valley_x - stroke * 0.8, valley_y - stroke // 2,
         valley_x + stroke * 0.8, valley_y + stroke // 2],
        radius=stroke // 2, fill=WHITE
    )

    # Eyes on top of M peaks
    eye_r = 38
    eye_y = top - 20
    # Left eye
    left_peak_x = left + stroke // 2 + 30
    draw.ellipse([left_peak_x - eye_r, eye_y - eye_r,
                  left_peak_x + eye_r, eye_y + eye_r], fill=WHITE)
    draw.ellipse([left_peak_x - 14 + 4, eye_y - 14,
                  left_peak_x + 14 + 4, eye_y + 14], fill=GREEN_PUPIL)

    # Right eye
    right_peak_x = left + m_w - stroke // 2 - 30
    draw.ellipse([right_peak_x - eye_r, eye_y - eye_r,
                  right_peak_x + eye_r, eye_y + eye_r], fill=WHITE)
    draw.ellipse([right_peak_x - 14 - 4, eye_y - 14,
                  right_peak_x + 14 - 4, eye_y + 14], fill=GREEN_PUPIL)

    save(img, "A1_M_eyes_dark.png")

    # Variant on accent green
    img2, draw2 = new_canvas(GREEN_ACCENT)
    # Re-paste the M and eyes onto accent background
    # (Just regenerate - same code different bg)
    draw_m_and_eyes(draw2, GREEN_ACCENT)
    save(img2, "A1_M_eyes_accent.png")

def draw_m_and_eyes(draw, bg_color):
    cx, cy = SIZE // 2, SIZE // 2
    m_w, m_h, stroke = 520, 480, 110
    left = cx - m_w // 2
    top = cy - m_h // 2 + 40

    draw.rounded_rectangle([left, top, left + stroke, top + m_h], radius=stroke//2, fill=WHITE)
    draw.rounded_rectangle([left + m_w - stroke, top, left + m_w, top + m_h], radius=stroke//2, fill=WHITE)

    valley_x, valley_y = cx, top + int(m_h * 0.7)
    pts_l = [(left + int(stroke*0.2), top), (left + int(stroke*1.2), top),
             (valley_x + int(stroke*0.6), valley_y), (valley_x - int(stroke*0.6), valley_y)]
    draw.polygon(pts_l, fill=WHITE)
    pts_r = [(left + m_w - int(stroke*1.2), top), (left + m_w - int(stroke*0.2), top),
             (valley_x + int(stroke*0.6), valley_y), (valley_x - int(stroke*0.6), valley_y)]
    draw.polygon(pts_r, fill=WHITE)
    draw.rounded_rectangle([valley_x - int(stroke*0.8), valley_y - stroke//2,
                            valley_x + int(stroke*0.8), valley_y + stroke//2], radius=stroke//2, fill=WHITE)

    eye_r, eye_y = 38, top - 20
    lx = left + stroke // 2 + 30
    rx = left + m_w - stroke // 2 - 30
    draw.ellipse([lx - eye_r, eye_y - eye_r, lx + eye_r, eye_y + eye_r], fill=WHITE)
    draw.ellipse([lx - 10, eye_y - 14, lx + 18, eye_y + 14], fill=(0, 55, 35))
    draw.ellipse([rx - eye_r, eye_y - eye_r, rx + eye_r, eye_y + eye_r], fill=WHITE)
    draw.ellipse([rx - 18, eye_y - 14, rx + 10, eye_y + 14], fill=(0, 55, 35))


# ============================================================
# A2: Monster M with Fang (獠牙向)
# ============================================================
def draw_a2():
    img, draw = new_canvas(GREEN_DARK)
    cx, cy = SIZE // 2, SIZE // 2
    m_w, m_h, stroke = 520, 480, 110
    left = cx - m_w // 2
    top = cy - m_h // 2 + 40

    # M body
    draw.rounded_rectangle([left, top, left + stroke, top + m_h], radius=stroke//2, fill=WHITE)
    draw.rounded_rectangle([left + m_w - stroke, top, left + m_w, top + m_h], radius=stroke//2, fill=WHITE)
    valley_x, valley_y = cx, top + int(m_h * 0.7)
    pts_l = [(left + int(stroke*0.2), top), (left + int(stroke*1.2), top),
             (valley_x + int(stroke*0.6), valley_y), (valley_x - int(stroke*0.6), valley_y)]
    draw.polygon(pts_l, fill=WHITE)
    pts_r = [(left + m_w - int(stroke*1.2), top), (left + m_w - int(stroke*0.2), top),
             (valley_x + int(stroke*0.6), valley_y), (valley_x - int(stroke*0.6), valley_y)]
    draw.polygon(pts_r, fill=WHITE)
    draw.rounded_rectangle([valley_x - int(stroke*0.8), valley_y - stroke//2,
                            valley_x + int(stroke*0.8), valley_y + stroke//2], radius=stroke//2, fill=WHITE)

    # Fang hanging from V valley bottom
    fang_top = valley_y + stroke // 2
    fang_h = 60
    fang_w = 36
    fang_pts = [
        (valley_x - fang_w, fang_top),
        (valley_x + fang_w, fang_top),
        (valley_x, fang_top + fang_h),
    ]
    draw.polygon(fang_pts, fill=WHITE)

    save(img, "A2_M_fang_dark.png")

    img2, _ = new_canvas(GREEN_ACCENT)
    draw2 = ImageDraw.Draw(img2)
    draw_m_and_fang(draw2)
    save(img2, "A2_M_fang_accent.png")

def draw_m_and_fang(draw):
    cx, cy = SIZE // 2, SIZE // 2
    m_w, m_h, stroke = 520, 480, 110
    left = cx - m_w // 2
    top = cy - m_h // 2 + 40

    draw.rounded_rectangle([left, top, left + stroke, top + m_h], radius=stroke//2, fill=WHITE)
    draw.rounded_rectangle([left + m_w - stroke, top, left + m_w, top + m_h], radius=stroke//2, fill=WHITE)
    valley_x, valley_y = cx, top + int(m_h * 0.7)
    pts_l = [(left + int(stroke*0.2), top), (left + int(stroke*1.2), top),
             (valley_x + int(stroke*0.6), valley_y), (valley_x - int(stroke*0.6), valley_y)]
    draw.polygon(pts_l, fill=WHITE)
    pts_r = [(left + m_w - int(stroke*1.2), top), (left + m_w - int(stroke*0.2), top),
             (valley_x + int(stroke*0.6), valley_y), (valley_x - int(stroke*0.6), valley_y)]
    draw.polygon(pts_r, fill=WHITE)
    draw.rounded_rectangle([valley_x - int(stroke*0.8), valley_y - stroke//2,
                            valley_x + int(stroke*0.8), valley_y + stroke//2], radius=stroke//2, fill=WHITE)

    fang_top = valley_y + stroke // 2
    fang_pts = [(valley_x - 36, fang_top), (valley_x + 36, fang_top), (valley_x, fang_top + 60)]
    draw.polygon(fang_pts, fill=WHITE)


# ============================================================
# B1: Coffee Cup with "Aa" on card
# ============================================================
def draw_b1():
    img, draw = new_canvas(GREEN_DARK)
    cx, cy = SIZE // 2, SIZE // 2

    # Cup body - slightly tilted trapezoid
    cup_w_top = 280
    cup_w_bot = 240
    cup_h = 340
    tilt = 12  # slight tilt
    cup_top = cy - cup_h // 2 + 50
    cup_bot = cup_top + cup_h

    cup_pts = [
        (cx - cup_w_top // 2 + tilt, cup_top),
        (cx + cup_w_top // 2 + tilt, cup_top),
        (cx + cup_w_bot // 2, cup_bot),
        (cx - cup_w_bot // 2, cup_bot),
    ]
    draw.polygon(cup_pts, fill=WHITE)

    # Cup lid - horizontal bar
    lid_h = 40
    lid_w = cup_w_top + 40
    draw.rounded_rectangle(
        [cx - lid_w // 2 + tilt, cup_top - lid_h,
         cx + lid_w // 2 + tilt, cup_top + 8],
        radius=12, fill=WHITE
    )

    # "Aa" text on cup body in green
    try:
        font_large = ImageFont.truetype("arial.ttf", 120)
    except:
        font_large = ImageFont.load_default()
    text = "Aa"
    bbox = draw.textbbox((0, 0), text, font=font_large)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((cx - tw // 2 + 6, cy - th // 2 + 40), text, fill=GREEN_DARK, font=font_large)

    # Steam - one thick S-curve
    steam_x = cx + tilt
    steam_y = cup_top - lid_h - 20
    # Draw as connected thick rounded line segments
    for i in range(8):
        y1 = steam_y - i * 28
        y2 = y1 - 28
        x_off = 30 if i % 2 == 0 else -30
        draw.line([(steam_x, y1), (steam_x + x_off, y2)],
                  fill=WHITE, width=18)
    # Round steam endpoints
    for i in range(8):
        y = steam_y - i * 28 - 28
        x_off = 30 if i % 2 == 0 else -30
        r = 9
        draw.ellipse([steam_x + x_off - r, y - r, steam_x + x_off + r, y + r], fill=WHITE)

    save(img, "B1_cup_Aa_dark.png")

    img2, _ = new_canvas(GREEN_ACCENT)
    draw_cup_card(ImageDraw.Draw(img2), GREEN_ACCENT)
    save(img2, "B1_cup_Aa_accent.png")

def draw_cup_card(draw, bg_color):
    cx, cy = SIZE // 2, SIZE // 2
    cup_w_top, cup_w_bot, cup_h = 280, 240, 340
    tilt = 12
    cup_top = cy - cup_h // 2 + 50
    cup_bot = cup_top + cup_h

    cup_pts = [(cx - cup_w_top//2 + tilt, cup_top), (cx + cup_w_top//2 + tilt, cup_top),
               (cx + cup_w_bot//2, cup_bot), (cx - cup_w_bot//2, cup_bot)]
    draw.polygon(cup_pts, fill=WHITE)

    lid_h, lid_w = 40, cup_w_top + 40
    draw.rounded_rectangle([cx - lid_w//2 + tilt, cup_top - lid_h, cx + lid_w//2 + tilt, cup_top + 8],
                           radius=12, fill=WHITE)

    try:
        font_large = ImageFont.truetype("arial.ttf", 120)
    except:
        font_large = ImageFont.load_default()
    text = "Aa"
    bbox = draw.textbbox((0, 0), text, font=font_large)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((cx - tw//2 + 6, cy - th//2 + 40), text, fill=bg_color, font=font_large)

    steam_x = cx + tilt
    steam_y = cup_top - lid_h - 20
    for i in range(8):
        y1 = steam_y - i * 28
        y2 = y1 - 28
        x_off = 30 if i % 2 == 0 else -30
        draw.line([(steam_x, y1), (steam_x + x_off, y2)], fill=WHITE, width=18)
    for i in range(8):
        y = steam_y - i * 28 - 28
        x_off = 30 if i % 2 == 0 else -30
        r = 9
        draw.ellipse([steam_x + x_off - r, y - r, steam_x + x_off + r, y + r], fill=WHITE)


# ============================================================
# B2: Coffee Cup with dashed lines (minimal variant)
# ============================================================
def draw_b2():
    img, draw = new_canvas(GREEN_DARK)
    cx, cy = SIZE // 2, SIZE // 2

    cup_w_top, cup_w_bot, cup_h = 280, 240, 340
    tilt = 12
    cup_top = cy - cup_h // 2 + 50
    cup_bot = cup_top + cup_h

    cup_pts = [(cx - cup_w_top//2 + tilt, cup_top), (cx + cup_w_top//2 + tilt, cup_top),
               (cx + cup_w_bot//2, cup_bot), (cx - cup_w_bot//2, cup_bot)]
    draw.polygon(cup_pts, fill=WHITE)

    lid_h, lid_w = 40, cup_w_top + 40
    draw.rounded_rectangle([cx - lid_w//2 + tilt, cup_top - lid_h, cx + lid_w//2 + tilt, cup_top + 8],
                           radius=12, fill=WHITE)

    # Two dashed horizontal lines instead of "Aa"
    line_y1 = cy + 20
    line_y2 = cy + 80
    dash_w = 30
    gap = 20
    for y in [line_y1, line_y2]:
        x_start = cx - 80
        x_end = cx + 80
        x = x_start
        while x < x_end:
            draw.rounded_rectangle([x, y - 8, x + dash_w, y + 8], radius=8, fill=GREEN_DARK)
            x += dash_w + gap

    # Steam
    steam_x = cx + tilt
    steam_y = cup_top - lid_h - 20
    for i in range(8):
        y1 = steam_y - i * 28
        y2 = y1 - 28
        x_off = 30 if i % 2 == 0 else -30
        draw.line([(steam_x, y1), (steam_x + x_off, y2)], fill=WHITE, width=18)
    for i in range(8):
        y = steam_y - i * 28 - 28
        x_off = 30 if i % 2 == 0 else -30
        draw.ellipse([steam_x + x_off - 9, y - 9, steam_x + x_off + 9, y + 9], fill=WHITE)

    save(img, "B2_cup_lines_dark.png")

    img2, _ = new_canvas(GREEN_ACCENT)
    draw_cup_lines(ImageDraw.Draw(img2), GREEN_ACCENT)
    save(img2, "B2_cup_lines_accent.png")

def draw_cup_lines(draw, bg_color):
    cx, cy = SIZE // 2, SIZE // 2
    cup_w_top, cup_w_bot, cup_h = 280, 240, 340
    tilt = 12
    cup_top = cy - cup_h // 2 + 50
    cup_bot = cup_top + cup_h

    cup_pts = [(cx - cup_w_top//2 + tilt, cup_top), (cx + cup_w_top//2 + tilt, cup_top),
               (cx + cup_w_bot//2, cup_bot), (cx - cup_w_bot//2, cup_bot)]
    draw.polygon(cup_pts, fill=WHITE)

    lid_h, lid_w = 40, cup_w_top + 40
    draw.rounded_rectangle([cx - lid_w//2 + tilt, cup_top - lid_h, cx + lid_w//2 + tilt, cup_top + 8],
                           radius=12, fill=WHITE)

    for y_off in [20, 80]:
        y = cy + y_off
        x = cx - 80
        while x < cx + 80:
            draw.rounded_rectangle([x, y - 8, x + 30, y + 8], radius=8, fill=bg_color)
            x += 50

    steam_x = cx + tilt
    steam_y = cup_top - lid_h - 20
    for i in range(8):
        y1 = steam_y - i * 28
        y2 = y1 - 28
        x_off = 30 if i % 2 == 0 else -30
        draw.line([(steam_x, y1), (steam_x + x_off, y2)], fill=WHITE, width=18)
    for i in range(8):
        y = steam_y - i * 28 - 28
        x_off = 30 if i % 2 == 0 else -30
        draw.ellipse([steam_x + x_off - 9, y - 9, steam_x + x_off + 9, y + 9], fill=WHITE)


# ============================================================
# Main
# ============================================================
if __name__ == "__main__":
    print("Generating Monster Word launcher icon candidates...")
    draw_a1()
    draw_a2()
    draw_b1()
    draw_b2()
    print("Done! 8 files generated.")
