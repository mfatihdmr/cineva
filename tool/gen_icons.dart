// Cineva ikon üretici. Çalıştırma: dart run tool/gen_icons.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const _design = 1024;
const _ss = 2; // süper-örnekleme katsayısı

const _bgTop = [11, 15, 20];
const _bgBottom = [20, 32, 42];
const _teal = [0, 205, 176];
const _tealDeep = [0, 127, 140];
const _coral = [255, 90, 95];

img.Color _c(List<int> rgb, [int a = 255]) =>
    img.ColorRgba8(rgb[0], rgb[1], rgb[2], a);

void main() {
  Directory('assets/icon').createSync(recursive: true);
  final icon = _render(withBackground: true, scale: 1.0);
  final foreground = _render(withBackground: false, scale: 0.68);
  _write(icon, 'assets/icon/app_icon.png');
  _write(foreground, 'assets/icon/app_icon_foreground.png');
  final small = img.copyResize(icon, width: 512, interpolation: img.Interpolation.average);
  _write(small, 'assets/icon/logo_512.png');
  stdout.writeln('icons üretildi');
}

img.Image _render({required bool withBackground, required double scale}) {
  final size = _design * _ss;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  if (withBackground) {
    _paintGradientBackground(canvas, size);
  } else {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        canvas.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      }
    }
  }

  final cx = size / 2.0, cy = size / 2.0;
  final u = size / _design; // tasarım birimi
  final rOuter = 336.0 * u * scale;
  final rInner = 214.0 * u * scale;
  final rMid = (rOuter + rInner) / 2.0;
  final startDeg = 50.0, endDeg = 310.0;

  // C yayı (dış kenar + iç kenar ters yönde) -> poligon
  final pts = <img.Point>[];
  for (var d = startDeg; d <= endDeg; d += 1.5) {
    final t = d * math.pi / 180.0;
    pts.add(img.Point((cx + rOuter * math.cos(t)).round(), (cy + rOuter * math.sin(t)).round()));
  }
  for (var d = endDeg; d >= startDeg; d -= 1.5) {
    final t = d * math.pi / 180.0;
    pts.add(img.Point((cx + rInner * math.cos(t)).round(), (cy + rInner * math.sin(t)).round()));
  }
  img.fillPolygon(canvas, vertices: pts, color: _c(_teal));

  // Yayın içine doğru koyu teal gölgelendirme: iç kenara paralel ince bant
  final innerBand = <img.Point>[];
  const bandFrom = 200.0;
  for (var d = startDeg; d <= endDeg; d += 1.5) {
    final t = d * math.pi / 180.0;
    innerBand.add(img.Point((cx + (rInner + 26 * u * scale) * math.cos(t)).round(),
        (cy + (rInner + 26 * u * scale) * math.sin(t)).round()));
  }
  for (var d = endDeg; d >= startDeg; d -= 1.5) {
    final t = d * math.pi / 180.0;
    innerBand.add(img.Point((cx + rInner * math.cos(t)).round(), (cy + rInner * math.sin(t)).round()));
  }
  img.fillPolygon(canvas, vertices: innerBand, color: _c(_tealDeep, bandFrom.round()));

  // Film şeridi delikleri: orta yarıçapta boşluklar
  final holeR = (30.0 * u * scale).round();
  for (final d in [75.0, 120.0, 165.0, 210.0, 255.0, 300.0]) {
    final t = d * math.pi / 180.0;
    img.fillCircle(
      canvas,
      x: (cx + rMid * math.cos(t)).round(),
      y: (cy + rMid * math.sin(t)).round(),
      radius: holeR,
      color: withBackground ? _c(_bgTop) : img.ColorRgba8(0, 0, 0, 0),
      antialias: true,
      blend: withBackground ? img.BlendMode.alpha : img.BlendMode.direct,
    );
  }

  // Oynat üçgeni: C'nin ağzında
  final tri = [
    img.Point((cx + 46 * u * scale).round(), (cy - 112 * u * scale).round()),
    img.Point((cx + 46 * u * scale).round(), (cy + 112 * u * scale).round()),
    img.Point((cx + 236 * u * scale).round(), cy.round()),
  ];
  img.fillPolygon(canvas, vertices: tri, color: _c(_coral));

  final out = img.copyResize(canvas,
      width: _design, height: _design, interpolation: img.Interpolation.average);
  return out;
}

void _paintGradientBackground(img.Image canvas, int size) {
  const radiusUnit = 0.215; // köşe yuvarlaklığı (oransal)
  final r = (size * radiusUnit).toDouble();
  for (var y = 0; y < size; y++) {
    final ty = y / (size - 1);
    for (var x = 0; x < size; x++) {
      if (!_insideRoundedRect(x, y, size, r)) {
        canvas.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        continue;
      }
      final tx = x / (size - 1);
      final t = (tx * 0.55 + ty * 0.45).clamp(0.0, 1.0);
      final px = (_bgTop[0] + (_bgBottom[0] - _bgTop[0]) * t).round();
      final py = (_bgTop[1] + (_bgBottom[1] - _bgTop[1]) * t).round();
      final pz = (_bgTop[2] + (_bgBottom[2] - _bgTop[2]) * t).round();
      // alt-üst köşede hafif teal parlama
      final glow = math.max(0.0, 1.0 - ((tx - 0.85).abs() / 0.35 + (ty - 0.9).abs() / 0.35))
          .clamp(0.0, 1.0);
      canvas.setPixel(
        x,
        y,
        img.ColorRgba8(
          (px + _teal[0] * glow * 0.16).round(),
          (py + _teal[1] * glow * 0.16).round(),
          (pz + _teal[2] * glow * 0.16).round(),
          255,
        ),
      );
    }
  }
}

bool _insideRoundedRect(int x, int y, int size, double r) {
  final left = x < r, right = x > size - 1 - r;
  final top = y < r, bottom = y > size - 1 - r;
  if (!(left || right || top || bottom)) return true;
  final ccx = (left ? r : right ? size - 1 - r : x).toDouble();
  final ccy = (top ? r : bottom ? size - 1 - r : y).toDouble();
  final dx = x - ccx, dy = y - ccy;
  return dx * dx + dy * dy <= r * r;
}

void _write(img.Image image, String path) {
  final bytes = img.encodePng(image);
  File(path).writeAsBytesSync(bytes);
  stdout.writeln('yazildi: $path (${(bytes.length / 1024).round()} KB)');
}
