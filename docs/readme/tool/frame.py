"""Draws an iPhone body around simulator screenshots and recordings.

The simulator's framebuffer has no hardware in it, so the body is drawn
here: a titanium band, a black bezel, the Dynamic Island and the side
buttons, sized for a 1320 x 2868 (iPhone Pro Max, 3x) screen.

    python3 frame.py still <screenshot.png> <out.png> [width]
    python3 frame.py gif <recording.mov> <out.gif> [--start S] [--end S]
        [--width W] [--fps F]

    python3 frame.py detail <recording.mov> <out.gif> --crop X Y W H
        [--start S] [--end S] [--width W] [--fps F]

`gif` composites a simulator recording under the body, on a backdrop
that reads in both light and dark themes, through ffmpeg. `detail`
crops a region of the screen instead, in screen pixels, and sets it on
the same backdrop as a rounded card: a close-up with no body.
"""

import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SCREEN_W, SCREEN_H = 1320, 2868
SCREEN_RADIUS = 168
BEZEL = 42
BAND = 22
PAD = 90  # room for the buttons and the shadow
S = 2  # supersampling for smooth curves

OUT_W = SCREEN_W + 2 * (BEZEL + BAND) + 2 * PAD
OUT_H = SCREEN_H + 2 * (BEZEL + BAND) + 2 * PAD
SCREEN_X = PAD + BAND + BEZEL
SCREEN_Y = PAD + BAND + BEZEL


def _rrect(draw, box, radius, fill):
    draw.rounded_rectangle([v * S for v in box], radius * S, fill=fill)


def _body():
    img = Image.new("RGBA", (OUT_W * S, OUT_H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0 = PAD, PAD
    x1, y1 = OUT_W - PAD, OUT_H - PAD
    outer_r = SCREEN_RADIUS + BEZEL + BAND

    # Side buttons, drawn first so the band overlaps their roots.
    button = (58, 60, 66, 255)
    left = x0 - 7
    _rrect(d, (left, y0 + 330, x0 + 6, y0 + 450), 5, button)   # action
    _rrect(d, (left, y0 + 560, x0 + 6, y0 + 760), 5, button)   # volume up
    _rrect(d, (left, y0 + 800, x0 + 6, y0 + 1000), 5, button)  # volume down
    _rrect(d, (x1 - 6, y0 + 640, x1 + 7, y0 + 960), 5, button)  # side
    _rrect(d, (x1 - 6, y0 + 1480, x1 + 7, y0 + 1700), 5, button)  # capture

    # Titanium band: a dark edge, the metal, and a thin highlight inside.
    _rrect(d, (x0, y0, x1, y1), outer_r, (44, 45, 50, 255))
    _rrect(d, (x0 + 3, y0 + 3, x1 - 3, y1 - 3), outer_r - 3, (122, 124, 130, 255))
    _rrect(d, (x0 + 8, y0 + 8, x1 - 8, y1 - 8), outer_r - 8, (86, 88, 94, 255))
    _rrect(
        d, (x0 + BAND - 3, y0 + BAND - 3, x1 - BAND + 3, y1 - BAND + 3),
        outer_r - BAND + 3, (160, 162, 168, 255),
    )
    # Bezel.
    _rrect(
        d, (x0 + BAND, y0 + BAND, x1 - BAND, y1 - BAND),
        SCREEN_RADIUS + BEZEL, (6, 6, 8, 255),
    )
    return img


def _screen_mask(scale=S):
    mask = Image.new("L", (OUT_W * scale, OUT_H * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [
            SCREEN_X * scale, SCREEN_Y * scale,
            (SCREEN_X + SCREEN_W) * scale, (SCREEN_Y + SCREEN_H) * scale,
        ],
        SCREEN_RADIUS * scale,
        fill=255,
    )
    return mask


def _island():
    img = Image.new("RGBA", (OUT_W * S, OUT_H * S), (0, 0, 0, 0))
    w, h, top = 378, 111, 33
    cx = SCREEN_X + SCREEN_W / 2
    _rrect(
        ImageDraw.Draw(img),
        (cx - w / 2, SCREEN_Y + top, cx + w / 2, SCREEN_Y + top + h),
        h / 2, (0, 0, 0, 255),
    )
    return img


def _shadow():
    shadow = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))
    r = SCREEN_RADIUS + BEZEL + BAND
    ImageDraw.Draw(shadow).rounded_rectangle(
        [PAD + 10, PAD + 40, OUT_W - PAD - 10, OUT_H - PAD + 20],
        r, fill=(0, 0, 0, 110),
    )
    return shadow.filter(ImageFilter.GaussianBlur(36))


def overlay():
    """The body with the screen cut out, the island on top, full size."""
    body = _body()
    cut = ImageChops.subtract(body.getchannel("A"), _screen_mask())
    body.putalpha(cut)
    body = Image.alpha_composite(body, _island())
    return body.resize((OUT_W, OUT_H), Image.LANCZOS)


def still(screenshot_path, out_path, width=None):
    shot = Image.open(screenshot_path).convert("RGBA")
    if shot.size != (SCREEN_W, SCREEN_H):
        shot = shot.resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
    canvas = _shadow()
    screen = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))
    screen.paste(shot, (SCREEN_X, SCREEN_Y))
    screen.putalpha(_screen_mask(1))
    canvas = Image.alpha_composite(canvas, screen)
    canvas = Image.alpha_composite(canvas, overlay())
    if width:
        canvas = canvas.resize(
            (int(width), round(OUT_H * int(width) / OUT_W)), Image.LANCZOS
        )
    canvas.save(out_path, optimize=True)


def backdrop():
    """A deep night gradient with the phone's shadow on it."""
    top, bottom = (22, 18, 40), (8, 10, 18)
    bg = Image.new("RGBA", (OUT_W, OUT_H))
    px = ImageDraw.Draw(bg)
    for y in range(OUT_H):
        f = y / (OUT_H - 1)
        px.line(
            [(0, y), (OUT_W, y)],
            fill=tuple(round(a + (b - a) * f) for a, b in zip(top, bottom)) + (255,),
        )
    glow = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [OUT_W * 0.1, OUT_H * 0.05, OUT_W * 0.9, OUT_H * 0.45],
        fill=(90, 70, 190, 70),
    )
    bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(160)))
    return Image.alpha_composite(bg, _shadow())


def gif(recording, out, start=0.0, end=None, width=360, fps=24):
    # Everything is composited at the output size: the body, the backdrop
    # and the screen mask are drawn full size and scaled once here, so
    # ffmpeg never touches a 3x frame beyond the first scale.
    k = width / OUT_W
    height = round(OUT_H * k) // 2 * 2
    sx, sy = round(SCREEN_X * k), round(SCREEN_Y * k)
    sw, sh = round(SCREEN_W * k) // 2 * 2, round(SCREEN_H * k) // 2 * 2
    with tempfile.TemporaryDirectory() as tmp:
        body, mask, bg = (os.path.join(tmp, n) for n in ("b.png", "m.png", "g.png"))
        overlay().resize((width, height), Image.LANCZOS).save(body)
        _screen_mask(4).crop(
            (SCREEN_X * 4, SCREEN_Y * 4,
             (SCREEN_X + SCREEN_W) * 4, (SCREEN_Y + SCREEN_H) * 4)
        ).resize((sw, sh), Image.LANCZOS).save(mask)
        backdrop().resize((width, height), Image.LANCZOS).save(bg)
        if end is None:
            end = float(subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "csv=p=0", recording],
                check=True, capture_output=True, text=True,
            ).stdout)
        trim = ["-ss", str(start), "-to", str(end)]
        # Every still runs exactly as long as the clip: a looped image with
        # no end keeps alphamerge, which has no `shortest`, alive forever.
        still = ["-loop", "1", "-t", str(end - start)]
        graph = (
            f"[0:v]fps={fps},scale={sw}:{sh}:flags=lanczos,format=rgba[v];"
            f"[3:v]format=gray[m];[v][m]alphamerge[scr];"
            f"[2:v][scr]overlay={sx}:{sy}:shortest=1[a];"
            f"[a][1:v]overlay=0:0:shortest=1,split[x][y];"
            f"[x]palettegen=max_colors=256:stats_mode=diff[p];"
            f"[y][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle"
        )
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", *trim, "-i", recording,
             *still, "-i", body, *still, "-i", bg, *still, "-i", mask,
             "-filter_complex", graph, "-loop", "0", out],
            check=True,
        )


def detail(recording, out, crop, start=0.0, end=None, width=360, fps=24):
    cx, cy, cw, ch = crop
    margin = round(width * 0.07)
    card_w = width - 2 * margin
    card_h = round(ch * card_w / cw) // 2 * 2
    height = card_h + 2 * margin
    radius = round(card_w * 0.07)
    with tempfile.TemporaryDirectory() as tmp:
        mask, bg = (os.path.join(tmp, n) for n in ("m.png", "g.png"))
        m = Image.new("L", (card_w * 4, card_h * 4), 0)
        ImageDraw.Draw(m).rounded_rectangle(
            [0, 0, card_w * 4 - 1, card_h * 4 - 1], radius * 4, fill=255
        )
        m.resize((card_w, card_h), Image.LANCZOS).save(mask)
        back = backdrop().resize((width, round(OUT_H * width / OUT_W)))
        top = (back.height - height) // 2
        back = back.crop((0, top, width, top + height))
        shade = Image.new("RGBA", back.size, (0, 0, 0, 0))
        ImageDraw.Draw(shade).rounded_rectangle(
            [margin, margin + 6, margin + card_w, margin + card_h + 6],
            radius, fill=(0, 0, 0, 120),
        )
        back = Image.alpha_composite(back, shade.filter(ImageFilter.GaussianBlur(10)))
        back.save(bg)
        if end is None:
            end = float(subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "csv=p=0", recording],
                check=True, capture_output=True, text=True,
            ).stdout)
        still = ["-loop", "1", "-t", str(end - start)]
        graph = (
            f"[0:v]fps={fps},crop={cw}:{ch}:{cx}:{cy},"
            f"scale={card_w}:{card_h}:flags=lanczos,format=rgba[v];"
            f"[2:v]format=gray[m];[v][m]alphamerge[card];"
            f"[1:v][card]overlay={margin}:{margin}:shortest=1,split[x][y];"
            f"[x]palettegen=max_colors=256:stats_mode=diff[p];"
            f"[y][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle"
        )
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-ss", str(start),
             "-to", str(end), "-i", recording, *still, "-i", bg,
             *still, "-i", mask, "-filter_complex", graph, "-loop", "0", out],
            check=True,
        )


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "still":
        still(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif mode == "gif":
        a = argparse.ArgumentParser()
        a.add_argument("recording")
        a.add_argument("out")
        a.add_argument("--start", type=float, default=0.0)
        a.add_argument("--end", type=float)
        a.add_argument("--width", type=int, default=360)
        a.add_argument("--fps", type=int, default=24)
        o = a.parse_args(sys.argv[2:])
        gif(o.recording, o.out, o.start, o.end, o.width, o.fps)
    elif mode == "detail":
        a = argparse.ArgumentParser()
        a.add_argument("recording")
        a.add_argument("out")
        a.add_argument("--crop", type=int, nargs=4, required=True)
        a.add_argument("--start", type=float, default=0.0)
        a.add_argument("--end", type=float)
        a.add_argument("--width", type=int, default=360)
        a.add_argument("--fps", type=int, default=24)
        o = a.parse_args(sys.argv[2:])
        detail(o.recording, o.out, o.crop, o.start, o.end, o.width, o.fps)
    else:
        sys.exit(__doc__)
