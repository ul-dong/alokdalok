import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 미리보기 그림을 실제 화면과 같게 만든다.
/// - Jua: 앱 글꼴 (실제 글자 폭으로 넘침 검사)
/// - MaterialIcons: 아이콘이 네모로 나오지 않게
/// - Roboto: 글꼴을 따로 정하지 않은 글자의 기본 글꼴
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('Jua', ['assets/fonts/Jua-Regular.ttf']);

  final root = _flutterRoot();
  if (root != null) {
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    await _load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    await _load('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf',
    ]);
  }
  await testMain();
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
    any = true;
  }
  if (any) await loader.load();
}

/// FLUTTER_ROOT 환경 변수, 없으면 dart 실행 파일 위치에서 Flutter SDK를 찾는다.
String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;
  // .../flutter/bin/cache/dart-sdk/bin/dart
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/bin/flutter').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return null;
}
