# 알록달록 꼬마 놀이터

만 3세 전후 유아용 숫자·색깔 학습 게임 (Flutter + Flame, iOS / Android / Web 단일 코드베이스).

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
flutter build web --release --no-web-resources-cdn   # build/web (CanvasKit을 함께 담아 오프라인에서도 동작)
flutter build apk --release                          # build/app/outputs/flutter-apk/app-release.apk
flutter build ipa                                    # macOS + Xcode 필요
```

> Android release 빌드는 현재 Flutter 기본 debug 키로 서명됩니다. 스토어 출시 전에 업로드 키를 만들어
> `android/app/build.gradle.kts`의 `signingConfig`를 바꿔야 합니다.

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
  data/item_catalog.dart       옷 17테마 70종 + 이전 아이템 환불표
  data/vehicles.dart           탈것 7종(킥보드·자전거·자동차·오토바이·탱크·비행기·우주선, 종류별 1대),
                               색칠 9색(한 번 사면 모든 탈것에), 스티커 10종·6색·최대 12장
  data/stages.dart             숫자 8단계(4단계부터 섞어 놓고 한 가지만 세기)·색깔 5단계
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
  shop/                        꾸미기 상점 (옷 테마 탭 + 탈것 탭)
  screens/                     메인, 단계 선택(골인 길), 내 캐릭터, 내 가방, 설정, 친구 고르기, 이름
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

- 기본은 **녹음 목소리**입니다. 무료 오픈소스 음성 모델 MeloTTS(MIT 라이선스, 한국어 모델)로 만든
  문장 조각 409개(`assets/voice/*.mp3`, 약 3MB)를 이어 붙여 말합니다.
  - "빨간 풍선이 / 세 개! / 정말 잘했어요!" 처럼 조각으로 나눠 녹음해서 수천 가지 문장을 만듭니다.
  - 조각 목록은 `lib/services/voice_lines.dart`. 문장을 바꾸면 목록도 맞춰야 합니다
    (`test/state_test.dart`의 '녹음 음성 팩' 테스트가 빠진 조각을 알려 줍니다).
  - 다시 만들기: `flutter test tool/voice/export_lines_test.dart` → `tool/voice/lines.json`,
    맥에서 `tool/voice/gen_voice.command`(Homebrew·Python 3.10·ffmpeg 필요) → `voice/out`을 `assets/voice`로.
- 녹음에 없는 말(아이 이름 등)과 설정에서 '기기'를 고르면 기기 음성 합성(TTS, `flutter_tts`)을 씁니다.
  음높이를 올리면 기계음이 일그러져 무섭게 들려서 올리지 않습니다.
- 더 아이다운 목소리를 원하면 같은 파일 이름으로 사람 목소리를 녹음해 `assets/voice`를 바꾸면 됩니다.

## 배경 음악

- `tool/generate_music.py`로 직접 작곡·합성한 계절 곡 4개(`assets/audio/music/`, 외부 음원 없음).
  단계마다 계절이 바뀐다: 1단계 봄 → 2단계 여름 → 3단계 가을 → 4단계 겨울 → 5단계 다시 봄 … (배경도 같은 계절)
- 목소리가 나올 때는 음악을 작게 줄인다. 설정에서 끌 수 있다.
- 웹(특히 아이패드 Safari)은 Web Audio(`lib/services/web_audio.dart`)로 재생한다. 첫 터치로 소리를 깨우고,
  녹음 조각을 정확한 시각에 이어 붙여 끊기지 않게 한다.

## 저장 데이터

`SharedPreferences` 키 `alokdalok_save`에 JSON 하나 (현재 `version: 5`)와 직전 값 백업 `alokdalok_save_backup`.
Android/iOS는 앱 내부 저장소, Web은 브라우저 localStorage. 손상·누락 시 항목별 기본값으로 복구하고,
`SaveData.migrate()`에 버전별 변환을 추가해 연령 모드·프로필 기능으로 확장합니다.
