#!/usr/bin/env python3
"""
Generate Monster Word launcher icon - Plan A1 (M + Eyes)
Flat vector style: bold rounded M with two cute eyes on Starbucks Green background.

Outputs:
  - assets/branding/icon_master_1024.png (1024x1024, green bg + white M + eyes)
  - assets/branding/icon_foreground_1024.png (1024x1024, transparent bg, white M + eyes, centered 66%)
"""

from PIL import Image, ImageDraw
import math
import os

# === Configuration ===
SIZE = 1024
BG_COLOR = (0, 98, 65)      # #006241 Starbucks Green
FG_COLOR = (255, 255, 255)   # #FFFFFF Pure White
PUPIL_COLOR = (0, 98, 65)    # Same as background for pupils

# Safe area: center 600px (58%) for the main subject
SAFE_MARGIN = 212  # (1024 - 600) / 2

# === Draw M shape ===
def draw_rounded_M(draw, cx, cy, width, height, stroke_width, color):
    """Draw a bold rounded uppercase M using thick strokes with round caps."""
    half_w = width / 2
    half_h = height / 2
    
    # M vertices (relative to center):
    # Bottom-left, Top-left, Middle-V, Top-right, Bottom-right
    bl = (cx - half_w, cy + half_h)
    tl = (cx - half_w, cy - half_h)
    mv = (cx, cy + half_h * 0.15)  # V valley point (slightly below center)
    tr = (cx + half_w, cy - half_h)
    br = (cx + half_w, cy + half_h)
    
    # Draw as thick lines with round joints/caps
    segments = [
        (bl, tl),    # Left vertical
        (tl, mv),    # Left diagonal down to V
        (mv, tr),    # Right diagonal up from V
        (tr, br),    # Right vertical
    ]
    
    for start, end in segments:
        draw.line([start, end], fill=color, width=stroke_width, joint="curve")
    
    # Add round caps at the bottoms
    r = stroke_width // 2
    for point in [bl, br]:
        draw.ellipse(
            [point[0] - r, point[1] - r, point[0] + r, point[1] + r],
            fill=color
        )
    
    # Round cap at top points
    for point in [tl, tr]:
        draw.ellipse(
            [point[0] - r, point[1] - r, point[0] + r, point[1] + r],
            fill=color
        )
    
    # Round cap at V valley
    draw.ellipse(
        [mv[0] - r, mv[1] - r, mv[0] + r, mv[1] + r],
        fill=color
    )
    
    return tl, tr, mv


def draw_eyes(draw, tl, tr, m_height, fg_color, pupil_color):
    """Draw two cute round eyes sitting on top of the M peaks."""
    eye_radius = int(m_height * 0.13)
    pupil_radius = int(eye_radius * 0.45)
    
    # Eyes sit on top of the M peaks
    eye_y = tl[1] - eye_radius * 0.3
    
    # Left eye - slightly inward from left peak
    left_eye_x = tl[0] + eye_radius * 0.5
    # Right eye - slightly inward from right peak
    right_eye_x = tr[0] - eye_radius * 0.5
    
    for eye_x in [left_eye_x, right_eye_x]:
        # White of eye
        draw.ellipse(
            [eye_x - eye_radius, eye_y - eye_radius,
             eye_x + eye_radius, eye_y + eye_radius],
            fill=fg_color
        )
        # Pupil - slightly inward (cross-eyed look)
        if eye_x == left_eye_x:
            px = eye_x + pupil_radius * 0.4
        else:
            px = eye_x - pupil_radius * 0.4
        py = eye_y + pupil_radius * 0.2  # Slightly looking down
        
        draw.ellipse(
            [px - pupil_radius, py - pupil_radius,
             px + pupil_radius, py + pupil_radius],
            fill=pupil_color
        )


def generate_master():
    """Generate 1024x1024 master icon with green background."""
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)
    
    # M dimensions within safe area
    m_width = 440   # Width of M
    m_height = 420  # Height of M
    m_cx = SIZE // 2
    m_cy = SIZE // 2 + 30  # Slightly below center to make room for eyes
    stroke_w = 90   # Thick bold strokes
    
    tl, tr, mv = draw_rounded_M(draw, m_cx, m_cy, m_width, m_height, stroke_w, FG_COLOR)
    draw_eyes(draw, tl, tr, m_height, FG_COLOR, PUPIL_COLOR)
    
    return img


def generate_foreground(master):
    """Generate foreground layer with transparent background, subject centered in 66%."""
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    
    # The master already has the subject centered. For Android adaptive icon,
    # the subject needs to be within the center 66% (676px).
    # Our subject is already well within that, so we can use the same content.
    # Just replace the green background with transparency.
    
    pixels = master.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = pixels[x, y]
            if (r, g, b) == BG_COLOR:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    
    return master


def main():
    # Create output directory
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")
    os.makedirs(out_dir, exist_ok=True)
    
    # Generate master
    print("Generating master icon (1024x1024)...")
    master = generate_master()
    master_path = os.path.join(out_dir, "icon_master_1024.png")
    master.save(master_path, "PNG")
    print(f"  Saved: {master_path}")
    
    # Generate foreground (copy master, make bg transparent)
    print("Generating foreground layer (transparent bg)...")
    # Need a fresh copy since generate_foreground modifies in-place
    master_copy = master.copy()
    foreground = generate_foreground(master_copy)
    fg_path = os.path.join(out_dir, "icon_foreground_1024.png")
    foreground.save(fg_path, "PNG")
    print(f"  Saved: {fg_path}")
    
    # Quick verification
    for path in [master_path, fg_path]:
        img = Image.open(path)
        print(f"  {os.path.basename(path)}: {img.size[0]}x{img.size[1]}, mode={img.mode}")
    
    print("\nDone! Next step: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
