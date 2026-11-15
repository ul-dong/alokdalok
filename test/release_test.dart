// Google Play 출시 설정 점검 (docs/RELEASE.md)
import 'dart:io';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android SDK 수준은 Flutter 기본값이 아니라 고정값 (targetSdk 36)', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    expect(g, contains('compileSdk = 36'));
    expect(g, contains('targetSdk = 36'));
    expect(g, contains('minSdk = 24'));
    expect(g, isNot(contains('flutter.targetSdkVersion')));
    expect(g, contains('"x86_64"'), reason: '크롬북 (AAB 는 ABI 별로 나뉘어 받는다)');
  });

  test('아동용 앱 매니페스트: 쓰지 않는 권한 제거, 클라우드 백업 끔', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final p in [
      'android.permission.INTERNET',
      'android.permission.RECORD_AUDIO',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'com.google.android.gms.permission.AD_ID',
    ]) {
      expect(
        m,
        contains('<uses-permission android:name="$p" tools:node="remove" />'),
        reason: p,
      );
    }
    expect(m, contains('android:allowBackup="false"'));
    expect(
      RegExp(r'camera\.any" android:required="false"')
          .hasMatch(m.replaceAll(RegExp(r'\s+'), ' ')),
      isTrue,
      reason: '카메라 없는 기기도 설치할 수 있게',
    );
  });

  test('개인정보처리방침 페이지: 한국어·영어, 카메라 처리·ML Kit 진단 정보 공개, 이메일은 자리표시', () {
    final h = File('web/privacy.html').readAsStringSync();
    expect(h, contains('lang="ko"'));
    expect(h, contains('lang="en"'));
    expect(h, contains('카메라'));
    expect(h, contains('camera'));
    expect(h, contains('저장하지 않고, 어디로도 전송하지 않습니다'));
    expect(h, contains('[앱 전용 문의 이메일 — 출시 전 입력]'));
    expect(h, contains('[App contact email — to be filled in before release]'));
    expect(h, isNot(contains('[문의 이메일 — 출시 전 입력]')));
    // 데이터 안전성 B안: 앱은 보내지 않지만 ML Kit이 진단 정보를 수집할 수 있다
    expect(h, contains('Google ML Kit이 Google Play 서비스를 통해 진단 정보를 수집할 수 있습니다'));
    expect(
      h,
      contains(
        'may collect diagnostic information through Google Play services',
      ),
    );
    expect(h, contains('ml-kit/android-data-disclosure'));
    // 권한은 부모님 안내 뒤에
    expect(h, contains('[허용하고 시작]'));
    expect(h, contains('[Allow and start]'));
    expect(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(h), isFalse);
  });

  testWidgets('세로 창(큰 화면 Android 16 포함)이면 돌려 달라는 안내가 앱 글꼴로', (t) async {
    t.view.physicalSize = const Size(800, 1280);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
    await s.load();
    await t.pumpWidget(AlokdalokApp(state: s));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(RotateHint), findsOneWidget);
    // Material 이 없으면 노란 밑줄·기본 글꼴로 나온다
    expect(
      find.ancestor(of: find.byType(Text), matching: find.byType(Material)),
      findsWidgets,
    );
    final style = t
        .widget<RichText>(
          find.descendant(
            of: find.byType(RotateHint),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!;
    expect(style.fontFamily, 'Jua');
    expect(style.decoration, isNot(TextDecoration.underline));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 9));
  });
}
