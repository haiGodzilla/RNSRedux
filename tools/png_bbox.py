#!/usr/bin/env python3
"""Prints the painted bounding box of a PNG, in pixels and in tiles.

A Factorio sprite canvas is usually larger than the artwork inside it. The
bounding box says which part of the canvas actually carries pixels, and that
decides whether a sprite fits its entity footprint, and where it has to sit.

The tile factor is not arbitrary: at zoom 1 the game draws 32 screen pixels per
tile, so a layer with scale s covers 32 / s canvas pixels per tile.

    sprite          scale      canvas px per tile
    ItemDrive*E     1/4        128
    DriveS          1/2         64
    Controller      192/512     85.3333
    Item IO Bus     1/8        256

Usage:  python3 tools/png_bbox.py <file.png> [canvas_px_per_tile] [--brief]

--brief prints one line per file, for looping over a whole directory.
Only the standard library is used, so it runs on any python3.
"""
import struct
import sys
import zlib


def read_chunks(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("not a PNG file")
    pos, chunks = 8, []
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunks.append((kind, data[pos + 8:pos + 8 + length]))
        pos += 12 + length
        if kind == b"IEND":
            break
    return chunks


def unfilter_rows(bit_depth, color_type, raw, width, height):
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    stride = (width * channels * bit_depth + 7) // 8
    bpp = max(1, channels * bit_depth // 8)
    rows, previous = [], bytearray(stride)
    pos = 0
    for _ in range(height):
        filter_type = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            left = line[i - bpp] if i >= bpp else 0
            above = previous[i]
            upper_left = previous[i - bpp] if i >= bpp else 0
            value = line[i]
            if filter_type == 0:
                pass
            elif filter_type == 1:
                value = (value + left) & 0xFF
            elif filter_type == 2:
                value = (value + above) & 0xFF
            elif filter_type == 3:
                value = (value + ((left + above) >> 1)) & 0xFF
            elif filter_type == 4:
                estimate = left + above - upper_left
                to_left = abs(estimate - left)
                to_above = abs(estimate - above)
                to_corner = abs(estimate - upper_left)
                if to_left <= to_above and to_left <= to_corner:
                    predictor = left
                elif to_above <= to_corner:
                    predictor = above
                else:
                    predictor = upper_left
                value = (value + predictor) & 0xFF
            else:
                raise SystemExit("unknown row filter %d" % filter_type)
            line[i] = value
        rows.append(bytes(line))
        previous = line
    return channels, rows


def alpha_at(color_type, bit_depth, channels, row, x, transparent_index):
    if color_type == 6:                       # RGBA
        return row[x * 4 * (bit_depth // 8) + 3 * (bit_depth // 8)]
    if color_type == 4:                       # grey + alpha
        return row[x * 2 * (bit_depth // 8) + (bit_depth // 8)]
    if color_type == 3:                       # palette
        index = row[x * (bit_depth // 8)]
        return transparent_index.get(index, 255)
    return 255


def measure(path):
    """Returns width, height, per_tile-independent bounds and alpha presence."""
    header, payload, transparent_index = None, b"", {}
    for kind, body in read_chunks(open(path, "rb").read()):
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body[:13])
        elif kind == b"tRNS":
            transparent_index = {i: 0 for i, a in enumerate(body) if a == 0}
        elif kind == b"IDAT":
            payload += body
    if header is None:
        raise SystemExit("no IHDR")

    width, height, bit_depth, color_type, _, _, interlace = header
    if interlace != 0:
        raise SystemExit("interlaced PNG, not supported")
    if bit_depth not in (8, 16):
        raise SystemExit("bit depth %d, not supported" % bit_depth)
    if color_type not in (0, 2, 3, 4, 6):
        raise SystemExit("color type %d, not supported" % color_type)

    channels, rows = unfilter_rows(bit_depth, color_type, zlib.decompress(payload),
                                   width, height)
    has_alpha = color_type in (4, 6) or (color_type == 3 and transparent_index)
    if not has_alpha:
        return width, height, bit_depth, color_type, False, (0, 0, width - 1, height - 1)

    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for y, row in enumerate(rows):
        for x in range(width):
            if alpha_at(color_type, bit_depth, channels, row, x, transparent_index) > 0:
                x0 = min(x0, x)
                x1 = max(x1, x)
                y0 = min(y0, y)
                y1 = max(y1, y)
    if x1 < 0:
        raise SystemExit("every pixel of this file is fully transparent")
    return width, height, bit_depth, color_type, True, (x0, y0, x1, y1)


def main():
    arguments = [a for a in sys.argv[1:] if a != "--brief"]
    brief = "--brief" in sys.argv
    if not arguments:
        raise SystemExit(__doc__)
    path = arguments[0]
    per_tile = float(arguments[1]) if len(arguments) > 1 else 0.0

    width, height, bit_depth, color_type, has_alpha, box = measure(path)
    x0, y0, x1, y1 = box

    if brief:
        text = "%-22s canvas %dx%d  art %dx%d px" % (
            path.split("/")[-1], width, height, x1 - x0 + 1, y1 - y0 + 1)
        if per_tile > 0:
            text += "  = %.3f x %.3f tiles  y %.3f..%.3f" % (
                (x1 - x0 + 1) / per_tile, (y1 - y0 + 1) / per_tile,
                y0 / per_tile, (y1 + 1) / per_tile)
        print(text)
        return

    print("file     :", path)
    print("canvas   : %d x %d px, color type %d, bit depth %d"
          % (width, height, color_type, bit_depth))
    if not has_alpha:
        print("alpha    : this color type carries none, the box is the whole canvas")
    print("painted  : x %d..%d, y %d..%d  (%d x %d px)"
          % (x0, x1, y0, y1, x1 - x0 + 1, y1 - y0 + 1))
    if per_tile <= 0:
        return

    def tiles(value):
        return value / per_tile

    centre_y = (y0 + y1 + 1) / 2.0
    print("factor   : %.3f canvas px per tile" % per_tile)
    print("canvas in: %.3f x %.3f tiles" % (tiles(width), tiles(height)))
    print("painted  : x %.3f..%.3f, y %.3f..%.3f tiles  (%.3f x %.3f)"
          % (tiles(x0), tiles(x1 + 1), tiles(y0), tiles(y1 + 1),
             tiles(x1 - x0 + 1), tiles(y1 - y0 + 1)))
    print("centre   : canvas %.3f,%.3f | painted %.3f,%.3f tiles"
          % (tiles(width / 2.0), tiles(height / 2.0),
             tiles((x0 + x1 + 1) / 2.0), tiles(centre_y)))
    print("offset   : painted centre minus canvas centre = %.3f, %.3f tiles"
          % (tiles((x0 + x1 + 1) / 2.0 - width / 2.0),
             tiles(centre_y - height / 2.0)))
    print("to south : painted south edge sits %.3f tiles south of the canvas centre"
          % tiles(y1 + 1 - height / 2.0))
    print("note     : the canvas centre sits on the entity centre only if the")
    print("           prototype's shift is zero. Subtract the shift to compare.")


if __name__ == "__main__":
    main()
