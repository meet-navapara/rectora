// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Writes original Rectora icons and short sound effects. No third-party art.
void main() {
  final root = Directory.current;
  final brand = Directory('${root.path}/assets/brand')
    ..createSync(recursive: true);
  final sfx = Directory('${root.path}/assets/sfx')..createSync(recursive: true);
  File('${brand.path}/icon.png').writeAsBytesSync(_png(_mark(1024)));

  const android = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in android.entries) {
    final dir = Directory('${root.path}/android/app/src/main/res/${entry.key}');
    File('${dir.path}/ic_launcher.png')
        .writeAsBytesSync(_png(_mark(entry.value)));
    // Adaptive layer. Launchers crop to the middle 72 of its 108 units.
    final side = entry.value * 108 ~/ 48;
    File(
      '${dir.path}/ic_launcher_foreground.png',
    ).writeAsBytesSync(_png(_inset(_mark(side ~/ 2, transparent: true), side)));
  }

  final icons = Directory(
    '${root.path}/ios/Runner/Assets.xcassets/AppIcon.appiconset',
  );
  const ios = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  for (final entry in ios.entries) {
    File('${icons.path}/${entry.key}')
        .writeAsBytesSync(_png(_mark(entry.value)));
  }

  final launch = Directory(
    '${root.path}/ios/Runner/Assets.xcassets/LaunchImage.imageset',
  );
  for (final scale in [1, 2, 3]) {
    final name = scale == 1 ? 'LaunchImage.png' : 'LaunchImage@${scale}x.png';
    File('${launch.path}/$name')
        .writeAsBytesSync(_png(_mark(120 * scale, transparent: true)));
  }

  File('${sfx.path}/tap.wav').writeAsBytesSync(_tone([(880, 0.04)]));
  File('${sfx.path}/place.wav').writeAsBytesSync(_tone([(523, 0.09)]));
  File('${sfx.path}/error.wav').writeAsBytesSync(_tone([(196, 0.12)]));
  File('${sfx.path}/complete.wav')
      .writeAsBytesSync(_tone([(523, 0.08), (659, 0.08), (784, 0.16)]));
  print('Wrote Rectora icons and sound effects.');
}

/// Centers [mark] on a transparent square of [side] pixels.
Uint32List _inset(Uint32List mark, int side) {
  final size = math.sqrt(mark.length).round();
  final at = (side - size) ~/ 2;
  final pixels = Uint32List(side * side);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      pixels[(y + at) * side + x + at] = mark[y * size + x];
    }
  }
  return pixels;
}

Uint32List _mark(int size, {bool transparent = false}) {
  final pixels = Uint32List(size * size);
  const bg = 0xFF141A22;
  const copper = 0xFFE0975C;
  const paper = 0xFFF3E7D6;
  if (!transparent) {
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = bg;
    }
  }
  final radius = (size * 0.22).round();
  _roundRect(
    pixels,
    size,
    0,
    0,
    size,
    size,
    radius,
    copper,
    fill: false,
    stroke: math.max(2, (size * 0.07).round()),
  );
  _roundRect(
    pixels,
    size,
    (size * 0.22).round(),
    (size * 0.22).round(),
    (size * 0.34).round(),
    (size * 0.56).round(),
    (size * 0.06).round(),
    paper,
    fill: true,
    stroke: 0,
  );
  _roundRect(
    pixels,
    size,
    (size * 0.48).round(),
    (size * 0.22).round(),
    (size * 0.30).round(),
    (size * 0.28).round(),
    (size * 0.06).round(),
    copper,
    fill: true,
    stroke: 0,
  );
  return pixels;
}

void _roundRect(
  Uint32List pixels,
  int canvas,
  int x,
  int y,
  int w,
  int h,
  int radius,
  int argb, {
  required bool fill,
  required int stroke,
}) {
  final r = radius.clamp(0, math.min(w, h) ~/ 2);
  void plot(int px, int py) {
    if (px < 0 || py < 0 || px >= canvas || py >= canvas) return;
    pixels[py * canvas + px] = argb;
  }

  bool inside(int px, int py) {
    final left = x;
    final top = y;
    final right = x + w - 1;
    final bottom = y + h - 1;
    if (px < left || py < top || px > right || py > bottom) return false;
    var cx = px;
    var cy = py;
    if (px < left + r && py < top + r) {
      cx = left + r;
      cy = top + r;
    } else if (px > right - r && py < top + r) {
      cx = right - r;
      cy = top + r;
    } else if (px < left + r && py > bottom - r) {
      cx = left + r;
      cy = bottom - r;
    } else if (px > right - r && py > bottom - r) {
      cx = right - r;
      cy = bottom - r;
    } else {
      return true;
    }
    final dx = px - cx;
    final dy = py - cy;
    return dx * dx + dy * dy <= r * r;
  }

  for (var py = y; py < y + h; py++) {
    for (var px = x; px < x + w; px++) {
      if (!inside(px, py)) continue;
      if (fill) {
        plot(px, py);
      } else if (!inside(px + stroke, py) ||
          !inside(px - stroke, py) ||
          !inside(px, py + stroke) ||
          !inside(px, py - stroke)) {
        plot(px, py);
      }
    }
  }
}

Uint8List _png(Uint32List argb) {
  final size = math.sqrt(argb.length).round();
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0);
    for (var x = 0; x < size; x++) {
      final pixel = argb[y * size + x];
      raw.addByte((pixel >> 16) & 0xff);
      raw.addByte((pixel >> 8) & 0xff);
      raw.addByte(pixel & 0xff);
      raw.addByte((pixel >> 24) & 0xff);
    }
  }
  final idat = zlib.encode(raw.toBytes());
  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final name = type.codeUnits;
    final length = ByteData(4)..setUint32(0, data.length);
    out.add(length.buffer.asUint8List());
    out.add(name);
    out.add(data);
    final crc = ByteData(4)..setUint32(0, _crc32([...name, ...data]));
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', idat);
  chunk('IEND', const []);
  return out.toBytes();
}

int _crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xedb88320 & mask);
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Uint8List _tone(List<(double, double)> notes, {int rate = 22050}) {
  final samples = <int>[];
  for (final (freq, seconds) in notes) {
    final count = (rate * seconds).round();
    for (var i = 0; i < count; i++) {
      final attack = (i / (rate * 0.01)).clamp(0, 1);
      final release = ((count - i) / (rate * 0.03)).clamp(0, 1);
      final envelope = math.min(attack.toDouble(), release.toDouble());
      final sample = math.sin(2 * math.pi * freq * i / rate) * envelope * 0.35;
      samples.add((sample * 32767).round().clamp(-32767, 32767));
    }
  }
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  final bytes = data.buffer.asUint8List();
  final out = BytesBuilder();
  void word(String value) => out.add(value.codeUnits);
  void u32(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void u16(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  word('RIFF');
  u32(36 + bytes.length);
  word('WAVE');
  word('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  word('data');
  u32(bytes.length);
  out.add(bytes);
  return out.toBytes();
}
