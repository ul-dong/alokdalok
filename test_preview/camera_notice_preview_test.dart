// 부모님 카메라 안내 미리보기: 안내 / [나중에] 뒤 / 권한 거절 뒤 를 한국어·영어, 세 크기로 그린다.
// shots/camera_notice_<언어>_<단계>_<폭>.png
// 실행: flutter test test_preview/camera_notice_preview_test.dart --update-goldens
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/screens/camera_notice_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/l10n_screens.dart';

/// 권한을 거절하는 가짜 카메라
class _DenyCamera implements EyeSensor {
  @override
  bool keepCamera = true;
  @override
  String get mode => '';
  @override
  bool get supported => true;
  @override
  EyeDetectStats? get detectStats => null;
  @override
  double defaultDistanceCm(double size) => 1 / size;
  @override
  Future<FaceReading?> sampleOnce({
    Duration budget = EyeRules.windowBudget,
  }) async => throw const EyeSensorDenied('denied');
  @override
  Future<void> stop() async {}
}

void main() {
  tearDown(() => L10n.use(AppLanguage.fallback));

  for (final size in l10nSizes) {
    final w = size.width.toInt();
    for (final code in ['ko', 'en']) {
      final l = lookupAppLocalizations(Locale(code));
      for (final stage in ['ask', 'later', 'denied', 'settings']) {
        testWidgets('$code $stage $w', (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final s = GameState(
            storage: MemoryStorage(),
            audio: RecordingAudio(),
            eyeGuard: EyeGuard(sensor: _DenyCamera()),
          );
          await s.load();
          await t.pumpWidget(
            l10nApp(
              s,
              CameraNoticeScreen(
                fromSettings: stage == 'settings',
                onDone: (_) {},
              ),
              code,
            ),
          );
          await t.pump(const Duration(milliseconds: 400));
          Finder button(String label) => find.byWidgetPredicate(
            (w) => w is PillButton && w.semanticLabel == label,
          );
          if (stage == 'later') await t.tap(button(l.cameraNotice_later));
          if (stage == 'denied') await t.tap(button(l.cameraNotice_allow));
          for (var i = 0; i < 5; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          expect(t.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp).first,
            matchesGoldenFile('shots/camera_notice_${code}_${stage}_$w.png'),
          );
        });
      }
    }
  }
}
