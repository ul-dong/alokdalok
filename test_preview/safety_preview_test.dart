import 'dart:async';
import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/device_heat.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/perf_monitor.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카메라가 있는 기기처럼 보이게 하는 미리보기용 센서 (창은 열리지 않는다)
class _PreviewSensor implements EyeSensor {
  @override
  bool keepCamera = true;
  @override
  String get mode => '카메라 유지 (stopImageStream)';
  @override
  bool get supported => true;

  @override
  EyeDetectStats? get detectStats => null;
  @override
  Future<FaceReading?> sampleOnce({Duration budget = EyeRules.windowBudget}) =>
      Completer<FaceReading?>().future;
  @override
  Future<void> stop() async {}
  @override
  double defaultDistanceCm(double size) => 1 / size;
}

/// 놀이 시간·눈 쉬기 덮개, 부모 확인, 설정 화면 미리보기
void main() {
  Future<(GameState, DateTime Function(), void Function(Duration))> make({
    EyeGuard? eye,
  }) async {
    var now = DateTime(2026, 10, 21, 9);
    final s = GameState(
      storage: MemoryStorage.noticeSeen(),
      audio: RecordingAudio(),
      now: () => now,
      eyeGuard: eye,
    );
    await s.load();
    await s.setNickname('별이');
    for (var i = 0; i < 40; i++) {
      await s.rewardCorrect(firstTry: true);
    }
    await s.purchase('crown_gold');
    return (s, () => now, (Duration d) => now = now.add(d));
  }

  Future<void> run(
    WidgetTester t,
    void Function(Duration) advance,
    Duration d,
  ) async {
    const step = Duration(seconds: 5);
    for (var left = d; left > Duration.zero; left -= step) {
      advance(step);
      await t.pump(step);
    }
  }

  for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
    final w = size.width.toInt();

    testWidgets('limit + gate $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final (s, _, advance) = await make();
      await s.setPlayLimit(10);
      await s.setEyeBreak(20);
      await t.pumpWidget(AlokdalokApp(state: s));
      await t.pump(const Duration(seconds: 1));
      await run(t, advance, const Duration(minutes: 10, seconds: 5));
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/safety_limit_$w.png'),
      );
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is Pressable && w.semanticLabel == '부모님: 15분 더',
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/safety_gate_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('eye break $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final (s, _, advance) = await make();
      await s.setPlayLimit(0);
      await t.pumpWidget(AlokdalokApp(state: s));
      await t.pump(const Duration(seconds: 1));
      await run(t, advance, const Duration(minutes: 10, seconds: 5));
      await run(t, advance, const Duration(seconds: 5));
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/safety_break_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('confirmParent dialog $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final (s, _, _) = await make();
      late BuildContext ctx;
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SettingsScreen();
              },
            ),
          ),
        ),
      );
      // ignore: use_build_context_synchronously
      confirmParent(ctx, random: Random(4));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/safety_confirm_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('settings full $w', (t) async {
      // 설정 화면 전체를 한 장에 (높이만 늘림)
      t.view.physicalSize = Size(size.width, 2000);
      t.view.devicePixelRatio = 1;
      final (s, _, _) = await make();
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/settings_full_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('settings eye heat off $w', (t) async {
      // 기기가 뜨거워(SEVERE) 눈 지킴이를 이번 실행 동안 끔 → 설정 눈 지킴이 칸 안내
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final eye = EyeGuard(
        sensor: _PreviewSensor(),
        heat: DeviceHeat(const HeatStatus(thermal: HeatLevel.severe)),
      );
      final (s, _, _) = await make(eye: eye);
      expect(eye.heatOff, isTrue);
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      await t.ensureVisible(find.text('눈 지킴이'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('기기가 뜨거워서 눈 지킴이를 잠시 껐어요'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/settings_eye_heat_off_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('settings eye diagnostics duty $w', (t) async {
      // 진단 칸: 창 열기 시간·방식·기기 열·절전·배터리 (기기 따뜻함 + 배터리 18% → 창 주기 ×2)
      t.view.physicalSize = Size(size.width, 2400);
      t.view.devicePixelRatio = 1;
      final eye = EyeGuard(
        sensor: _PreviewSensor(),
        heat: DeviceHeat(
          const HeatStatus(
            thermal: HeatLevel.moderate,
            powerSave: false,
            battery: 18,
          ),
        ),
      );
      final (s, _, _) = await make(eye: eye);
      final st = EyeStats.instance..reset();
      for (final ms in [420, 380, 510]) {
        st.windowClosed(Duration(milliseconds: ms));
        st.check();
      }
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      await t.longPress(find.textContaining('회원가입'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('창 열기 시간'), findsOneWidget);
      expect(find.text('방식 바꾸기'), findsOneWidget);
      await expectLater(
        find.byType(EyeDiagnosticsPanel),
        matchesGoldenFile('shots/settings_eye_diag_duty_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
      st.reset();
    });

    testWidgets('settings eye diagnostics $w', (t) async {
      // '부모님께'를 길게 누르면 열리는 눈 지킴이 진단 칸 (아래쪽만)
      t.view.physicalSize = Size(size.width, 2400);
      t.view.devicePixelRatio = 1;
      final (s, _, _) = await make();
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      await t.longPress(find.textContaining('회원가입'));
      await t.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(EyeDiagnosticsPanel),
        matchesGoldenFile('shots/settings_eye_diag_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('settings perf diagnostics $w', (t) async {
      // 렉, 터치 진단 칸: 느린 프레임 몇 장, 최근 누름 두 번, 소리 플레이어
      t.view.physicalSize = Size(size.width, 2400);
      t.view.devicePixelRatio = 1;
      final (s, _, _) = await make();
      final now = DateTime.now();
      final m = PerfMonitor(now: () => now);
      for (final ms in [6.0, 8.0, 12.0, 18.0, 41.0, 9.0]) {
        m.addFrame(ms);
      }
      t.binding.pointerRouter.addGlobalRoute(m.onPointer);
      addTearDown(() => t.binding.pointerRouter.removeGlobalRoute(m.onPointer));
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PerfDiagnosticsPanel(monitor: m),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('화면 그리기'));
      await t.pump(const Duration(milliseconds: 500));
      await t.longPress(find.text('가장 느린 장'));
      await t.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(PerfDiagnosticsPanel),
        matchesGoldenFile('shots/settings_perf_diag_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });
  }
}
