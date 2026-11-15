# 알록달록 꼬마 놀이터

만 3세 전후 유아용 숫자·색깔·모양·크기·짝 맞추기 학습 놀이 (Flutter + Flame, iOS / Android / Web 단일 코드베이스).

글을 읽지 못해도 그림·음성만으로 놀 수 있고, 틀려도 혼나지 않는 편안한 놀이를 목표로 합니다.
회원가입·서버·광고·추적·현금 결제·확률형 뽑기가 없습니다.

## 실행

```bash
flutter pub get
flutter run                     # 연결된 기기 / 에뮬레이터
flutter run -d chrome           # 웹
```

## 빌드

```bash
./tool/build_web.sh            # 웹: build/web (base-href /alokdalok/, CDN 없음, 오프라인 서비스 워커 목록 생성)
./install_and_build.command    # Android: 도구 설치(~/alokdev) + arm 전용 release APK → build/alokdalok.apk
flutter build ios --simulator  # iOS 시뮬레이터 (Xcode + CocoaPods, 먼저 cd ios && pod install)
```

- **웹 오프라인:** Flutter 기본 서비스 워커는 이제 스스로 등록을 지우므로 `web/offline_sw.js`를 직접 등록한다
  (`web/flutter_bootstrap.js`). `tool/build_web.sh`가 미리 담을 파일 목록 `offline_files.json`을 만들고
  서비스 워커에 빌드 번호를 붙인다. 그냥 `flutter build web`만 하면 오프라인 목록이 빠진다.
- **Android:** arm 전용(armeabi-v7a, arm64-v8a, `android/gradle.properties`의 `disable-abi-filtering`),
  ML Kit 얼굴 인식은 Play 서비스(unbundled) 버전. release 서명은 `android/key.properties`(git 제외)에
  키 위치만 적고, 비밀번호는 빌드 때 직접 입력한다(`ALOK_STORE_PASSWORD` 환경 변수). 키가 없으면 debug 키로 서명된다.
- **iOS:** 최소 iOS 15.5(ML Kit 요구). ML Kit에는 arm64 시뮬레이터 조각이 없어서 `pod install` 때
  `tool/ios/mlkit_sim_slices.py`가 시뮬레이터용 사본(`ios/Pods/MLKitSim`)을 만들고 시뮬레이터 빌드에서만 쓴다.
  실기기 서명(Team, 번들 ID)은 Xcode에서 직접 설정한다.

## 앱 아이콘·이름

- **이름:** 한국어 "알록달록 꼬마 놀이터", 영어 "Balloon Playground" (Android `res/values*/strings.xml`의 `app_name`,
  iOS `CFBundleDisplayName`, 웹 `manifest.json`). 패키지명·번들 ID는 `io.github.uldong.alokdalok` (Play 출시 뒤에는 못 바꾼다).
- **아이콘:** 풍선 3개 묶음. 이미지 원본 없이 `lib/branding/app_icon_painter.dart`(CustomPainter)로 그리고,
  PNG는 아래 명령 한 번으로 모두 다시 만든다.

```bash
flutter test tool/gen_icons_test.dart
```

| 결과 | 크기 | 배율·배경 |
|---|---|---|
| `web/icons/Icon-192.png`, `Icon-512.png`, `web/favicon.png`(32) | 192, 512, 32 | 1.0, 배경 있음 |
| `web/icons/Icon-maskable-192.png`, `Icon-maskable-512.png` | 192, 512 | 0.7, 배경 있음 |
| `android/.../mipmap-*/ic_launcher.png` (레거시) | 48·72·96·144·192 | 1.0, 배경 있음 |
| `android/.../mipmap-*/ic_launcher_foreground.png` (어댑티브 전경) | 108dp: 108·162·216·324·432 | 0.7, 투명 |
| `tool/out/store_icon.png` (Play 스토어, git 제외) | 512 | 1.0, 알파 없음 |
| `tool/out/adaptive_safe_zone.png`, `adaptive_masks.png` (확인용, git 제외) | | 66dp 안전 원, 런처 마스크 미리보기 |

어댑티브 아이콘(`mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml`)의 배경은 그라데이션 없이
단색 `#BFE3FA`(`values/ic_launcher_background.xml`)로 둔다. 런처가 패럴랙스로 움직이기 때문이다.
iOS 앱 아이콘(`ios/Runner/Assets.xcassets/AppIcon.appiconset`)은 아직 Flutter 기본 그림이다.

## 테스트

```bash
flutter analyze
flutter test
```

- `test/logic_test.dart` 숫자·색깔 문제 생성과 정답/오답 판정, 힌트, 닉네임 검증
- `test/state_test.dart` 코인 보상, 오답 시 차감 없음, 구매·보유·장착/해제, 설정, 재실행 후 유지, 손상 데이터 복구, 마이그레이션
- `test/widget_test.dart` 5가지 화면 크기(320×568 ~ 1280×800)에서 넘침 없음, 첫 실행 닉네임 흐름, 숫자 놀이 한 판 전체, 색깔 놀이, 상점 구매 확인
- `test/flutter_test_config.dart` 테스트에서도 실제 Jua 폰트를 불러와 글자 폭을 실제와 같게 검사

## 구조

```
lib/
  main.dart, app.dart          앱 시작(가로 고정), 첫 실행이면 12지신 친구 고르기 → 이름 짓기
  core/palette.dart            파스텔 색상표 (모든 그림이 공유)
  core/economy.dart            코인 보상량·한 판 문제 수 (밸런스 조정은 여기만)
  data/item_catalog.dart       옷 17테마 71종 + 이전 아이템 환불표
  data/vehicles.dart           탈것 7종(열기구·기차·자동차·오토바이·탱크·비행기·우주선, 종류별 1대),
                               색칠 9색(한 번 사면 모든 탈것에), 스티커 10종·6색·최대 12장
  data/stages.dart             숫자 8단계(4단계부터 섞어 놓고 한 가지만 세기)·색깔·모양·크기·짝 맞추기 각 5단계
  data/game_objects.dart       사물 종류, 색 이름, 조사(이/가, 을/를), 셈 단위(개/마리)
  character/zodiac.dart        12지신 동물과 색
  character/animal_painter.dart 자체 제작 납작한 꼬마 동물 그림 (굵은 갈색 외곽선, 레이어 순서 고정)
  character/item_art.dart      옷 그림 (style별 모양 + colors로 색)
  vehicle/                     탈것 그림, 스티커 그림, 스티커 놀이 화면(garage_screen), 탄 모습(ride_view)
  games/common/journey_trail.dart 골인 지점까지 가는 길 (맞힐 때마다 앞으로, 끝에서 "골인!")
  games/common/scene_game.dart Flame 배경(하늘·바다·집·구름·새·계절 효과)과 정답 반짝이
  games/common/game_frame.dart 놀이 공통 틀 (상태줄, 문제 카드, 아래쪽 골인 길, 일시정지, 결과)
  games/number_game/           숫자 놀이 로직(number_round) + 화면
  games/color_game/            색깔 놀이 로직(color_round) + 화면
  games/shape_game/, size_game/, match_game/  모양·크기·짝 맞추기 (로직 + 화면, 공용 QuizCard·QuizGrid)
  shop/                        꾸미기 상점 (옷 테마 탭 + 탈것 탭)
  screens/                     홈(큰 버튼 3개), 놀이터, 단계 고르기(골인 길), 내 캐릭터, 설정, 친구 고르기, 이름 (내 가방 bag_screen은 홈에서 빠져 지금은 쓰지 않음)
  services/                    저장(버전·백업·복구), 음성/효과음, 앱 상태
assets/
  fonts/Jua-Regular.ttf        SIL OFL 1.1 (assets/licenses/Jua-OFL.txt, 앱 '오픈소스 라이선스'에 표시)
  audio/sfx/*.wav              tool/generate_sfx.py로 합성한 자체 효과음 (실로폰 느낌)
```

### 새 옷 테마·아이템 추가
`OutfitTheme`에 테마를 추가하고 `ItemCatalog.all`에 아이템을 넣습니다. 이미 있는 모양
(`robothelmet`, `crown`, `firehelmet`, `policecap`, `armyhelmet`, `bonehead`, `robot`, `dress`, `firesuit`,
`police`, `camo`, `caveman`, `robotboots`, `boots`, `magic`, `loafer`, `sandal`, `visor`, `ribbon`, `badge`,
`dogtag`, `tooth`, `necklace`, `wings`, `jetpack`, `firetank`, `backpack`, `club`)에 색만 바꾸면 코드 수정이
필요 없고, 새 모양은 `item_art.dart`에 style을 추가합니다. 없앤 아이템은 `ItemCatalog.retired`에 가격과 함께
남기면 예전 저장값을 불러올 때 코인으로 돌려줍니다.

### 새 미니게임 추가
`games/<이름>/`에 순수 로직 클래스(문제 생성·판정)와 화면을 만들고, 화면은 `GameFrame`을 쓰면
상단 상태줄·발자국 진행·일시정지·결과·보상이 그대로 붙습니다. `GameKind`와 `SaveData`에 진행 단계를 추가합니다.

## 음성 안내

- 기본은 **녹음 목소리**입니다. 무료 오픈소스 음성 모델 MeloTTS(MIT 라이선스, 한국어·영어 모델)로 만든
  문장 조각(`assets/voice/ko/*.mp3` 1044개, `assets/voice/en/*.mp3` 976개)을 이어 붙여 말합니다. 녹음은 언어별 폴더
  (`assets/voice/<언어>/` + `manifest.json`)에 두고, 녹음이 없는 언어·문장은 그 언어 기기 음성으로 읽습니다.
  - 목소리: 밝은 만화 캐릭터 느낌(한국어 약 310Hz, 영어 약 370Hz). 높이만 올리면 무섭게 들려서
    포먼트는 1.03~1.06만 올리고 억양으로 생동감을 낸다. 튐·전자음 깨짐을 막으려고 피치 옥타브 오류 보정,
    무성음(s, z, ch) 구간 보호, 곡선 다듬기를 하고, 억양 확대는 약하게(1.3배) 둔다.
    질문은 만 3세가 따라오게 천천히(3.2음절/초 이하), 한국어는 어절마다 약한 억양 굽이를 넣는다. mp3 64kbps.
    설정은 `tool/voice/child_voice.py`의 `VOICES` 한곳(MeloTTS 속도·sdp_ratio·씨앗 포함, 같은 문장은 늘 같은 녹음).
  - "빨간 풍선이 / 세 개! / 정말 잘했어요!" 처럼 조각으로 나눠 녹음해서 수천 가지 문장을 만듭니다.
  - 조각 목록은 언어별로 `lib/l10n/ko/voice_lines_ko.dart`, `lib/l10n/en/voice_lines_en.dart`
    (`lib/services/voice_lines.dart`의 `VoiceLines.forLocale`). 문장을 바꾸면 목록도 맞춰야 합니다
    (`test/state_test.dart`의 '녹음 음성 팩' 테스트가 빠진 조각을 알려 줍니다).
  - 다시 만들기: 맥에서 `tool/gen_voice.command [ko|en]`(Homebrew 필요). 그 언어 문장 목록을 내보내고
    (`tool/voice/export_lines_test.dart` → `tool/voice/lines_<언어>.json`), 녹음이 없는 문장만 새로 만들어
    `assets/voice/<언어>`에 넣는다. 영어는 MeloTTS 영어 모델(EN-US)을 쓴다.
    목소리 설정을 바꿨으면 `tool/gen_voice.command <언어> --all`로 그 언어를 전부 다시 녹음한다.
- 녹음에 없는 말(아이 이름 등)과 설정에서 '기기'를 고르면 기기 음성 합성(TTS, `flutter_tts`)을 씁니다.
  음높이를 올리면 기계음이 일그러져 무섭게 들려서 올리지 않습니다.
- 더 아이다운 목소리를 원하면 같은 파일 이름으로 사람 목소리를 녹음해 `assets/voice/ko`를 바꾸면 됩니다.

## 다국어 (한국어 / English)

- 화면 문구: `lib/l10n/app_ko.arb`(기준) · `app_en.arb` → `flutter gen-l10n`이 `lib/l10n/gen/`을 만든다.
  키 이름은 `화면_용도`(예: `settings_language`, 말하는 문장은 끝에 `Say`, 설명에 `[음성]`).
  위젯은 `context.l10n.키`, 화면 밖 코드는 `L10n.current.키`.
- 문장 조립기: `lib/l10n/phrases.dart`(`Phrases.current`). 한국어(`ko/korean_phrases.dart`)는 조사(이/가, 을/를)와
  셈 단위(개/마리), 영어(`en/english_phrases.dart`)는 관사와 복수형("1 balloon" / "3 balloons"). 아이템·친구·탈것
  영어 이름도 여기 있다. 한국어 결과는 녹음 팩과 글자 하나까지 같아야 한다(`test/voice_ko_snapshot_test.dart`).
- 언어 고르기: 설정(부모님용) → 언어: 자동 / 한국어 / English. 자동은 기기(웹은 브라우저) 언어, 지원하지 않는
  언어면 한국어. 새로 설치하면 자동, 예전 저장값(v7 이하)은 한국어로 둔다(저장 v8).
- 새 언어 더하기: `app_<언어>.arb`, `lib/l10n/<언어>/`에 `Phrases` 구현과 음성 목록, `AppLanguage.supported`,
  `assets/voice/<언어>/manifest.json`(빈 `{}`면 기기 음성).
- 한국어 문자열이 `lib/`에 새로 들어가면 `test/l10n_hangul_test.dart`가 알려 준다(허용 목록에 이유를 적는다).

## 배경 음악

- `tool/generate_music.py`로 직접 작곡·합성한 계절 곡 4개(`assets/audio/music/`, 외부 음원 없음).
  단계마다 계절이 바뀐다: 1단계 봄 → 2단계 여름 → 3단계 가을 → 4단계 겨울 → 5단계 다시 봄 … (배경도 같은 계절)
- 홈·상점 곡도 있다. 멜로디는 첫 버전 그대로이고, 베이스·화음 패드·분산 화음·멜로디 층과 짧은 잔향으로 다듬었다.
  모든 곡은 -20 LUFS로 맞추고(앱에서는 약 0.3배로 더 작게 틀어 목소리보다 확실히 작다), 끝과 처음이 끊김 없이 이어진다.
  효과음(`tool/generate_sfx.py`)도 소리마다 크기를 맞췄다(정답 > 다시 해 봐요 > 누르기).
- 음악은 부드럽게 커지고(페이드 인) 꺼질 때 스르르 줄어든다(페이드 아웃).
  목소리(녹음·기기 음성 모두)가 나올 때는 음악을 작게 줄인다(덕킹). 설정에서 끌 수 있다.
- 웹(특히 아이패드 Safari)은 Web Audio(`lib/services/web_audio.dart`)로 재생한다. 첫 터치로 소리를 깨우고,
  녹음 조각을 정확한 시각에 이어 붙여 끊기지 않게 한다.

## 저장 데이터

`SharedPreferences` 키 `alokdalok_save`에 JSON 하나 (현재 `version: 5`)와 직전 값 백업 `alokdalok_save_backup`.
Android/iOS는 앱 내부 저장소, Web은 브라우저 localStorage. 손상·누락 시 항목별 기본값으로 복구하고,
`SaveData.migrate()`에 버전별 변환을 추가해 연령 모드·프로필 기능으로 확장합니다.
