# 사양 대비 코드 차이 (GAP REPORT)

- 기준 사양: `docs/MASTER_PROMPT.md` (2026-10-21, iOS 정식 포함)
- 기준 코드: 2026-10-21 05:04 스냅샷 (`/Users/ul_dong/alokdev/alokdalok_app`에서 가져옴, 첫 커밋 `기준선`)
- 이 스냅샷 이후 GitHub(ul-dong/alokdalok, 웹 빌드만 남음)에 올라간 기능 — 놀이터 화면, 모양·크기·짝 놀이, 부모 확인, 놀이 시간·눈 쉬기, ALOK1- 백업, 버튼 이름 읽기, 기차·열기구(+저장 마이그레이션), 탈것 방향, 꾹 눌러 나가기 — 은 **소스가 없어 다시 만들어야 한다.**
- 표기: **있음** / **부분** / **없음**

## 기준선 결과 (2026-10-21)

| 항목 | 결과 |
|---|---|
| `flutter pub get` | 성공 (13개 패키지 상위 버전 있음, 제약상 미적용) |
| `flutter analyze` | 한글 경로에서 분석 서버 크래시(JSON FormatException). ASCII 경로 복사본에서 **No issues found** |
| `flutter test` (test/) | **120개 전부 통과** (소스상 `test`/`testWidgets` 72곳: state 33·widget 19·logic 14·eye_guard 6, 화면 크기 반복 포함 실행 120건). 사양 목표 142 |
| `flutter test test_preview` | 그대로 돌리면 9 통과 / 32 실패 (골든 비교: `shots/` 없음 + 저장된 PNG 픽셀 차이). 미리보기 생성기이므로 `--update-goldens`로 돌리면 **41개 전부 통과** |

## 1. 화면 구성과 흐름

| 사양 | 상태 | 현재 코드 / 메모 |
|---|---|---|
| 첫 실행: 친구 고르기 → 이름 짓기 → 이후 홈 | 있음 | `lib/app.dart` RootGate, `screens/zodiac_picker_screen.dart`, `screens/nickname_screen.dart` |
| 홈: 큰 버튼 3개(놀이터 가기·내 캐릭터·꾸미기 상점)만 | **부분** | `screens/home_screen.dart`: 숫자 놀이·색깔 놀이·내 캐릭터·꾸미기 상점·내 가방·탈것 꾸미기 6개 타일. '놀이터 가기' 없음, 가방·탈것 꾸미기 별도 진입 |
| 홈 구석 작은 톱니바퀴 → 부모 확인 → 설정 | 부분 | 톱니바퀴(60px) 있음, 부모 확인 없음 |
| 놀이터 화면 (기구 그림 5개, 이름표, 깬 단계만큼 별, 내 캐릭터 서 있음) | **없음** | 새 화면 필요 (`screens/playground_screen.dart` 예정) |
| 단계 고르기: 카드에 문제 그림 + 계절 아이콘, 아래 골인 길 | 있음(가로 스크롤 문제) | `screens/stage_picker.dart` (계절 아이콘, JourneyTrail, 잠김 시 "앞 단계를 먼저…"). 카드 목록이 `ListView` 가로 스크롤 → 원칙 4 위반. 잠긴 카드 흔들림 확인 필요 |
| 놀이 화면: 위 멈춤·발자국·코인 / 가운데 문제 카드 / 아래 길·말풍선 | 있음 | `games/common/game_frame.dart` |
| 내 캐릭터: 옷 입기, 탈것 타기, 친구 바꾸기 | 있음 | `screens/character_screen.dart` (+ `screens/bag_screen.dart` 중복 기능) |
| 설정: 눈 보호·놀이 시간·눈 쉬기 간격·소리·백업 | **부분** | `screens/settings_screen.dart`: 소리(음성·효과음·음악·목소리 종류), 눈 지킴이, 닉네임, 기록 지우기(꾹 누르기), 라이선스. 놀이 시간·눈 쉬기·백업 없음 |

## 2. 놀이 5종

공통 규칙: 단계 5개(숫자 8개), 한 판 5문제(`Economy.questionsPerSession = 5` 있음), 목소리 문제 + "다시 듣기".

| 놀이 | 상태 | 현재 코드 / 메모 |
|---|---|---|
| 숫자 놀이 (미끄럼틀), 8단계 | 있음 | `games/number_game/`, `data/stages.dart` `Stages.number` 8단계, 4단계부터 섞인 물건 중 한 가지만 세기 (`NumberMode`) |
| └ 보기에 숫자 + 주사위 모양 발자국 | 있음 | `number_game_screen.dart` `_Choice` + `games/common/number_shape.dart` |
| └ 정답·오답 모두 "하나, 둘…" 세기 + 도장 "쾅" + 보기 자리에 큰 숫자, 물건 가리지 않음 | 있음 | `_startCountingHint`, `games/common/stamp.dart`, `Sfx.stamp` |
| └ 원색, 단계마다 다양, 많으면 줄 맞춤 | 있음 | `objectRows()` 줄 맞춤, 단계별 색 목록 |
| 색깔 놀이 (그네), 5단계 | 있음 | `games/color_game/`, `Stages.color` 5단계 (`swatchFromStart`, `mixedShapes`) |
| 모양 놀이 (모래놀이터) | **없음** | 동그라미·세모·네모·별·하트·다이아 / 같은 색·회전·견본과 같은 모양 |
| 크기 놀이 (시소) | **없음** | 큰 것/작은 것, 3개 이상 "가장", 차이 감소 |
| 짝 맞추기 (회전목마) | **없음** | 뒤집지 않음, 2→6쌍, 마지막 같은 물건 다른 색 |
| 공통 흐름: 정답→효과음·칭찬·코인→다음, 결과(별·코인, 또 하기/다음 단계/집으로) | 있음 | `game_frame.dart` 결과 화면 |
| 단계마다 계절 배경·음악 | 있음 | `scene_game.dart` `seasonForStage`, 계절 음악 4곡 |
| 1번 틀림 그림 힌트, 2번 틀림 정답 빛남, 틀린 보기 흐려짐 | 있음 | 숫자(`wrongPicks`, `glow`, opacity .35), 색깔(`faded`, `glow`) |
| `GameKind` 확장 | 없음 | `services/game_state.dart` `enum GameKind { number, color }`, `SaveData`에 숫자·색깔 진행만 |

## 3. 캐릭터 (24마리)

| 사양 | 상태 | 메모 |
|---|---|---|
| 12지신 + 공룡 12종 | 있음 | `character/zodiac.dart` (`FriendGroup.zodiac/dino`), `animal_painter.dart` |
| 같은 2등신 몸매, 옷 공유 | 있음 | |
| 이름 짓기: 예시 없음, 비우면 랜덤, 동물 실명 | 있음(확인 권장) | `character/nickname.dart`, `nickname_screen.dart` |
| 친구 12마리 화살표 쪽 넘기기 | 부분 | 12지신/공룡 그룹 탭 + `Wrap`. 화살표 페이지 넘김은 아님 |

## 4. 옷 꾸미기 / 상점

| 사양 | 상태 | 메모 |
|---|---|---|
| 테마 17개 | 있음 | `data/item_catalog.dart` `OutfitTheme` 17개 |
| 자리 5곳 (머리·옷·신발·장식·등) | 있음 | `ItemSlot` |
| 아이템 71개, 10~45코인 | 있음 | 71개, 가격 10~45 (README는 70개로 적혀 있음 — 고칠 것) |
| 눌러서 바로 입어 보기, 이름 말하기 | 있음 | `shop/shop_screen.dart` `say(item.name)` |
| ✔/✖ 구매 확인 | 있음 | `shop/item_widgets.dart` |
| 코인 부족: "놀이하면서 코인을 모아요" + 진행 막대, 결제 화면 없음 | 있음 | `shop_screen.dart` ~433행 |
| 테마 17개 큰 화살표 쪽 넘기기 (가로 밀기 금지) | **없음** | `ThemeTabs`가 `ListView` 가로 스크롤 |

## 5. 탈것 7종

| 사양 | 상태 | 메모 |
|---|---|---|
| 열기구 20 · 기차 25 · 자동차 40 · 오토바이 40 · 탱크 50 · 비행기 50 · 우주선 50 | 있음 | `data/vehicles.dart` 7종. 기차·열기구는 `vehicle/vehicle_painter.dart`에 새로 그림 (다리는 기관실·바구니 안, 스티커 자리 넓음) |
| 자전거·킥보드 → 기차·열기구 저장 마이그레이션 (스티커·색 옮김) | 있음 | `SaveData.migrate` 끝에서 버전과 상관없이 `Vehicles.retired`에 있는 id를 옮김 (가진 탈것·타는 탈것·스티커·칠한 색·산 색). 여러 번 돌려도 같음. 버전 번호는 그대로 |
| 고르고 "탑승!" 눌러야 탄다 | 있음 | 내 친구·상점·꾸미기 모두 고르기(이름 말하기) → "탑승!". 사도 바로 타지 않음 (`buyVehicle`) |
| 타면 캐릭터가 옆을 보며 앉음 (방향) | 있음 | `character/rider_pose.dart` 공통 변환(얼굴 돌리기 `AnimalPainter.sideways` + 앉은 팔다리). 24마리 × 7종 |
| 스티커 10종 × 6색, 고르고→누르기, 지우개, 드래그 없음 | 있음 | `StickerKind` 10, `stickerColors` 6, `vehicle/garage_screen.dart` (최대 12장) |
| 색칠: 탈것마다 따로, 한 색 10코인, 처음 색 공짜 | 있음 | `Vehicles.paintPrice = 10`, `paintKey('paint@vehicle')`, `canPaint`. 코인이 모자라면 꾸미기 화면에 "놀이하면서 코인을 모아요" + 진행 막대 |
| 가로 스크롤 금지 | 있음 | 꾸미기: 칸 크기를 맞추고 탈것이 많으면 화살표로 넘김. 내 친구·상점 탈것 칸은 `vehicle/fit_grid.dart`로 한 화면에. (공용 화살표 위젯은 트랙 A) |

## 6. 코인 규칙

| 하는 일 | 사양 | 코드 (`lib/core/economy.dart`) | 상태 |
|---|---|---|---|
| 처음 시작 | 10 | `startingCoins = 10` | 있음 |
| 한 번에 맞힘 | 2 | `correctFirstTry = 2` | 있음 |
| 다시 시도해서 맞힘 | 1 | `correctAfterRetry = 1` | 있음 |
| 한 판 끝내기 | 3 | `sessionComplete = 3` | 있음 |
| 처음 판을 끝냄 (한 번) | 5 | `firstPlayBonus = 5` | 있음 |
| 새 단계 처음 끝냄 | 5 | `newStageBonus = 5` | 있음 |
| 틀려도 차감 없음 | | `state_test.dart`에서 검사 | 있음 |

## 7. 아이 안전·건강

| 사양 | 상태 | 메모 |
|---|---|---|
| 부모 확인: 덧셈(각 6~9) 숫자 패드, 설정 진입·놀이 시간 연장 시 | **없음** | `widgets/parental_gate.dart` 예정 |
| 눈 보호·놀이 시간·부모 확인 **기본 켜짐** | **부분** | `SaveData.eyeGuardOn = false` 기본 꺼짐. 놀이 시간·부모 확인은 기능 자체 없음 |
| 눈 보호 기준 30cm / 해제 34cm | 있음 | `services/eye_guard.dart` `EyeRules.tooCloseCm 30`, `clearCm 34` |
| 각도 좌우 35° · 위아래 30° · 기울기 45° | 있음 | `maxYaw 35`, `maxPitch 30`, `maxRoll 45` |
| 2~3초 지속 시에만 | 있음 | `closeHold 2s`, `angleHold 3s`, `clearHold 0.9s` |
| 안드로이드 ML Kit / 웹 MediaPipe(앱 내장) | 있음 | `services/eye_sensor_io.dart` (google_mlkit_face_detection + camera), `services/eye_sensor_web.dart` + `web/eye_guard.js` + `web/mediapipe/` (CDN 없음) |
| iOS ML Kit | 코드상 있음, 빌드 미확인 | `eye_sensor_io.dart`가 `Platform.isIOS` 지원 (bgra8888, 회전 처리) |
| 부모님 거리 맞추기(보정) | 있음 | `calibrateNow`, 설정 `_EyeGuardCard` |
| 덮개 "조금 더 멀리서 봐요" | 있음 | `widgets/eye_guard_overlay.dart` |
| 하루 놀이 시간 (제한 없음·10·15·20·30·45·60분), "오늘은 여기까지!", 부모 확인 후 +15분, 다음 날 리셋 | **없음** | |
| 눈 쉬기 10/20분(기본 10) → 20초 "창밖 먼 곳을 봐요", 산 그림 + 줄어드는 고리, 5분 이상 안 보면 쉰 것으로 | **없음** | |

## 8. 저장과 백업

| 사양 | 상태 | 메모 |
|---|---|---|
| 기기 안에만 저장, 버전 번호 + 마이그레이션 | 있음 | `services/save_data.dart` v5, `migrate()` v0→v5, `services/storage_service.dart` (직전 값 백업 키) |
| 없어진 탈것 스티커를 새 탈것으로 옮김 | 부분 | v3→v4 색깔별 탈것 통합은 있음. 자전거·킥보드 → 기차·열기구는 없음 |
| 'ALOK1-' 백업 문자열 복사/붙여 넣기 복구 | **없음** | `SaveData.encode()` 재사용 가능 |

## 9. UI/UX 원칙 1~9

| # | 사양 | 상태 | 메모 |
|---|---|---|---|
| 1 | 목소리 먼저: 모든 문제·칭찬·안내 음성 | 있음 | `services/audio_service.dart`, `voice_lines.dart`, 409 조각 |
| 1 | 물건·탈것·옷 누르면 이름 말하기 | 부분 | 상점은 있음. 홈 메뉴 버튼·놀이 물건·캐릭터 화면 등 '버튼 이름 읽기' 전반은 소실 |
| 1 | 큰 노란 "다시 듣기" 62px, 6초마다 통통 | **부분** | 숫자·색깔 화면 `RoundIconButton(size: 52, yellowSoft)`. 62px 아님, 6초 튀기 없음 |
| 2 | 놀이를 기구 그림으로 고르기, 단계 카드에 문제 그림 | 부분 | 놀이터 없음. 단계 카드 그림은 있음 |
| 3 | 터치 60~72px, 눌리면 작아짐 + 효과음 | 있음(대부분) | `widgets/common.dart` `Pressable` (scale .94), `RoundIconButton` 기본 72. 다시 듣기 52px 예외. `test_preview/touch_audit_test.dart` |
| 4 | 가로 밀기 금지, 자동 칸 크기, 많으면 큰 화살표 쪽 넘김 | **부분** | 가로 스크롤 남은 곳: `shop/item_widgets.dart` ThemeTabs, `screens/stage_picker.dart`, `vehicle/garage_screen.dart`. 화살표 페이저 위젯 없음 |
| 5 | 놀이 중 나가기 = 멈춤 → 집으로 꾹 누르기(~1초 고리) | **부분** | 멈춤 화면 있음, '집으로'는 한 번 탭으로 바로 나감 (`game_frame.dart` `_PauseOverlay`). 설정 '기록 지우기'에만 꾹 누르기 있음 |
| 5 | ✔/✖ 구매 확인, 뒤로가기 = 멈춤 화면 | 있음 | `PopScope` → `_paused = true` |
| 6 | 단계적 도움 | 있음 | 2장 참고 |
| 7 | 노치 대응, 높이 340 미만 전체 축소, 568×320·844×390·1280×800 넘침 없음 | 부분 | `SafeArea`·`FitBox` 개별 축소, 위젯 테스트 6개 크기 통과. '높이 340 미만이면 전체 축소' 전역 처리는 없음 |
| 8 | 공용 20fps 시계, 멈춘 장면 안 그림, 계속 도는 애니메이션 금지 | 있음 | `core/slow_clock.dart` (50ms). 예외: `RotateHint`의 `repeat()` (세로 안내 화면) |
| 9 | 짧은 페이드 전환 | 있음 | `softRoute` 260ms `FadeTransition` |

## 10. 아트·사운드

| 사양 | 상태 | 메모 |
|---|---|---|
| 모든 그림 CustomPainter | 있음 | 이미지 에셋 없음 (`assets/`에 폰트·오디오만) |
| 계절 배경 | 있음 | `scene_game.dart` |
| Jua 글꼴 내장 | 있음 | `assets/fonts/Jua-Regular.ttf` + OFL |
| 녹음 mp3 + 없는 문장만 TTS | 있음 | `assets/voice/` + `flutter_tts` |
| 음악: 홈·상점·계절별 | 있음 | home·shop·계절 4곡 (`assets/audio/music/`, `tool/generate_music.py`) |
| 효과음 7종 직접 합성 | 있음 | `tool/generate_sfx.py`, `assets/audio/sfx/` |

## 11. 빌드·배포·테스트

| 사양 | 상태 | 메모 |
|---|---|---|
| 웹 `--base-href /alokdalok/ --no-web-resources-cdn`, 서비스 워커, MediaPipe 내장 | 있음(스크립트 없음) | `web/mediapipe/` 포함. 빌드 명령은 README에만 |
| 안드로이드 `install_and_build.command`, arm 전용(armeabi-v7a, arm64-v8a) | **없음** | 스크립트 없음. `android/app/build.gradle.kts`에 ABI 필터 없음, release가 debug 키 서명 |
| ML Kit Play 서비스 버전(용량 줄이기) | **없음** | `google_mlkit_face_detection` 번들 모델 사용 중 (Android 매니페스트/gradle에 unbundled 설정 없음) |
| 음성 `gen_voice.command` | 있음 | `tool/voice/gen_voice.command`, `export_lines_test.dart` |
| 테스트 142개 | 부분 | 현재 120개 |

## 12. iOS 준비 상태

| 항목 | 상태 | 메모 |
|---|---|---|
| Info.plist `NSCameraUsageDescription` | 있음 | 한국어 설명 문구 있음 (`ios/Runner/Info.plist`) |
| 가로 고정 | 있음 | `UISupportedInterfaceOrientations`(+~ipad) LandscapeLeft/Right만, `UIRequiresFullScreen = true`, `main.dart`에서 `setPreferredOrientations` |
| 최소 iOS 버전 | 부분 | `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (pbxproj). `Podfile`의 `platform :ios`는 주석. google_mlkit_face_detection 최신은 iOS 15.5+ 요구 가능 → `platform :ios, '15.5'` 이상으로 맞출 것 |
| 눈 보호 센서 | 코드 준비됨 | `eye_sensor_io.dart`는 `google_mlkit_face_detection` + `camera` (Android 전용 API 아님, iOS 분기 있음). 실기기 검증 필요 |
| Podfile | 기본형 | `use_frameworks!`. ML Kit은 arm64 시뮬레이터 미지원 → `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` post_install 설정이 필요할 수 있음 |
| 서명·번들 ID | 미설정 | Team/번들 ID(`com.alokdalok.alokdalok`?) 확인 필요, `pod install` 미실행 (Pods 없음) |
| 표시 이름 | 있음 | `CFBundleDisplayName = 알록달록 놀이터` |
| 노치·홈 인디케이터 | 부분 | `SafeArea` 사용. `immersiveSticky`는 Android용 |

## 13. 기타 정리할 것

- README: "옷 70종", "탈것 킥보드·자전거" 등 오래된 설명 → 사양에 맞게 갱신.
- `screens/bag_screen.dart`(내 가방)와 홈의 '탈것 꾸미기' 타일은 사양 홈 구성(버튼 3개)에 없음 → 내 캐릭터 / 상점 안으로 옮길지 결정.
- `flutter analyze`는 한글 경로에서 크래시 → ASCII 경로 복사본에서 실행 (CLAUDE.md 참고).
