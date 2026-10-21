import 'package:flutter/material.dart';

import '../widgets/screen_fit.dart';
import 'palette.dart';

/// 앱 전체 테마. 앱과 미리보기·테스트가 같은 모습이 되도록 한 곳에서 만든다.
ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Jua',
  scaffoldBackgroundColor: Palette.skyBottom,
  // 화면 전환은 짧은 페이드 (눈이 피로한 미끄러짐·번쩍임 없이)
  pageTransitionsTheme: fadePageTransitions,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.pink,
    surface: Palette.cream,
  ),
  textTheme: const TextTheme().apply(
    bodyColor: Palette.text,
    displayColor: Palette.text,
  ),
);
