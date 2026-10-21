# 사양 대비 코드 차이 (GAP REPORT)

- 기준 사양: `docs/MASTER_PROMPT.md` (2026-10-21, iOS 정식 포함)
- 기준 코드: `integrate` 브랜치 (2026-10-22, 트랙 A~E 합친 뒤 통합 마무리). 처음 기준선은 2026-10-21 05:04 스냅샷(첫 커밋 `기준선`)
- 기준선 이후 GitHub 웹 빌드에만 있던 기능(놀이터 화면, 모양·크기·짝 놀이, 부모 확인, 놀이 시간·눈 쉬기, ALOK1- 백업, 버튼 이름 읽기, 기차·열기구 + 저장 옮기기, 탈것 방향, 꾹 눌러 나가기)은 트랙 A~D에서 모두 다시 만들었다.
- 표기: **있음** / **부분** / **없음**

## 검증 결과

| 항목 | 결과 |
|---|---|
| `flutter pub get` | 성공 (13개 패키지 상위 버전 있음, 제약상 미적용) |
| `flutter analyze` | 한글 경로에서 분석 서버 크래시(JSON FormatException). ASCII 경로 복사본에서 **No issues found** |
| 통합 마무리 (2026-10-22) | `flutter test` **323개 전부 통과**, `flutter analyze` **0건** (이 경로는 ASCII라 바로 실행), `flutter test test_preview --update-goldens` **131개 통과** (568×320·844×390·1280×800 주요 화면 그림 확인). 빌드 3종은 11장 참고 |
| 기준선 `flutter test` (test/) | **120개 전부 통과** (소스상 `test`/`testWidgets` 72곳: state 33·widget 19·logic 14·eye_guard 6, 화면 크기 반복 포함 실행 120건). 사양 목표 142 |
| 기준선 `flutter test test_preview` | 그대로 돌리면 9 통과 / 32 실패 (골든 비교: `shots/` 없음 + 저장된 PNG 픽셀 차이). 미리보기 생성기이므로 `--update-goldens`로 돌리면 **41개 전부 통과** |

## 1. 화면 구성과 흐름

| 사양 | 상태 | 현재 코드 / 메모 |
|---|---|---|
| 첫 실행: 친구 고르기 → 이름 짓기 → 이후 홈 | 있음 | `lib/app.dart` RootGate, `screens/zodiac_picker_screen.dart`, `screens/nickname_screen.dart` |
| 홈: 큰 버튼 3개(놀이터 가기·내 캐릭터·꾸미기 상점)만 | 있음 (트랙 A) | `screens/home_screen.dart`. 누르면 이름을 말함. 내 가방(`bag_screen.dart`)은 홈에서 빠짐(내 캐릭터 화면이 같은 일을 함), 탈것 꾸미기는 내 캐릭터 → 탈것 탭에서 |
| 홈 구석 작은 톱니바퀴 → 부모 확인 → 설정 | 있음 | 톱니바퀴(60px) → `confirmParent(context)`(트랙 C `widgets/parental_gate.dart`) 통과하면 설정 (`HomeScreen._openSettings`) |
| 놀이터 화면 (기구 그림 5개, 이름표, 깬 단계만큼 별, 내 캐릭터 서 있음) | 있음 (트랙 A) | `screens/playground_screen.dart` + `playground_art.dart`(CustomPainter). 기구를 누르면 "미끄럼틀! 숫자 놀이를 해 볼까요?" → 단계 고르기 → 놀이 |
| 단계 고르기: 카드에 문제 그림 + 계절 아이콘, 아래 골인 길 | 있음 | `screens/stage_picker.dart`: `PagedGrid`(화살표 쪽 넘기기), 잠긴 카드 흔들림(`ShakeOnChange`) + 음성. 카드 그림은 `StageArtBox`가 카드 크기에 맞춰 줄이고 키운다(1280 화면에서도 크게), 계절 아이콘은 카드 머리줄 오른쪽. 그림·놀이 연결은 `games/game_entry.dart`(`stageArt`, `openGame`) |
| 놀이 화면: 위 멈춤·발자국·코인 / 가운데 문제 카드 / 아래 길·말풍선 | 있음 | `games/common/game_frame.dart` |
| 내 캐릭터: 옷 입기, 탈것 타기, 친구 바꾸기 | 있음 | `screens/character_screen.dart`. 옷 칸도 `PagedGrid`(밀기 없음). `screens/bag_screen.dart`는 홈에서 빠져 들어갈 길이 없음 — 지울지는 사용자 결정(13장) |
| 설정: 눈 보호·놀이 시간·눈 쉬기 간격·소리·백업 | 있음 | `screens/settings_screen.dart`: 눈 보호(켜기·경고 거리 25/30/35/40cm·30cm 보정), 하루 놀이 시간, 눈 쉬기 간격, 소리, 부모 확인 켜기/끄기, 백업, 닉네임, 기록 지우기, 라이선스 |

## 2. 놀이 5종

공통 규칙: 단계 5개(숫자 8개), 한 판 5문제(`Economy.questionsPerSession = 5` 있음), 목소리 문제 + "다시 듣기".

| 놀이 | 상태 | 현재 코드 / 메모 |
|---|---|---|
| 숫자 놀이 (미끄럼틀), 8단계 | 있음 | `games/number_game/`, `data/stages.dart` `Stages.number` 8단계, 4단계부터 섞인 물건 중 한 가지만 세기 (`NumberMode`) |
| └ 보기에 숫자 + 주사위 모양 발자국 | 있음 | `number_game_screen.dart` `_Choice` + `games/common/number_shape.dart` |
| └ 정답·오답 모두 "하나, 둘…" 세기 + 도장 "쾅" + 보기 자리에 큰 숫자, 물건 가리지 않음 | 있음 | `_startCountingHint`, `games/common/stamp.dart`, `Sfx.stamp` |
| └ 원색, 단계마다 다양, 많으면 줄 맞춤 | 있음 | `objectRows()` 줄 맞춤, 단계별 색 목록 |
| 색깔 놀이 (그네), 5단계 | 있음 | `games/color_game/`, `Stages.color` 5단계 (`swatchFromStart`, `mixedShapes`) |
| 모양 놀이 (모래놀이터) | 있음 (트랙 B) | `games/shape_game/` (`shape_round.dart` 순수 로직, `shape_art.dart` 그림), `Stages.shape` 5단계: 쉬운 세 모양+견본 → 여섯 모양 → 같은 색 → 회전 → 견본과 같은 모양 |
| 크기 놀이 (시소) | 있음 (트랙 B) | `games/size_game/`, `Stages.size` 5단계: 보기 2→2→3→3→4, 3개 이상은 "가장 큰/작은", 이웃 크기 비율 2.2→1.2로 감소 |
| 짝 맞추기 (회전목마) | 있음 (트랙 B) | `games/match_game/`, `Stages.match` 2→3→4→5→6쌍, 카드 모두 보임, 5단계는 같은 물건 다른 색. 한 문제 = 카드 한 판 |
| 공통 흐름: 정답→효과음·칭찬·코인→다음, 결과(별·코인, 또 하기/다음 단계/집으로) | 있음 | `game_frame.dart` 결과 화면 |
| 단계마다 계절 배경·음악 | 있음 | `scene_game.dart` `seasonForStage`, 계절 음악 4곡 |
| 1번 틀림 그림 힌트, 2번 틀림 정답 빛남, 틀린 보기 흐려짐 | 있음 | 숫자(`wrongPicks`, `glow`, opacity .35), 색깔(`faded`, `glow`) |
| `GameKind` 확장 | 있음 (트랙 B) | `enum GameKind { number, color, shape, size, match }` + `title`·`stageCount`. 진입: `games/game_entry.dart` `gameScreen(kind, stageId)`·`openGame(context, kind, stageId)`·`stageArt(kind, stageId)`. `SaveData`에 `shape/size/matchStageUnlocked·Cleared` 추가(버전 5 유지, 없으면 1단계부터) |

## 3. 캐릭터 (24마리)

| 사양 | 상태 | 메모 |
|---|---|---|
| 12지신 + 공룡 12종 | 있음 | `character/zodiac.dart` (`FriendGroup.zodiac/dino`), `animal_painter.dart` |
| 같은 2등신 몸매, 옷 공유 | 있음 | |
| 이름 짓기: 예시 없음, 비우면 랜덤, 동물 실명 | 있음(확인 권장) | `character/nickname.dart`, `nickname_screen.dart` |
| 친구 12마리 화살표 쪽 넘기기 | 있음 (트랙 A) | 12지신/공룡 탭 + `PagedGrid` (칸이 64px보다 작아지면 화살표로 넘김) |

## 4. 옷 꾸미기 / 상점

| 사양 | 상태 | 메모 |
|---|---|---|
| 테마 17개 | 있음 | `data/item_catalog.dart` `OutfitTheme` 17개 |
| 자리 5곳 (머리·옷·신발·장식·등) | 있음 | `ItemSlot` |
| 아이템 71개, 10~45코인 | 있음 | 71개, 가격 10~45 (README도 71로 고침) |
| 눌러서 바로 입어 보기, 이름 말하기 | 있음 | `shop/shop_screen.dart` `say(item.name)` |
| ✔/✖ 구매 확인 | 있음 | `shop/item_widgets.dart` |
| 코인 부족: "놀이하면서 코인을 모아요" + 진행 막대, 결제 화면 없음 | 있음 | `shop_screen.dart` ~433행 |
| 테마 17개 큰 화살표 쪽 넘기기 (가로 밀기 금지) | 있음 | `ThemeTabs` → `widgets/paged_grid.dart`. 테마 안의 옷 칸도 `PagedGrid`(예전 세로 `GridView` 대신) |

## 5. 탈것 7종

| 사양 | 상태 | 메모 |
|---|---|---|
| 열기구 20 · 기차 25 · 자동차 40 · 오토바이 40 · 탱크 50 · 비행기 50 · 우주선 50 | 있음 | `data/vehicles.dart` 7종. 기차·열기구는 `vehicle/vehicle_painter.dart`에 새로 그림 (다리는 기관실·바구니 안, 스티커 자리 넓음) |
| 자전거·킥보드 → 기차·열기구 저장 마이그레이션 (스티커·색 옮김) | 있음 | `SaveData.migrate` 끝에서 버전과 상관없이 `Vehicles.retired`에 있는 id를 옮김 (가진 탈것·타는 탈것·스티커·칠한 색·산 색). 여러 번 돌려도 같음. 버전 번호는 그대로 |
| 고르고 "탑승!" 눌러야 탄다 | 있음 | 내 친구·상점·꾸미기 모두 고르기(이름 말하기) → "탑승!". 사도 바로 타지 않음 (`buyVehicle`) |
| 타면 캐릭터가 옆을 보며 앉음 (방향) | 있음 | `character/rider_pose.dart` 공통 변환(얼굴 돌리기 `AnimalPainter.sideways` + 앉은 팔다리). 24마리 × 7종 |
| 스티커 10종 × 6색, 고르고→누르기, 지우개, 드래그 없음 | 있음 | `StickerKind` 10, `stickerColors` 6, `vehicle/garage_screen.dart` (최대 12장) |
| 색칠: 탈것마다 따로, 한 색 10코인, 처음 색 공짜 | 있음 | `Vehicles.paintPrice = 10`, `paintKey('paint@vehicle')`, `canPaint`. 코인이 모자라면 꾸미기 화면에 "놀이하면서 코인을 모아요" + 진행 막대 |
| 가로 스크롤 금지 | 있음 | 꾸미기·내 친구·상점 탈것 칸 모두 공용 `PagedGrid` (예전 `vehicle/fit_grid.dart`는 합치면서 없앰) |

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
| 부모 확인: 덧셈(각 6~9) 숫자 패드, 설정 진입·놀이 시간 연장 시 | 있음 | `widgets/parental_gate.dart` `confirmParent(context)` (틀리면 새 문제, 닫으면 false). 놀이 시간 연장은 덮개 안에서 바로 연결. 설정 진입 연결은 트랙 A |
| 눈 보호·놀이 시간·부모 확인 **기본 켜짐** | 있음 | 저장 v6: `eyeGuardOn`·`parentGateOn` 기본 true, `playLimitMin` 기본 10. v5→v6에서 눈 보호를 켬 |
| 눈 보호 기준 30cm / 해제 34cm | 있음 | `services/eye_guard.dart` `EyeRules.tooCloseCm 30`, `clearCm 34` |
| 각도 좌우 35° · 위아래 30° · 기울기 45° | 있음 | `maxYaw 35`, `maxPitch 30`, `maxRoll 45` |
| 2~3초 지속 시에만 | 있음 | `closeHold 2s`, `angleHold 3s`, `clearHold 0.9s` |
| 안드로이드 ML Kit / 웹 MediaPipe(앱 내장) | 있음 | `services/eye_sensor_io.dart` (google_mlkit_face_detection + camera), `services/eye_sensor_web.dart` + `web/eye_guard.js` + `web/mediapipe/` (CDN 없음) |
| iOS ML Kit | 빌드됨, 카메라는 실기기 확인 필요 | `eye_sensor_io.dart`가 `Platform.isIOS` 지원 (bgra8888, 회전 처리) |
| 부모님 거리 맞추기(보정) | 있음 | `calibrateNow` + 경고 거리 선택(`EyeGuard.tooCloseCm`, 풀림 = +4cm), 설정 `_EyeGuardCard` |
| 덮개 "조금 더 멀리서 봐요" | 있음 | `widgets/eye_guard_overlay.dart` |
| 하루 놀이 시간 (제한 없음·10·15·20·30·45·60분), "오늘은 여기까지!", 부모 확인 후 +15분, 다음 날 리셋 | 있음 | 순수 로직 `services/play_clock.dart` `PlayClock`(시계 주입), 덮개 `widgets/play_guard_overlay.dart`(`app.dart`에서 전체 화면 위). 논 시간은 저장(30초마다·백그라운드 갈 때) |
| 눈 쉬기 10/20분(기본 10) → 20초 "창밖 먼 곳을 봐요", 산 그림 + 줄어드는 고리, 5분 이상 안 보면 쉰 것으로 | 있음 | `PlayClock` + `EyeBreakCard`(`WindowViewPainter`, `ShrinkingRingPainter`, 공용 20fps 시계). 백그라운드 5분 이상이면 쉰 것. "오늘은 여기까지"가 20초 넘게 떠 있어도 쉰 것 |

## 8. 저장과 백업

| 사양 | 상태 | 메모 |
|---|---|---|
| 기기 안에만 저장, 버전 번호 + 마이그레이션 | 있음 | `services/save_data.dart` **v6**. `migrate()` = 버전 단계 목록 `SaveData.steps`(n→n+1) + 매번 도는 멱등 정리 단계 `SaveData.repairs`(트랙 D 탈것 정리 자리). `services/storage_service.dart` (직전 값 백업 키) |
| 없어진 탈것 스티커를 새 탈것으로 옮김 | 있음 | v3→v4 색깔별 탈것 통합 + `SaveData.repairs`의 자전거·킥보드 → 기차·열기구 (5장) |
| 'ALOK1-' 백업 문자열 복사/붙여 넣기 복구 | 있음 | `services/backup_code.dart`: `ALOK1-<base64url JSON>-<FNV-1a 체크섬>`, 버전 검사(새 버전 거절·예전 버전 마이그레이션), 띄어쓰기 무시, 잘못된 글자는 이유와 함께 거절. 카메라 보정·오늘 논 시간은 빼고 백업 |

## 9. UI/UX 원칙 1~9

| # | 사양 | 상태 | 메모 |
|---|---|---|---|
| 1 | 목소리 먼저: 모든 문제·칭찬·안내 음성 | 있음 | `services/audio_service.dart`, `voice_lines.dart`, 녹음 조각 576개(문장 목록 574 전부 녹음됨, 2026-10-22 135개 추가) |
| 1 | 물건·탈것·옷 누르면 이름 말하기 | 있음 | `Pressable(speak:)` / `RoundIconButton(speakLabel:)`: 홈 버튼·놀이터 기구·옷·탈것. 놀이 화면은 `SayName`(widgets/common.dart): 숫자 놀이 세는 물건("사과!", 섞인 물건은 "빨간 사과!"), 모양·크기·짝 견본 그림, 색깔 견본. 보기 칸에는 붙이지 않아 답 고르기와 겹치지 않고, 같이 세는 중에는 말하지 않는다 |
| 1 | 큰 노란 "다시 듣기" 62px, 6초마다 통통 | 있음 | 공용 위젯 `widgets/listen_again_button.dart`(공용 20fps 시계, 튈 때만 구독). 모양·크기·짝의 `ReplayButton`(`games/common/quiz_widgets.dart`)과 숫자·색깔 화면 모두 이 위젯 하나를 쓴다 |
| 2 | 놀이를 기구 그림으로 고르기, 단계 카드에 문제 그림 | 있음 | 놀이터 기구(트랙 A), 단계 카드 그림 |
| 3 | 터치 60~72px, 눌리면 작아짐 + 효과음 | 있음 | `widgets/common.dart` `Pressable` (scale .94), `RoundIconButton` 기본 72. `test_preview/touch_audit_test.dart`(홈·단계·숫자·색깔·꾸미기·상점·내 캐릭터·설정 모두 60px 이상), `test/screens_test.dart` 화면 크기별 검사. 물건 이름 듣기(`SayName`)는 버튼이 아닌 덤이라 물건 크기 그대로(섞인 숫자 단계에서는 작다) |
| 4 | 가로 밀기 금지, 자동 칸 크기, 많으면 큰 화살표 쪽 넘김 | 있음 | `widgets/paged_grid.dart`: 상점 테마·옷 칸, 내 캐릭터 옷 칸, 단계 고르기, 친구 고르기, 탈것 칸. lib 전체에 가로 스크롤 없음(`test/polish_test.dart`가 소스를 검사). 세로 스크롤은 부모님용 설정·이름 입력(키보드)과 안 쓰는 `bag_screen.dart`에만 |
| 5 | 놀이 중 나가기 = 멈춤 → 집으로 꾹 누르기(~1초 고리) | 있음 (트랙 A) | `widgets/hold_button.dart` `HoldToConfirm`, `game_frame.dart` `_PauseOverlay` |
| 5 | ✔/✖ 구매 확인, 뒤로가기 = 멈춤 화면 | 있음 | `PopScope` → `_paused = true` |
| 6 | 단계적 도움 | 있음 | 2장 참고 |
| 7 | 노치 대응, 높이 340 미만 전체 축소, 568×320·844×390·1280×800 넘침 없음 | 있음 | `widgets/screen_fit.dart` `MinHeightScaler`를 `app.dart` builder에 적용 (안전 영역 여백도 같은 비율) |
| 8 | 공용 20fps 시계, 멈춘 장면 안 그림, 계속 도는 애니메이션 금지 | 있음 | `core/slow_clock.dart` (50ms, 듣는 위젯이 없으면 멈춤). lib에 `repeat()` 없음(`RotateHint`도 공용 시계로 세 번만 눕히고 멈춤). 남은 60fps는 누를 때 한 번 도는 짧은 반응뿐: 폴짝(0.7~0.9초), 도장(0.5초), 꾹 누르기 고리, 정답 반짝이(`SceneGame._boostFrames` 약 1.6초) |
| 9 | 짧은 페이드 전환 | 있음 | `softRoute` 260ms `FadeTransition` + 테마 `fadePageTransitions` (MaterialPageRoute도 페이드), 첫 실행 → 홈도 `RootGate` 260ms 페이드, 덮개는 250ms 페이드. 번쩍임·빠른 깜빡임 없음(캐릭터 눈 깜빡임만 3.2초마다 한 번) |

## 10. 아트·사운드

| 사양 | 상태 | 메모 |
|---|---|---|
| 모든 그림 CustomPainter | 있음 | 이미지 에셋 없음 (`assets/`에 폰트·오디오만) |
| 계절 배경 | 있음 | `scene_game.dart` |
| Jua 글꼴 내장 | 있음 | `assets/fonts/Jua-Regular.ttf` + OFL |
| 녹음 mp3 + 없는 문장만 TTS | 있음 | `assets/voice/` (576개, 약 4.5MB) + `flutter_tts`. 아이 이름 등 목록 밖 문장만 TTS |
| 음악: 홈·상점·계절별 | 있음 | home·shop·계절 4곡 (`assets/audio/music/`, `tool/generate_music.py`) |
| 효과음 7종 직접 합성 | 있음 | `tool/generate_sfx.py`, `assets/audio/sfx/` |

## 11. 빌드·배포·테스트

| 사양 | 상태 | 메모 |
|---|---|---|
| 웹 `--base-href /alokdalok/ --no-web-resources-cdn`, 서비스 워커, MediaPipe 내장 | 있음 | `tool/build_web.sh`. Flutter 기본 SW는 자기 등록을 지우는 껍데기라 `web/offline_sw.js`(+`web/flutter_bootstrap.js`)로 교체, 파일 489개·47.6MB 미리 담음. 헤드리스 Chrome에서 서버를 끈 뒤 열리는 것 확인. 2026-10-22 다시 빌드 성공 (파일 624개, 48.5MB) |
| 안드로이드 `install_and_build.command`, arm 전용(armeabi-v7a, arm64-v8a) | 있음 | 저장소 루트 스크립트(caffeinate). `abiFilters` + `disable-abi-filtering=true`. release 키는 `android/key.properties`(git 제외) + 비밀번호 직접 입력, 없으면 debug 키 |
| ML Kit Play 서비스 버전(용량 줄이기) | 있음 | `com.google.mlkit:face-detection` 제외 → `play-services-mlkit-face-detection:17.1.0`, 매니페스트 `com.google.mlkit.vision.DEPENDENCIES=face`. APK 89.6MB → 42.0MB. 2026-10-22 arm 전용 release APK(debug 키 서명) **43.3MB** 빌드 성공 (armeabi-v7a, arm64-v8a) |
| 음성 `gen_voice.command` | 있음 | `tool/gen_voice.command` (목록 내보내기 → 없는 문장만 `assets/voice`에 녹음, manifest 합치기). 2026-10-22 `~/alokdev/melo-venv`로 135문장 녹음(69초) |
| 테스트 142개 | 있음 | 323개 (트랙 A `screens_test`, B `games_*_test`, C `safety_*_test`, D `vehicle_test`, 통합 `polish_test` 18개 등) |

## 12. iOS 준비 상태

| 항목 | 상태 | 메모 |
|---|---|---|
| Info.plist `NSCameraUsageDescription` | 있음 | 한국어 설명 문구 있음 (`ios/Runner/Info.plist`) |
| 가로 고정 | 있음 | `UISupportedInterfaceOrientations`(+~ipad) LandscapeLeft/Right만, `UIRequiresFullScreen = true`, `main.dart`에서 `setPreferredOrientations` |
| 최소 iOS 버전 | 있음 | `platform :ios, '15.5'`, pbxproj·모든 Pod 15.5 (ML Kit 요구) |
| 눈 보호 센서 | 코드 준비됨 | `eye_sensor_io.dart`는 `google_mlkit_face_detection` + `camera` (Android 전용 API 아님, iOS 분기 있음). 실기기 검증 필요 |
| Podfile | 있음 | iOS 27 시뮬레이터는 x86_64를 못 돌려서 arm64 제외 대신 `tool/ios/mlkit_sim_slices.py`로 arm64 시뮬레이터 사본(`Pods/MLKitSim`)을 만들어 시뮬레이터 빌드에서만 사용. `flutter build ios --simulator` 성공, iPhone 17e(iOS 27) 실행 확인. 2026-10-22 다시 빌드·설치: 친구 고르기 → 이름 짓기(비워 두고 좋아요) → 홈까지 확인 |
| 서명·번들 ID | 사용자 몫 | 번들 ID `com.alokdalok.alokdalok`. Team(Apple 개발자 계정)·서명은 Xcode에서 사용자가 설정. `Podfile.lock` 커밋 |
| 표시 이름 | 있음 | `CFBundleDisplayName = 알록달록 놀이터` |
| 노치·홈 인디케이터 | 있음 | `SafeArea` 사용, Info.plist `UIStatusBarHidden`, `UIRequiresFullScreen` |

## 13. 남은 차이와 사용자 결정

- **`screens/bag_screen.dart`(내 가방)**: 홈 버튼 3개 사양에 맞춰 홈에서 빠졌고 들어갈 길이 없다. 내 캐릭터 화면이 같은 일을 한다. 지울지는 사용자 결정 (지금은 그대로 둠).
- **사양 '남은 일' 중 사용자 결정 대기**: 캐릭터 완전 옆모습 여부, 오토바이 다리 보임 여부, 연령 확장 계획, iOS 출시(서명·Team은 사용자 몫).
- **실기기 확인 필요**: iOS·안드로이드 눈 보호(ML Kit) 카메라 동작은 시뮬레이터·테스트로만 확인.
- 사양의 웹 빌드 명령(`flutter build web ...`)은 그대로 쓰면 오프라인 목록이 빠져서 `tool/build_web.sh`로 대신한다 (같은 옵션 + 서비스 워커 목록).
- `flutter analyze`는 한글 경로(`~/Documents/알록달록`)에서만 크래시 → ASCII 경로에서 실행 (CLAUDE.md 참고).
