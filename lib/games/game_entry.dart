import 'dart:math';

import 'package:flutter/material.dart';

import '../data/stages.dart';
import '../services/game_state.dart';
import '../widgets/common.dart';
import 'color_game/color_game_screen.dart';
import 'match_game/match_game_screen.dart';
import 'number_game/number_game_screen.dart';
import 'shape_game/shape_game_screen.dart';
import 'size_game/size_game_screen.dart';

/// 놀이 종류와 단계 번호로 놀이 화면을 만든다 (놀이터·단계 고르기에서 쓴다).
Widget gameScreen(GameKind kind, int stageId, {Random? random}) =>
    switch (kind) {
      GameKind.number => NumberGameScreen(stageId: stageId, random: random),
      GameKind.color => ColorGameScreen(stageId: stageId, random: random),
      GameKind.shape => ShapeGameScreen(stageId: stageId, random: random),
      GameKind.size => SizeGameScreen(stageId: stageId, random: random),
      GameKind.match => MatchGameScreen(stageId: stageId, random: random),
    };

/// 지금 화면을 놀이 화면으로 바꾼다 (짧은 페이드).
Future<void> openGame(BuildContext context, GameKind kind, int stageId) =>
    Navigator.of(context).pushReplacement(softRoute(gameScreen(kind, stageId)));

/// 모양·크기·짝 맞추기 단계 카드에 그릴 문제 그림.
/// 숫자·색깔 놀이는 단계 고르기 화면이 직접 그리므로 null.
Widget? stageArt(GameKind kind, int stageId) => switch (kind) {
  GameKind.shape => ShapeStageArt(Stages.shape[stageId - 1]),
  GameKind.size => SizeStageArt(Stages.size[stageId - 1]),
  GameKind.match => MatchStageArt(Stages.match[stageId - 1]),
  GameKind.number || GameKind.color => null,
};
