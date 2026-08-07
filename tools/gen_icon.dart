// Extension icon generator - 32x32 PNG (no Flutter required).
//
// Usage:
//   cd tools
//   dart pub get
//   dart run gen_icon.dart <seed> <out.png>
//
// Draws: dark rounded background + a progress bar in HunterToon colors.
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run gen_icon.dart <seed> <out.png>');
    exit(1);
  }
  final seed = args[0];
  final outPath = args[1];

  const size = 32;
  final image = img.Image(width: size, height: size, numChannels: 4);

  // خلفية داكنة نصف شفافة بحواف دائرية (3px).
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  final bg = img.ColorRgba8(0x14, 0x17, 0x21, 255);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final inRect = x >= 1 && y >= 1 && x <= size - 2 && y <= size - 2;
      if (!inRect) continue;
      final corner = (x < 5 && y < 5) ||
              (x >= size - 5 && y < 5) ||
              (x < 5 && y >= size - 5) ||
              (x >= size - 5 && y >= size - 5)
          ? 1
          : 0;
      final dx = x < 5 ? (x - 4).abs() : (x >= size - 5 ? (x - (size - 5)).abs() : 0);
      final dy = y < 5 ? (y - 4).abs() : (y >= size - 5 ? (y - (size - 5)).abs() : 0);
      final dist = dx > dy ? dx : dy;
      if (corner == 1 && dist > 3) continue;
      image.setPixelRgba(x, y, bg.r, bg.g, bg.b, bg.a);
    }
  }

  // لونان يميّزان الإضافة حسب الـ seed (رمز بسيط).
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0xffff;
  }
  final accent = img.ColorRgba8(0xE8, 0xC4, 0x6A, 255); // ذهبي HunterToon
  final bar = img.ColorRgba8(0x6A, 0x9F, 0xE8, 255); // أزرق مكمل

  // شريط تقدم: إطار + تعبئة 60%.
  const frameY = 11;
  img.fillRect(image,
      x1: 5, y1: frameY, x2: 26, y2: frameY + 3,
      color: bar);
  img.fillRect(image,
      x1: 5, y1: frameY + 4, x2: 26, y2: frameY + 7,
      color: img.ColorRgba8(0x2A, 0x2E, 0x3A, 255));
  img.fillRect(image,
      x1: 6, y1: frameY + 5, x2: 6 + 13, y2: frameY + 6,
      color: bar);

  // سهم صعود (التقدم).
  img.fillRect(image, x1: 10, y1: 8, x2: 12, y2: 9, color: accent);
  img.fillRect(image, x1: 11, y1: 7, x2: 13, y2: 7, color: accent);
  img.fillRect(image, x1: 13, y1: 8, x2: 14, y2: 9, color: accent);
  img.fillRect(image, x1: 10, y1: 10, x2: 14, y2: 10, color: accent);

  // علامة ✓ بجانب الشريط.
  img.fillRect(image, x1: 20, y1: 20, x2: 21, y2: 21, color: accent);
  img.fillRect(image, x1: 22, y1: 22, x2: 23, y2: 22, color: accent);
  img.fillRect(image, x1: 19, y1: 22, x2: 20, y2: 22, color: accent);

  final png = img.encodePng(image);
  File(outPath).writeAsBytesSync(png);
  stdout.writeln('icon written to $outPath (${png.length} bytes)');
}
