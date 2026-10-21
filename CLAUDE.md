# CLAUDE.md — 알록달록 꼬마 놀이터

만 3~4세용 가로 화면 학습 놀이 앱 (Flutter + Flame). 대상: Android · iOS · 웹(GitHub Pages).

## 기준 문서

- **제품 사양은 `docs/MASTER_PROMPT.md`.** 코드와 다르면 문서가 이긴다. 사양을 바꿔야 할 이유가 보이면 먼저 사용자에게 제안하고 승인받는다.
- 사양과 코드의 차이 목록: `docs/GAP_REPORT.md` (기능을 채우면 함께 갱신).
- 원본 PDF(`*.pdf`, `*.pdf.zip`)는 루트에 있지만 git에 넣지 않는다.

## 도구 경로

- Flutter: `/Users/ul_dong/alokdev/flutter/bin/flutter` (3.47.x)
- JDK 17: `/Users/ul_dong/alokdev/jdk-17*/Contents/Home` (`JAVA_HOME`), Android SDK: `/Users/ul_dong/alokdev/android-sdk` (`ANDROID_HOME`)

## 테스트

```bash
F=/Users/ul_dong/alokdev/flutter/bin/flutter
$F pub get
$F test                                   # test/ : 단위·위젯 테스트 (반드시 전부 통과)
$F test test_preview --update-goldens     # 미리보기 그림 렌더 → test_preview/shots/*.png (눈으로 확인용)
$F analyze
```

- `test_preview/`는 합격/불합격 스위트가 아니라 **미리보기 그림 생성기**다. 항상 `--update-goldens`로 돌리고, 결과 PNG를 열어 화면을 확인한다. `shots/`, `failures/`는 git에서 제외. (`touch_audit_test.dart`는 터치 칸 크기 점검)
- **주의: `flutter analyze`는 이 폴더 경로(한글 `알록달록`)에서 분석 서버가 JSON 오류로 죽는다.** ASCII 경로로 복사해서 돌린다:
  `rsync -a --delete --exclude build ./ "$TMPDIR/alok_ana/" && (cd "$TMPDIR/alok_ana" && $F analyze)`
  (심볼릭 링크는 실제 경로로 풀려서 소용없다. `flutter test`는 한글 경로에서도 잘 된다.)
- 사양 목표: 테스트 142개. 새 기능마다 테스트를 추가한다.

## 꼭 지킬 것

- **화면 크기:** 568×320, 844×390, 1280×800 가로에서 넘침(overflow)이 없어야 한다 (`test/widget_test.dart`의 화면 크기 테스트 + `test_preview` 그림으로 확인). 높이 340 미만이면 전체 축소.
- **한국어 UI**, 모든 안내는 녹음 음성(`assets/voice`, 문장 조각은 `lib/services/voice_lines.dart`). 새 문장을 넣으면 음성 팩 테스트가 빠진 조각을 알려 준다.
- **모든 그림은 CustomPainter로 직접 그린다** (이미지 에셋 없음, 기존 캐릭터 모방 금지).
- **광고·현금 결제·뽑기(가챠) 금지.** 코인은 놀이로만, 틀려도 차감 없음. 개인정보는 기기 안에만.
- 터치 칸 60~72px 이상, 옆으로 밀기(가로 스크롤) 대신 큰 화살표로 쪽 넘기기, 짧은 페이드 전환, 애니메이션은 공용 20fps 시계(`lib/core/slow_clock.dart`).
- 저장 형식이 바뀌면 `SaveData.currentVersion`을 올리고 `SaveData.migrate()`에 단계 추가 + 테스트.

## 빌드

- **웹:** `tool/build_web.sh`로 빌드한다 (`flutter build web`만 하면 오프라인 서비스 워커 목록 `offline_files.json`이 빠진다).
- **iOS 시뮬레이터:** ML Kit에 arm64 시뮬레이터 조각이 없어서, `pod install` 때 `tool/ios/mlkit_sim_slices.py`가 만드는 `ios/Pods/MLKitSim` 사본으로 처리한다 (`ios/Podfile` post_install). arm64를 빼는(EXCLUDED_ARCHS) 방식은 iOS 27 시뮬레이터에서 실행되지 않는다.

## 커밋

- 메시지는 한국어 요약 한 줄(무엇을 했는지, 예: `숫자 놀이: 보기에 주사위 발자국 추가`), 필요하면 빈 줄 뒤 본문.
- 마지막 줄에 다음 트레일러:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

- 원격(remote) 추가·푸시는 사용자가 요청할 때만.
