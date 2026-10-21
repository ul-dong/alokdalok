import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 놀이 시간·눈 쉬기 덮개, 부모 확인, 설정 화면 미리보기
void main() {
  Future<(GameState, DateTime Function(), void Function(Duration))>
  make() async {
    var now = DateTime(2026, 10, 21, 9);
    final s = GameState(
      storage: MemoryStorage(),
      audio: RecordingAudio(),
      now: () => now,
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
  }
}
