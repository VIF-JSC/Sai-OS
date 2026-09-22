#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Apply the official brand assets (brand/tmp/) to every asset in the repo.

Source files (not committed; supplied by the designer):
  - logo tách nền.png : S mark + star, transparent background
  - A1/A2.png         : logo + name on light / dark background
  - A3.png            : monochrome version (transparent background)
  - A21.png           : wide hero on dark background (splash)
  - Wallpaper*.png    : 2 dark + 2 light

Requires ImageMagick (magick) and rsvg-convert. Run from the repo root:
    python3 brand/apply.py
"""
import base64, glob, math, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "brand", "tmp")
TMP = tempfile.mkdtemp(prefix="sai-brand-")
os.chdir(ROOT)

# Official palette
PRIMARY, PRIMARY_DARK = "#2D8CFF", "#0F4FD6"
NAVY, ACCENT = "#0A1226", "#00D4FF"
SYM = "#bebebe"

MARK = f"{SRC}/logo tách nền.png"
A1, A2, A3, A21 = (f"{SRC}/A1.png", f"{SRC}/A2.png", f"{SRC}/A3.png", f"{SRC}/A21.png")
W_DARK = f"{SRC}/Wallpaper tối 3840x2160.png"
W_DARK2 = f"{SRC}/Wallpaper3840x2160_bản tối.png"
W_LIGHT = f"{SRC}/Wallpaper3840x2160 bản sáng.png"
W_LIGHT2 = f"{SRC}/Wallpaper3840x2160 bản sáng biến thể 1.png"

for f in (MARK, A1, A2, A3, A21, W_DARK, W_DARK2, W_LIGHT, W_LIGHT2):
    if not os.path.isfile(f):
        sys.exit(f"Missing source file: {f}")
for tool in ("magick", "rsvg-convert"):
    if not shutil.which(tool):
        sys.exit(f"{tool} is required (brew install imagemagick librsvg)")

def run(*args):
    subprocess.run(list(args), capture_output=True, check=True)

def magick(*args):
    run("magick", *args)

_n = [0]
def render_svg(svg_text, out, width):
    _n[0] += 1
    src = os.path.join(TMP, f"b{_n[0]}.svg")
    open(src, "w").write(svg_text)
    run("rsvg-convert", "-w", str(width), "--keep-aspect-ratio", "-o", src + ".png", src)
    shutil.move(src + ".png", out)
    _n[0] += 1

def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()

# ---------------------------------------------------------------- intermediates
# Square transparent mark (base icon)
MARK_SQ = f"{TMP}/mark_sq.png"
magick(MARK, "-trim", "+repage", "-resize", "1024x1024",
       "-background", "none", "-gravity", "center", "-extent", "1024x1024", MARK_SQ)

# System icon tile: rounded dark square + mark (like A2 but without text, so
# 16-48 px icons stay legible)
TILE = f"{TMP}/tile.png"
TILE_SVG = (
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
    f'<defs><radialGradient id="g" cx="0.5" cy="0.38" r="0.85">'
    f'<stop offset="0" stop-color="#16418F"/><stop offset="1" stop-color="{NAVY}"/></radialGradient></defs>'
    f'<rect width="1024" height="1024" rx="192" fill="url(#g)"/>'
    f'<image x="152" y="152" width="720" height="720" '
    f'href="data:image/png;base64,{b64(MARK_SQ)}"/></svg>')
render_svg(TILE_SVG, TILE, 1024)

# Monochrome version: take the mark from A3 (drop the SAI OS text below), tint #bebebe
SYM_SQ = f"{TMP}/sym_sq.png"
magick(A3, "-trim", "+repage", "-gravity", "North", "-crop", "100%x78%+0+0", "+repage",
       "-trim", "+repage", "-channel", "RGB", "-fill", SYM, "-colorize", "100", "+channel",
       "-resize", "1024x1024", "-background", "none", "-gravity", "center",
       "-extent", "1024x1024", SYM_SQ)

# Logo + name: A1 (light) / A2 (dark) fitted to a 512 frame
L_LIGHT, L_DARK = f"{TMP}/l_light.png", f"{TMP}/l_dark.png"
magick(A1, "-resize", "512x512", "-background", "white", "-gravity", "center",
       "-extent", "512x512", L_LIGHT)
magick(A2, "-resize", "512x512", L_DARK)

def svg_wrap(png, size=512):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" '
            f'width="{size}" height="{size}">'
            f'<image width="{size}" height="{size}" '
            f'href="data:image/png;base64,{b64(png)}"/></svg>')

TILE_512, SYM_512 = f"{TMP}/tile512.png", f"{TMP}/sym512.png"
magick(TILE, "-resize", "512x512", TILE_512)
magick(SYM_SQ, "-resize", "512x512", SYM_512)
SVG_LOGO = svg_wrap(TILE_512)
SVG_SYMBOLIC = svg_wrap(SYM_512)
SVG_LOGO_LIGHT = svg_wrap(L_LIGHT)
SVG_LOGO_DARK = svg_wrap(L_DARK)

# ------------------------------------------------------------------- icon SVG
for p in glob.glob("**/*.svg", recursive=True):
    b = os.path.basename(p)
    if b in ("sai-logo.svg", "start-here.svg"):
        open(p, "w").write(SVG_LOGO)
    elif b == "Sai_logo.svg":
        open(p, "w").write(SVG_LOGO_LIGHT)
    elif b == "Sai_logo_dark.svg":
        open(p, "w").write(SVG_LOGO_DARK)
    elif b == "Sai_only_icon.svg":
        open(p, "w").write(svg_wrap(MARK_SQ, 1024).replace('viewBox="0 0 1024 1024" width="1024" height="1024"',
                                                           'viewBox="0 0 1024 1024" width="512" height="512"'))
    elif b in ("sai-logo-symbolic.svg", "linuxmint-logo-ring-symbolic.svg"):
        open(p, "w").write(SVG_SYMBOLIC)

# ------------------------------------------------------------------- icon PNG
def size_hint(path, default=512):
    import re
    m = re.search(r"/(\d+)x\1/", path)
    return int(m.group(1)) if m else default

for p in glob.glob("**/*.png", recursive=True):
    if p.startswith("brand/tmp/"):
        continue
    b = os.path.basename(p)
    s = str(size_hint(p))
    if b in ("sai-logo.png", "sai.png", "start-here.png", "mintubiquity.png"):
        magick(TILE, "-resize", f"{s}x{s}", p)
    elif b == "sai-logo-full.png":
        magick(L_LIGHT, "-resize", f"{s}x{s}", p)
    elif b == "Sai_logo.png":
        shutil.copy(L_LIGHT, p)
    elif b == "Sai_logo_dark.png":
        shutil.copy(L_DARK, p)
    elif b == "Sai_only_icon.png":
        magick(MARK_SQ, "-resize", "512x512", p)
    elif b in ("sai-logo-symbolic.png", "linuxmint-logo-ring-symbolic.png"):
        magick(SYM_SQ, "-resize", f"{s}x{s}", p)
print("icons OK")

# JPG copies for the brand folder
run("magick", L_LIGHT, "-background", "white", "-flatten", "brand/Logo + Name/Sai_logo.jpg")
run("magick", L_DARK, "brand/Logo + Name/Sai_logo_dark.jpg")

# Horizontal lockup 770x160: mark + "SAI OS" text (rendered via rsvg because
# this ImageMagick build has no font delegate)
text_png = f"{TMP}/lockup_text.png"
render_svg(
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 700 160" width="700" height="160">'
    f'<text x="0" y="120" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" '
    f'font-size="120" font-weight="bold" letter-spacing="6" fill="{PRIMARY_DARK}">SAI OS</text></svg>',
    text_png, 700)
magick(text_png, "-trim", "+repage", "-resize", "x84",
       "-bordercolor", "none", "-border", "28x0", "+repage", text_png)
mark_140 = f"{TMP}/mark140.png"
magick(MARK_SQ, "-trim", "+repage", "-resize", "x140", mark_140)
magick(mark_140, text_png, "-background", "none", "-gravity", "center",
       "+append", "+repage", "-gravity", "center", "-extent", "770x160",
       "os/rootfs/usr/share/pixmaps/sai-lockup.png")
print("lockup OK")

# ------------------------------------------------------------------ boot/splash
BG = "os/rootfs/usr/share/backgrounds/sai"
# GRUB/isolinux: A2 as a 640 square, hero A21 cropped to 4:3
magick(A2, "-resize", "640x640", "brand/boot-splash.png")
for out in ("brand/splash.png", f"{BG}/splash.png"):
    magick(A21, "-resize", "640x480^", "-gravity", "center", "-extent", "640x480", out)

# Plymouth: watermark = transparent mark at 240
for out in (f"{BG}/watermark.png", f"{BG}/plymouth-logo.png"):
    magick(MARK_SQ, "-resize", "200x200", "-background", "none",
           "-gravity", "center", "-extent", "240x240", out)

# Boot spinner: brand-blue ring + rotating accent arc
def svg_spinner(angle):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 240" width="240" height="240">'
            f'<g transform="rotate({angle} 120 120)">'
            f'<circle cx="120" cy="120" r="80" fill="none" stroke="{PRIMARY}" stroke-opacity="0.25" stroke-width="14"/>'
            f'<path d="M 120 40 A 80 80 0 0 1 200 120" fill="none" stroke="{ACCENT}" stroke-width="14" stroke-linecap="round"/>'
            f'</g></svg>')

for i in range(1, 37):
    render_svg(svg_spinner((i - 1) * 10), f"{BG}/animation-{i:04d}.png", 240)
for i in range(1, 31):
    render_svg(svg_spinner((i - 1) * 12), f"{BG}/throbber-{i:04d}.png", 240)
print("plymouth OK")

# ------------------------------------------------------------------ wallpaper
def wall(src, out, w, h):
    magick(src, "-filter", "Lanczos", "-resize", f"{w}x{h}^",
           "-gravity", "center", "-extent", f"{w}x{h}", out)

wall(W_DARK,   "brand/Wallpaper 4K/sai_202020.png", 3840, 2160)
wall(W_DARK2,  "brand/Wallpaper 4K/sai_303030.png", 3840, 2160)
wall(W_LIGHT,  "brand/Wallpaper 4K/sai_e0e0e0.png", 3840, 2160)
wall(W_LIGHT2, "brand/Wallpaper 4K/sai_f0f0f0.png", 3840, 2160)
wall(W_DARK,  f"{BG}/sai-dark.png", 3840, 2160)
wall(W_LIGHT, f"{BG}/sai-light.png", 3840, 2160)
wall(W_DARK,  f"{BG}/default.png", 2000, 1121)      # desktop + login screen
wall(W_DARK,  f"{BG}/sai-wallpaper.png", 2000, 1121)
wall(W_DARK2, f"{BG}/wallpaper2.png", 1672, 941)
for j in (f"{BG}/default.jpg", f"{BG}/wallpaper.jpg", "brand/wallpaper.jpg"):
    if os.path.exists(j):
        wall(W_DARK, j, 2000, 1121)
print("walls OK")

# ---------------------------------------------------------------- ascii logo
ASCII = r"""
   _____ ___    ____   ____  _____
  / ___//   |  /  _/  / __ \/ ___/
  \__ \/ /| |  / /  / / / / \__ \
 ___/ / ___ |_/ /  / /_/ / ___/ /
/____/_/  |_/___/   \____//____/
                *
""".lstrip("\n")
open("os/rootfs/usr/share/sai/ascii-logo.txt", "w").write(ASCII)
B, C, R = "\033[1;34m", "\033[1;36m", "\033[0m"  # brand blue + cyan for the star
lines = ASCII.rstrip("\n").split("\n")
ansi = "\n".join(f"{C}{l}{R}" if "*" in l else f"{B}{l}{R}" for l in lines) + "\n"
open("os/rootfs/usr/share/sai/ascii-logo-color.ansi", "w").write(ansi)

shutil.rmtree(TMP, ignore_errors=True)
print("Brand assets applied.")
