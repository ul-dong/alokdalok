// 모양·크기·짝 맞추기 놀이 단계별 미리보기 (shots/game_<종류>_<단계>_<폭>.png)
// 실행: flutter test test_preview/games_preview_test.dart --update-goldens
import 'dart:math';

import 'package:alokdalok/games/common/quiz_widgets.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_preview_test.dart' show st;

Future<void> _pump(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const kinds = [GameKind.shape, GameKind.size, GameKind.match];
  for (final kind in kinds) {
    for (var stage = 1; stage <= kind.stageCount; stage++) {
      for (final size in const [
        Size(1280, 800),
        Size(844, 390),
        Size(568, 320),
      ]) {
        // 큰 화면은 모든 단계, 작은 화면은 첫·마지막 단계만
        if (size.width < 1280 && stage != 1 && stage != kind.stageCount) {
          continue;
        }
        testWidgets('${kind.name} $stage ${size.width}', (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          final s = await st();
          await t.pumpWidget(
            AppScope(
              state: s,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: gameScreen(kind, stage, random: Random(stage * 7)),
              ),
            ),
          );
          await _pump(t);
          await expectLater(
            find.byType(MaterialApp).first,
            matchesGoldenFile(
              'shots/game_${kind.name}_${stage}_${size.width.toInt()}.png',
            ),
          );
          // 틀린 보기를 두 번 눌러 힌트·흐림·반짝임을 본다 (큰 화면만)
          if (size.width == 1280) {
            final tiles = find.byType(QuizTile);
            var wrongs = 0;
            for (var i = 0; i < tiles.evaluate().length && wrongs < 2; i++) {
              final before = (s.audio as RecordingAudio).played.length;
              await t.tap(tiles.at(i), warnIfMissed: false);
              await t.pump(const Duration(milliseconds: 50));
              final played = (s.audio as RecordingAudio).played;
              if (played.length > before && played.last.name == 'tryAgain') {
                wrongs++;
              } else if (played.length > before &&
                  played.last.name == 'correct') {
                break;
              }
            }
            await _pump(t, 8);
            await expectLater(
              find.byType(MaterialApp).first,
              matchesGoldenFile('shots/game_${kind.name}_${stage}_hint.png'),
            );
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 3));
        });
      }
    }
    testWidgets('${kind.name} stages', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      final s = await st();
      for (var id = 1; id <= 2; id++) {
        await s.completeSession(kind, id);
      }
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: StagePicker(game: kind),
          ),
        ),
      );
      await _pump(t);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/stages_${kind.name}.png'),
      );
    });
  }
}
