import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 위젯 테스트에서도 앱과 같은 Jua 폰트를 써서 실제 글자 폭으로 넘침을 검사한다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = File('assets/fonts/Jua-Regular.ttf').readAsBytesSync();
  final loader = FontLoader('Jua')
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
  await testMain();
}
