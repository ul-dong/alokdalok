import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alokdalok/branding/app_icon_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [AppIconPainter] 를 [px] 크기로 그려 RGBA 바이트를 돌려준다.
Future<(int, List<int>)> _rgba(
  WidgetTester t,
  int px, {
  double scale = 1,
  bool background = true,
}) async {
  final bytes = await t.runAsync(() async {
    final rec = ui.PictureRecorder();
    AppIconPainter(
      scale: scale,
      drawBackground: background,
    ).paint(Canvas(rec), Size.square(px.toDouble()));
    final image = await rec.endRecording().toImage(px, px);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return (px, bytes!);
}

int _alpha((int, List<int>) img, int x, int y) =>
    img.$2[(y * img.$1 + x) * 4 + 3];

void main() {
  testWidgets('배경 있으면 모서리까지 불투명, 없으면 모서리는 투명', (t) async {
    final withBg = await _rgba(t, 128);
    expect(_alpha(withBg, 0, 0), 255);
    expect(_alpha(withBg, 127, 127), 255);

    final noBg = await _rgba(t, 128, scale: .7, background: false);
    expect(_alpha(noBg, 0, 0), 0);
    expect(_alpha(noBg, 127, 0), 0);
    // 가운데 풍선 몸통은 그려져 있다
    expect(_alpha(noBg, 64, 50), 255);
  });

  testWidgets('어댑티브 전경(0.7배)은 108dp 중 66dp 안전 원 안에 들어온다', (t) async {
    const px = 432; // 108dp × 4
    final img = await _rgba(t, px, scale: .7, background: false);
    const c = px / 2;
    const safe = 33 * px / 108; // 66dp 지름의 반지름
    var maxR = 0.0;
    for (var y = 0; y < px; y++) {
      for (var x = 0; x < px; x++) {
        if (_alpha(img, x, y) == 0) continue;
        maxR = math.max(
          maxR,
          math.sqrt(math.pow(x + .5 - c, 2) + math.pow(y + .5 - c, 2)),
        );
      }
    }
    expect(maxR, greaterThan(safe * .6)); // 너무 작지도 않게
    expect(maxR, lessThanOrEqualTo(safe));
  });

  test('앱 이름·패키지명이 한 가지로 맞춰져 있다', () {
    const pkg = 'io.github.uldong.alokdalok';
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('namespace = "$pkg"'));
    expect(gradle, contains('applicationId = "$pkg"'));
    expect(
      File(
        'android/app/src/main/kotlin/io/github/uldong/alokdalok/MainActivity.kt',
      ).readAsStringSync(),
      startsWith('package $pkg\n'),
    );
    expect(
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
      isNot(contains('com.alokdalok')),
    );

    const res = 'android/app/src/main/res';
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="@string/app_name"'),
    );
    expect(
      File('$res/values/strings.xml').readAsStringSync(),
      contains('<string name="app_name">알록달록 꼬마 놀이터</string>'),
    );
    expect(
      File('$res/values-en/strings.xml').readAsStringSync(),
      contains('<string name="app_name">Balloon Playground</string>'),
    );
    for (final n in ['ic_launcher', 'ic_launcher_round']) {
      expect(
        File('$res/mipmap-anydpi-v26/$n.xml').readAsStringSync(),
        allOf(
          contains('@color/ic_launcher_background'),
          contains('@mipmap/ic_launcher_foreground'),
        ),
      );
    }
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File('$res/mipmap-$d/ic_launcher_foreground.png').existsSync(),
        isTrue,
      );
    }
  });
}
