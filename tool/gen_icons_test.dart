import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alokdalok/branding/app_icon_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 아이콘 PNG 생성기 (AppIconPainter → PNG). 저장소 루트에서:
///   flutter test tool/gen_icons_test.dart
/// test_preview 와 같은 방식(RepaintBoundary → toImage → PNG)으로 그린다.
/// 결과: web/ 아이콘, android mipmap-*, tool/out/ (스토어 아이콘·확인 그림, git 제외)
void main() {
  const res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  testWidgets('web icons', (t) async {
    await _icon(t, 'web/icons/Icon-192.png', 192);
    await _icon(t, 'web/icons/Icon-512.png', 512);
    await _icon(t, 'web/icons/Icon-maskable-192.png', 192, scale: .7);
    await _icon(t, 'web/icons/Icon-maskable-512.png', 512, scale: .7);
    await _icon(t, 'web/favicon.png', 32);
  });

  testWidgets('android legacy + adaptive foreground', (t) async {
    for (final MapEntry(key: d, value: k) in densities.entries) {
      await _icon(t, '$res/mipmap-$d/ic_launcher.png', (48 * k).round());
      await _icon(
        t,
        '$res/mipmap-$d/ic_launcher_foreground.png',
        (108 * k).round(),
        scale: .7,
        background: false,
      );
    }
  });

  testWidgets('play store icon (no alpha)', (t) async {
    await _icon(t, 'tool/out/store_icon.png', 512, opaque: true);
  });

  // 확인 그림: 108dp 캔버스(432px)에 72dp 보이는 칸과 66dp 안전 원을 겹친 것,
  // 그리고 런처 마스크(원·둥근 사각형·스쿼클·물방울)를 씌운 미리보기.
  testWidgets('adaptive check sheets', (t) async {
    await _render(
      t,
      'tool/out/adaptive_safe_zone.png',
      const Size(432, 432),
      CustomPaint(painter: _SafeZonePainter()),
    );
    await _render(
      t,
      'tool/out/adaptive_masks.png',
      const Size(4 * 200 + 5 * 24, 200 + 2 * 24),
      Container(
        color: const Color(0xFF3A3F4B),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            for (final m in _Mask.values) ...[
              SizedBox.square(
                dimension: 200,
                child: CustomPaint(painter: _MaskedPainter(m)),
              ),
              if (m != _Mask.values.last) const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  });
}

Future<void> _icon(
  WidgetTester t,
  String path,
  int px, {
  double scale = 1,
  bool background = true,
  bool opaque = false,
}) => _render(
  t,
  path,
  Size.square(px.toDouble()),
  CustomPaint(
    painter: AppIconPainter(scale: scale, drawBackground: background),
  ),
  opaque: opaque,
);

Future<void> _render(
  WidgetTester t,
  String path,
  Size size,
  Widget child, {
  bool opaque = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final key = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await t.runAsync(() async {
    final image = await boundary.toImage();
    try {
      if (!opaque) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        return png!.buffer.asUint8List();
      }
      final rgba = await image.toByteData();
      return _encodeRgbPng(
        image.width,
        image.height,
        rgba!.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  });
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!);
}

/// 알파 채널 없는 PNG (색 형식 2 = RGB 8비트). Play 스토어 아이콘용.
Uint8List _encodeRgbPng(int w, int h, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // 필터 없음
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc32(body)));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, 2, 0, 0, 0]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.takeBytes()));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// 108dp 캔버스: 체크무늬(투명 확인) 위에 전경, 72dp 보이는 칸(파랑)·66dp 안전 원(빨강)
class _SafeZonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final even = ((x + y) / cell).round().isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          Paint()
            ..color = even ? const Color(0xFFFFFFFF) : const Color(0xFFDDDDDD),
        );
      }
    }
    const AppIconPainter(scale: .7, drawBackground: false).paint(canvas, size);
    final dp = size.width / 108;
    final c = size.center(Offset.zero);
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 72 * dp, height: 72 * dp),
      Paint()
        ..color = const Color(0xFF2F6FE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      33 * dp,
      Paint()
        ..color = const Color(0xFFE0302F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

enum _Mask { circle, roundedSquare, squircle, teardrop }

/// 런처처럼: 108dp 중 가운데 72dp 를 잘라 마스크를 씌운다 (배경 단색 + 전경 0.7).
class _MaskedPainter extends CustomPainter {
  _MaskedPainter(this.mask);
  final _Mask mask;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final clip = switch (mask) {
      _Mask.circle => Path()..addOval(r),
      _Mask.roundedSquare =>
        Path()..addRRect(
          RRect.fromRectAndRadius(r, Radius.circular(size.width * .2)),
        ),
      _Mask.squircle =>
        Path()..addRRect(
          RRect.fromRectAndRadius(r, Radius.circular(size.width * .42)),
        ),
      _Mask.teardrop =>
        Path()..addRRect(
          RRect.fromRectAndCorners(
            r,
            topLeft: Radius.circular(size.width / 2),
            topRight: Radius.circular(size.width / 2),
            bottomLeft: Radius.circular(size.width / 2),
            bottomRight: Radius.circular(size.width * .1),
          ),
        ),
    };
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawRect(r, Paint()..color = AppIconPainter.backgroundTop);
    // 72dp 칸이 size 에 맞도록 108dp 캔버스를 키우고 가운데 맞춤
    final full = size.width * 108 / 72;
    canvas.translate(-(full - size.width) / 2, -(full - size.height) / 2);
    const AppIconPainter(
      scale: .7,
      drawBackground: false,
    ).paint(canvas, Size.square(full));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}
