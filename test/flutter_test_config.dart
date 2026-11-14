import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// 위젯 테스트에서도 앱과 같은 Jua 폰트를 써서 실제 글자 폭으로 넘침을 검사한다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 한국어 기기로 돌린다 (언어 '자동'이 한국어가 되게). 영어는 테스트에서 직접 고른다.
  TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .localesTestValue = const [
    Locale('ko', 'KR'),
  ];
  final bytes = File('assets/fonts/Jua-Regular.ttf').readAsBytesSync();
  final loader = FontLoader('Jua')
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
  await testMain();
}
