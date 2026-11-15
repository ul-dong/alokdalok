# Google Play 출시 메모 (Android)

알록달록 꼬마 놀이터(영어 이름 Balloon Playground, `io.github.uldong.alokdalok`)를 Google Play에 올리는 데 필요한 내용을 모았다.
작성일은 2026-11-15이고, 기준은 Flutter 3.47.x와 `source` 브랜치다. iOS와 웹은 다루지 않는다.

---

## 0. 일정 리스크: 비공개 테스트를 가장 먼저 시작한다

- 개인 개발자 계정을 **2023-11-13 이후에 만들었다면** 프로덕션 접근을 바로 신청할 수 없다.
  먼저 **비공개 테스트를 해야 하고, 테스터 12명 이상이 14일 연속으로 참여**해야 한다.
  조직 계정은 이 조건이 없다.
- 이 단계가 출시 일정에서 가장 오래 걸린다. 테스터를 모으고 14일을 기다린 뒤 프로덕션 신청 심사까지 받아야 한다.
  그래서 **코드 작업이 끝나기를 기다리지 말고 병행해서 먼저 시작한다.**
  1. 개발자 계정을 만들고 본인 인증을 마친다. 개인 계정인지 조직 계정인지 확인한다.
  2. 업로드 키를 만든다(아래 1절). 첫 AAB를 **비공개 테스트** 트랙에 올린다.
  3. 테스터 12명 이상을 이메일 목록이나 Google 그룹으로 초대한다. 14일 동안 설치한 상태를 유지하고 가끔 실행해 달라고 부탁한다.
     중간에 빠지는 사람이 있을 수 있으니 15~20명을 모으는 편이 안전하다.
  4. 14일이 지나면 Play Console에서 프로덕션 접근을 신청한다(테스트 내용에 관한 설문이 있다).
- 비공개 테스트 기간은 실기기 점검 기간으로도 쓴다(3절의 "사용자 확인 필요" 항목).

## 1. AAB 빌드와 서명

```bash
tool/build_android.sh                  # 출시용 AAB: build/alokdalok.aab
tool/build_android.sh --build-number=2 # 업데이트할 때마다 versionCode를 올린다 (pubspec.yaml의 +N도 가능)
tool/build_android.sh --debug-signed   # 점검용 (debug 키로 서명): build/alokdalok-DEBUG-SIGNED.aab, Play에 올릴 수 없음
```

- Play에는 APK를 올릴 수 없어서 AAB를 만든다. 기존 `install_and_build.command`는 직접 설치용 APK(arm 전용)를 만드는 스크립트이고 그대로 둔다.
- 서명 방식은 `install_and_build.command`와 같다. `android/key.properties`(git 제외)에 `storeFile=`와 `keyAlias=`만 적는다.
  비밀번호는 환경 변수 `ALOK_STORE_PASSWORD`로 넘기고, 키 비밀번호가 다르면 `ALOK_KEY_PASSWORD`도 넘긴다.
  환경 변수가 없으면 스크립트가 화면에 보이지 않게 물어본다. 비밀번호는 어떤 파일에도 적지 않는다.
- `key.properties`가 없으면 스크립트는 그 사실을 알리고 멈춘다. 빌드가 끝나면 서명자를 출력하고, release 빌드인데 debug 키로 서명되었으면 실패로 끝난다.
- **Play 앱 서명**을 쓴다(새 앱의 기본값). 지금 만드는 키는 *업로드 키*이고, 실제 배포 서명 키는 Google이 보관한다.
  업로드 키를 잃어버려도 Play Console에서 재설정을 요청할 수 있다. 그래도 `.jks` 파일과 비밀번호는 저장소 밖에 따로 백업한다.
- 업로드 키는 아직 없다. 처음 한 번 `install_and_build.command`를 실행해 6단계에서 `y`를 고르면
  `~/alokdev/keys/alokdalok-release.jks`와 `android/key.properties`가 만들어진다.
  `keytool -genkeypair ... -validity 10000`을 직접 실행해도 된다.

## 2. SDK 수준 (`android/app/build.gradle.kts`)

| 값 | 설정 | 이유 |
|---|---|---|
| compileSdk | 36 | 고정값. 전에는 `flutter.compileSdkVersion`에 맡겨서 Flutter 버전이 바뀌면 같이 바뀌었다 |
| targetSdk | **36** | 2026-08-31부터 신규 앱과 업데이트는 API 36 이상이어야 Play에 제출할 수 있다 |
| minSdk | 24 (Android 7.0) | Flutter 3.47 기본값과 같다. camera(CameraX)와 ML Kit 요구 수준도 충족한다 |

`test/release_test.dart`가 이 값이 다시 `flutter.*`로 돌아가지 않았는지 확인한다.

## 3. targetSdk 36 동작 변경 점검

| 변경 | 이 앱에서 확인한 것 | 결과 |
|---|---|---|
| **edge-to-edge 강제** (Android 15부터. targetSdk 36에서는 `windowOptOutEdgeToEdgeEnforcement`로 끌 수 없음) | `styles.xml`에서 이 속성을 쓰지 않는다. 앱은 `SystemUiMode.immersiveSticky`로 시스템 바를 숨긴다. 모든 화면이 `LandscapePage`, `GameFrame`, 덮개의 `SafeArea` 안에 그려지고 배경만 가장자리까지 깔린다. 높이 340 미만 축소(`MinHeightScaler`)도 padding을 같은 비율로 나눠서 넘긴다 | 문제없음. `test_preview/insets_preview_test.dart`로 노치 44px(왼쪽)와 제스처 바 24px(아래)을 넣어 844×390과 568×320에서 홈·숫자 놀이·상점을 그렸다. 넘침이 없고 버튼이 여백 안쪽에 있다 (`test_preview/shots/insets_*.png`) |
| **화면 잘림(cutout)** 모드가 기본 ALWAYS | 가로로 들면 노치가 왼쪽이나 오른쪽에 온다. 이 inset은 `MediaQuery.padding`으로 들어온다 | 위와 같다. 노치 쪽은 배경 그림만 보인다 |
| **큰 화면(sw600dp 이상)에서 방향·크기 고정 무시** (Android 16, targetSdk 36) | `screenOrientation="sensorLandscape"`가 태블릿과 펼친 폴더블에서 무시되면 세로 창이 될 수 있다 | ① 매니페스트에 `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY=true`를 넣었다. targetSdk 36인 동안은 이 속성으로 가로 고정이 유지된다. **Android 17(targetSdk 37)부터는 이 속성이 무시되므로 그때 다시 대응해야 한다.** ② 그래도 세로 창이 되면 `app.dart`가 "화면을 옆으로 돌려 주세요" 안내(`RotateHint`)를 띄운다. 이 안내가 Material 밖에 그려져 노란 밑줄과 기본 글꼴로 나오던 문제를 고쳤다 (`test/release_test.dart`, `shots/insets_tablet_portrait.png`). ③ `configChanges`에 orientation과 screenSize가 들어 있어서 창 모양이 바뀌어도 액티비티를 다시 만들지 않는다 |
| **뒤로 가기 예측(predictive back)** 기본 켜짐 | 홈은 `PopScope(canPop: false)`이고 놀이 화면은 `GameFrame`의 `PopScope`로 멈춤 화면을 연다. Flutter가 `OnBackInvokedCallback`을 처리한다 | 코드상 문제없음. 실기기 확인 필요 |
| **16KB 페이지 크기** (Android 15 이상 대상 앱은 Play 필수) | AAB 안의 모든 `.so` LOAD 세그먼트 정렬을 확인했다 | 모든 `.so`가 16KB 이상이다 (libflutter와 libapp은 64KB, CameraX와 datastore는 16KB). `extractNativeLibs=false` |
| 브로드캐스트·배터리 | `MainActivity`가 API 33 이상에서 `RECEIVER_NOT_EXPORTED`로 등록한다 | 문제없음 |

**사용자 확인 필요 (실기기):** 지금 연결된 기기와 에뮬레이터 이미지가 없어서 실기기 확인은 하지 못했다. 비공개 테스트 동안 아래를 확인한다.
- Android 15 이상 노치 휴대폰을 좌우로 돌려 가며 홈, 놀이, 상점의 버튼이 노치나 둥근 모서리에 가리지 않는지 본다.
  아래에서 밀어 시스템 바를 잠깐 꺼냈을 때 화면이 크게 튀지 않는지도 본다.
- Android 16 태블릿이나 폴더블에서 가로로 고정되는지 본다. 세로로 들었을 때 가로 화면이 유지되는지, 아니면 돌려 달라는 안내가 나오는지 확인한다.
- 뒤로 가기 제스처를 홈에서 쓰면 앱이 꺼지지 않고, 놀이 중에 쓰면 멈춤 화면이 열리는지 본다.
- 눈 지킴이가 켜지고 얼굴을 찾는지 본다. 인터넷 권한을 뺐기 때문에(5절) 가장 중요한 확인이다.
  `adb logcat | grep -i -E "mlkit|vision|datatransport"`에 오류가 반복되지 않는지도 본다.

## 4. ABI: x86_64를 넣는다 (크롬북)

2026-11-15에 같은 소스로 release AAB를 두 번 빌드해 쟀다. bundletool이 없어서 `unzip -v`의 압축 크기를 합쳐 추정했다.

| | arm 전용 (v7a, arm64) | **arm + x86_64** | 차이 |
|---|---|---|---|
| AAB 파일 (업로드) | 80.6 MB | 99.2 MB | +18.6 MB |
| ├ 공통(에셋·dex·리소스) | 41.7 MB | 41.7 MB | 0 |
| ├ `lib/x86_64` | – | 8.7 MB | +8.7 MB |
| └ 디버그 기호(BUNDLE-METADATA, 기기로 안 감) | 21.6 MB | 31.6 MB | +10.0 MB |
| **arm64 기기 다운로드 (추정)** | 50.2 MB | 50.2 MB | **0** |
| armeabi-v7a 기기 다운로드 (추정) | 49.8 MB | 49.8 MB | 0 |
| x86_64 기기(크롬북) 다운로드 (추정) | 설치 불가 또는 번역 실행 | 50.4 MB | – |

공통 부분 41.7MB의 대부분은 녹음 음성이다(한국어 17.7MB, 영어 19.7MB).

**결정: x86_64를 포함한다.**
- AAB를 올리면 Play가 기기 ABI별로 분할 APK를 만든다. 휴대폰과 태블릿(arm)은 자기 ABI 조각만 받으므로 **다운로드 크기가 늘지 않는다.**
  늘어나는 것은 업로드 파일 크기뿐이다.
- 크롬북 대부분(Intel/AMD)은 x86_64다. arm 전용 앱은 Play에서 빠지거나 ARM 번역으로 느리게 돌 수 있다.
  ARM 번역에서는 Flutter와 카메라·ML Kit 조합이 불안정할 수도 있다. 화면이 큰 기기에서 노는 유아 앱이라 크롬북 사용자를 빼지 않는다.
- 업로드 크기 99MB는 Play의 기본 모듈 한도보다 훨씬 작다.
- 직접 설치용 APK(`install_and_build.command`)는 `--target-platform`으로 계속 arm만 만든다.
- 설정 위치: `build.gradle.kts`의 `abiFilters`(`gradle.properties`의 `disable-abi-filtering=true`와 함께), 그리고 `tool/build_android.sh`의 `--target-platform android-arm,android-arm64,android-x64`.

## 5. 병합된 매니페스트의 권한 (release AAB에서 직접 확인)

`build/app/outputs/logs/manifest-merger-release-report.txt`와 AAB 안의 `base/manifest/AndroidManifest.xml`을 확인했다.

| 권한 / 기능 | 어디서 왔나 | 조치 | 최종 AAB |
|---|---|---|---|
| `CAMERA` | 앱(눈 지킴이), camera 플러그인 | 유지 | **있음** |
| `INTERNET` | `com.google.android.datatransport:transport-backend-cct`. ML Kit이 사용 통계를 보내는 통로다 | **제거** (`tools:node="remove"`) | 없음 |
| `ACCESS_NETWORK_STATE` | media3(audioplayers), datatransport | 유지 (네트워크 상태만 읽는 일반 권한이다. 인터넷 없이는 아무것도 보내지 못한다) | 있음 |
| `RECORD_AUDIO` | camera_android_camerax (동영상 녹화용) | **제거**. 앱은 `enableAudio: false`로 이미지 스트림만 쓴다 | 없음 |
| `WRITE_EXTERNAL_STORAGE`(≤28), `READ_EXTERNAL_STORAGE` | camera_android_camerax (사진·동영상 저장용) | **제거**. 사진과 동영상을 저장하지 않는다 | 없음 |
| `com.google.android.gms.permission.AD_ID` | **현재 의존성에는 없다** | 의존성이 바뀌어도 들어오지 않게 미리 제거 규칙을 넣었다 | 없음 |
| `uses-feature camera.any` | camera_android_camerax가 required=true로 넣는다 | **required=false**로 바꿨다. 카메라 없는 기기도 설치할 수 있다. 그런 기기에서는 눈 지킴이가 "앞카메라가 없어요"를 보여 준다 | required=false |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | androidx.core (앱 자신의 signature 권한) | 유지 | 있음 |

- debug와 profile 빌드는 `src/debug|profile/AndroidManifest.xml`의 INTERNET을 그대로 갖는다. Flutter 개발 도구가 이 권한을 쓴다.
  release에서만 빠진다는 것을 `processDebugManifest`로 확인했다.
- **INTERNET을 빼도 되는 근거**
  - 얼굴 인식은 Play 서비스판 ML Kit이고 기기 안에서 돈다.
  - 모델은 Google Play 서비스가 자기 권한으로 내려받는다. 매니페스트의 `com.google.mlkit.vision.DEPENDENCIES=face`가 설치할 때 내려받기를 요청한다.
  - 앱 코드에는 네트워크를 쓰는 곳이 없다. 음성과 음악은 앱에 담긴 파일이다. "기기 목소리"는 시스템 TTS 엔진이 자기 프로세스에서 처리한다.
  - INTERNET이 없으면 datatransport 전송은 IOException으로 실패한다. 이 실패는 재시도 작업으로 처리될 뿐 앱이 죽지 않는다.
  - 남는 위험은 실기기에서 확인하지 못했다는 점이다(3절의 확인 항목). 눈 지킴이가 동작하지 않으면 이 제거부터 되돌려 본다.
- `test/release_test.dart`가 제거 규칙이 남아 있는지 확인한다.

## 6. 개인정보처리방침

- 파일은 `web/privacy.html`이다(한국어와 영어 한 페이지). 웹 빌드에 그대로 복사되므로 배포하면 **https://ul-dong.github.io/alokdalok/privacy.html** 로 열린다.
  `tool/build_web.sh`가 `build/web`의 모든 파일을 오프라인 목록에 넣으므로 오프라인 목록에도 자동으로 들어간다.
- 내용은 다음과 같다.
  - 회원가입 없음, 서버 없음, 앱 자체의 수집·전송 없음, 광고·결제·분석 없음, Android 앱은 인터넷 권한 없음.
  - 다만 Android에서 얼굴 인식에 쓰는 Google ML Kit이 Google Play 서비스를 통해 진단 정보(기기·앱 정보, 기기 식별자, 성능 지표)를 수집할 수 있다(7.2, B안).
  - 저장은 기기 내부뿐이고, Google 드라이브 자동 백업은 끄고, 기기를 바꿀 때는 '백업 글자'를 쓴다.
  - 눈 지킴이는 기본으로 켜져 있다. 카메라 권한은 처음 실행할 때 부모님 안내 화면에서 [허용하고 시작]을 눌렀을 때만 요청한다. 영상은 기기 안에서 얼굴 크기와 기울기 계산에만 쓰고, 저장하거나 전송하지 않으며, 누구인지 식별하지 않는다.
  - Android는 Play 서비스 ML Kit, 웹은 앱에 담긴 MediaPipe를 쓴다.
- **문의 연락처는 자리표시다:** `[앱 전용 문의 이메일 — 출시 전 입력]` (영어 쪽은 `[App contact email — to be filled in before release]`).
  2026-11-15 사용자 결정: 개인 메일이 아닌 **앱 전용 이메일**을 새로 만들어 쓴다(아직 없음). 같은 주소를 Play Console "개발자 연락처 이메일"에도 넣는다. 이 주소는 스토어에 공개된다.
  GitHub Issues 링크는 개발자용 보조 창구로만 남긴다. 개인 이메일 주소는 어디에도 넣지 않는다.
- Play Console의 **앱 콘텐츠 → 개인정보처리방침**에 위 URL을 넣는다. 웹을 다시 배포해 URL이 열리는지 먼저 확인한다.

## 7. Play Console 입력값

### 7.1 앱 콘텐츠

| 항목 | 답 |
|---|---|
| 개인정보처리방침 | https://ul-dong.github.io/alokdalok/privacy.html |
| 앱 액세스 권한 | 모든 기능을 제한 없이 사용할 수 있다 (로그인 없음). 설정은 앱 안의 간단한 보호자 확인 문제로 열린다. 심사자용 안내로 "부모 확인: 두 수(각 6~9)의 덧셈 답을 숫자 패드로 누르면 설정이 열린다"를 적는다 |
| 광고 | **아니요, 광고가 없다** |
| 콘텐츠 등급 | 7.3 참고 |
| **타겟층** | 연령 그룹에서 **"만 5세 이하"만** 선택한다. 다른 연령대는 고르지 않는다. 이렇게 하면 **가족 정책(Families)이 전부 적용되는 아동 전용 앱**이 된다 |
| 아동에게 의도치 않게 매력적인지 | 해당 없음 (아동 대상 앱) |
| 가족 정책 준수 선언 | 동의한다. 근거: 광고와 광고 SDK 없음, AD_ID 없음, 인앱 결제와 가챠 없음, 앱 자체의 개인정보 수집 없음(ML Kit 진단 정보는 7.2에 신고), 외부 링크 없음, 위치 권한 없음. 카메라 권한은 부모님 안내 화면 뒤에만 묻는다. 코인은 놀이로만 얻고 틀려도 줄지 않는다. ML Kit의 가족 정책 SDK 요구사항 충족 여부는 10절에서 확인한다 |
| 뉴스 앱 | 아니요 |
| 코로나19 접촉 추적·상태 앱 | 아니요 |
| 데이터 보안(데이터 안전성) | 7.2 참고 |
| 정부 앱 | 아니요 |
| 금융 기능 | 없음 |
| 건강 앱 | 아니요. 눈 지킴이는 화면 거리와 휴식 안내일 뿐 의료·건강 측정 기능이 아니다 |
| 카테고리 | 앱 → **교육** (또는 게임 → 교육. Android 16의 게임 예외를 노리지 않으므로 교육을 권장한다). 태그: 유아, 숫자, 색깔 |

### 7.2 데이터 안전성 답변: B안(진단 정보 신고)으로 확정

*2026-11-15 사용자 결정.* 앱 자체는 아무것도 보내지 않지만, 얼굴 인식에 쓰는 ML Kit(Google Play 서비스)이
진단 목적으로 데이터를 수집할 수 있으므로 보수적으로 신고한다.

근거 문서: Google "ML Kit Android SDK 데이터 공개" (https://developers.google.com/ml-kit/android-data-disclosure, 2025-05-14 수정본을 2026-11-15에 확인).
- 문서는 "모든 기능 공통"으로 다음을 수집한다고 적는다: 기기 정보(제조사, 모델, OS 버전·빌드, ML 가속기), 앱 정보(패키지명, 앱 버전),
  기기 또는 기타 식별자(Play 서비스판 "thin" 기능은 기기 식별자와 설치별 식별자), 성능 지표(지연 시간 등), API 설정(이미지 형식·해상도),
  기능 입력·출력 크기, 기능 버전, 이벤트 종류, 오류 코드.
- 모든 항목의 용도는 "진단 및 사용 분석(diagnostics and usage analytics)"이다.
- "제3자에게 전송하지 않는다", "HTTPS로 암호화해 전송한다"고 적는다.
- 얼굴 인식 전용 항목은 따로 없다. 삭제 요청과 일시 처리(ephemeral) 여부는 문서에 없다.
- 문서는 데이터 안전성 답변을 개발자가 책임지고 정하라고 한다.

**Play Console 입력값** (항목 이름은 Play Console 한국어 화면 기준. 화면 문구가 다르면 같은 뜻의 항목을 고른다)

| 질문 | 답 |
|---|---|
| 앱이 필수 사용자 데이터 유형을 수집하거나 공유하나요? | **예** (ML Kit 진단 정보 때문) |
| 전송되는 모든 사용자 데이터가 암호화되나요? | **예**. ML Kit이 HTTPS로 보낸다 (Google 문서). 앱 자체는 보내는 데이터가 없다 |
| 사용자가 데이터 삭제를 요청할 수 있는 방법을 제공하나요? | 앱에는 계정과 서버가 없어서 개발자가 지울 데이터가 없다. 앱을 지우면 기기 안 기록이 모두 지워진다. ML Kit이 Google에 보낸 진단 정보의 삭제는 Google이 처리한다(Google 개인정보처리방침의 방법). **Google 문서로 최종 확인 필요**: ML Kit 문서에 삭제 요청 방법이 없다. Play 양식에서 이 질문에 "아니요"로 답할지, 위 설명으로 답할지 Play 도움말과 함께 확인한다 |

수집하는 데이터 유형 (모두 **수집함, 공유 안 함, 필수**)

| Play 데이터 유형 | 실제 내용 (ML Kit 문서) | 일시 처리 | 목적 |
|---|---|---|---|
| **앱 정보 및 성능 → 진단** | 기기 정보(제조사, 모델, OS), 앱 정보(패키지명, 버전), 성능 지표(지연 시간), API 설정, 이벤트 종류, 오류 코드 | 아니요 | **앱 기능, 분석** |
| **기기 또는 기타 ID** | Play 서비스판 기능의 기기 식별자와 설치별 식별자 | 아니요 | **앱 기능, 분석** |

- 목적 메모: Google 문서의 용도는 "진단 및 사용 분석"이다. Play 양식에는 "진단"이라는 목적이 없어서 **분석**을 고르고,
  얼굴 인식이 동작하는 데 필요한 Play 서비스 기능이므로 **앱 기능**도 함께 고른다. 광고·마케팅, 맞춤설정, 계정 관리, 개발자 커뮤니케이션은 고르지 않는다.
  광고와 추적에는 쓰지 않는다. 판매하지 않는다. **Google 문서로 최종 확인 필요**: 목적 매핑(진단 → 분석)은 Google이 정해 준 것이 아니라 우리가 고른 것이다.
- "공유"가 아닌 이유: Play 정의에서 서비스 제공자(여기서는 Google Play 서비스)가 개발자를 대신해 처리하는 전송은 공유에서 뺀다. ML Kit 문서도 제3자에게 넘기지 않는다고 적는다.
- "선택" 아닌 "필수"인 이유: 눈 지킴이를 켜면 사용자가 이 수집만 따로 끌 수 없다. (눈 지킴이를 끄면 ML Kit을 쓰지 않는다.)

그 밖의 유형은 모두 **수집 안 함**이다.
- 사진·동영상(카메라): 프레임은 기기 안에서만 처리하고 바로 버리며 기기 밖으로 보내지 않는다.
  Play 정의에서 기기 안에서만 처리하는 데이터는 "수집"이 아니다. 그래도 처리 사실은 개인정보처리방침 4절과 스토어 설명에 공개한다.
- 위치, 개인 정보(이름·이메일 등), 앱 활동, 연락처, 오디오, 파일, 금융 정보: 없음. 닉네임과 놀이 기록은 기기에만 있다.

참고: release 앱은 INTERNET 권한을 빼서(5절) 앱 프로세스의 전송 통로(datatransport)로는 보낼 수 없다.
그래도 Play 서비스 프로세스 쪽 로깅은 앱이 통제할 수 없으므로 신고한다. 개인정보처리방침(`web/privacy.html` 2절, 4절)도 같은 내용으로 맞췄다.

### 7.3 콘텐츠 등급 설문 메모

- Play Console 설문(IARC)으로 처리한다. 카테고리는 "기타 앱"이 아니라 교육·게임 성격에 맞는 것을 고른다.
  폭력, 공포, 성적 내용, 언어, 약물, 도박이 모두 없다. 사용자 간 소통·공유, 위치 공유, 디지털 상품 구매도 없다(코인은 놀이용이고 현금 구매가 없다).
- **한국 등급:** Google Play는 게임물관리위원회가 지정한 자체등급분류사업자다. 설문 결과로 한국 등급(전체이용가가 예상된다)이 함께 나온다.
  **게임물관리위원회에 별도로 신청할 필요가 없다.**

## 8. 스토어 등록 정보 초안

### 한국어

- **앱 이름 (30자):** 알록달록 꼬마 놀이터
- **간단한 설명 (80자):** 만 3~4세를 위한 숫자·색깔·모양 놀이. 광고와 결제 없이, 인터넷 없이 놀아요.
- **자세한 설명:**

```
알록달록 꼬마 놀이터는 만 3~4세 아이가 혼자서도 즐겁게 숫자와 색깔을 만나는 놀이 앱이에요.

■ 놀이
• 숫자 놀이: 풍선을 세고 몇 개인지 찾아요
• 색깔 놀이: 빨강, 파랑, 갈색… 색 이름을 듣고 골라요
• 모양·크기·짝 맞추기 놀이
• 모든 안내는 다정한 녹음 목소리로 읽어 줘요. 글을 몰라도 놀 수 있어요
• 틀려도 괜찮아요. 힌트를 주고 다시 해 볼 수 있어요

■ 내 캐릭터와 꾸미기
• 열두 띠 동물·공룡 친구 중에서 내 캐릭터를 골라요
• 놀이로 모은 코인으로 옷과 탈것을 꾸며요 (코인은 돈으로 살 수 없고, 틀려도 줄지 않아요)

■ 부모님을 위한 안전 장치
• 눈 지킴이: 앞카메라로 화면이 너무 가까운지, 바르게 앉았는지 살펴 알려 줘요.
  카메라 영상은 기기 안에서만 처리하고, 저장하거나 어디로도 보내지 않아요. 설정에서 끌 수 있어요.
• 하루 놀이 시간과 눈 쉬기 알림
• 설정은 부모 확인 뒤에만 열려요

■ 개인정보
• 광고 없음, 인앱 결제 없음, 회원가입 없음
• 인터넷 없이 놀 수 있어요. 기록은 기기 안에만 저장돼요
• 기기를 바꿀 때는 설정의 '백업 글자'로 옮길 수 있어요

개인정보처리방침: https://ul-dong.github.io/alokdalok/privacy.html
```

### English

- **App name:** Balloon Playground
- **Short description (80):** Numbers, colors and shapes for ages 3–4. No ads, no purchases, works offline.
- **Full description:**

```
Balloon Playground is a gentle play app where children aged 3–4 explore numbers and colors on their own.

■ Play
• Number play: count balloons and find how many there are
• Color play: hear a color name and pick it
• Shape, size and matching games
• Every instruction is read aloud by a friendly recorded voice, so no reading is needed
• Mistakes are fine: hints help children try again

■ My character
• Choose a character from the twelve zodiac animals or dinosaur friends
• Dress up and decorate rides with coins earned through play (coins cannot be bought and are never taken away)

■ Safety features for parents
• Eye Guard: the front camera checks whether the screen is too close or posture is off.
  Camera frames are processed only on the device and are never saved or sent anywhere. It can be turned off in Settings.
• Daily play time limit and eye-rest breaks
• Settings open only after a parent check

■ Privacy
• No ads, no in-app purchases, no sign-up
• Works without the internet; progress is stored only on the device
• Move progress to a new device with a "backup code" in Settings

Privacy policy: https://ul-dong.github.io/alokdalok/privacy.html
```

### 그래픽

- 스크린샷: `tool/store_shots.sh`로 만든다. 결과는 `tool/out/store_shots/`이고 git에서 제외된다.
  1280×800 가로 6장이다: 1 홈, 2 숫자 놀이, 3 색깔 놀이, 4 꾸미기 상점, 5 내 캐릭터, 6 눈 지킴이 안내("화면이 너무 가까워요!").
  - `test_preview` 골든 렌더러(Jua 글꼴)로 그려서 언제든 똑같이 다시 뽑을 수 있다. 렌더러 설정은 `test_preview/store_shots_test.dart`에 있다.
  - Play 휴대폰 스크린샷 조건(변 320~3840px, 긴 변이 짧은 변의 2배 이하)을 만족한다.
    7인치와 10인치 태블릿 칸에도 같은 그림을 쓸 수 있다. 추천 노출에 1080px 이상이 필요하면 `STORE_DPR=2 tool/store_shots.sh`로 2560×1600을 뽑는다.
- 앱 아이콘 512×512: `web/icons/Icon-512.png`(같은 그림).
- 그래픽 이미지 1024×500: **아직 없다.** 사용자가 만들거나 다음 작업으로 렌더러에 추가한다.

## 9. allowBackup: 끄기로 결정 (`android:allowBackup="false"`)

- 기본값 `true`일 때 일어나는 일
  - Android 자동 백업이 SharedPreferences(닉네임, 캐릭터, 코인, 진행, 설정)를 **사용자의 Google 드라이브에 올린다.**
  - 같은 Google 계정의 새 Android 기기에 앱을 설치하면 자동으로 복원된다.
- '백업 글자'와 비교
  - 백업 글자는 서버 없이 보호자가 직접 복사해 옮기는 방식이다. Android, iOS, 웹 사이를 오갈 수 있다.
  - 자동 백업은 Android에서 Android로만 되고, 클라우드를 거친다.
  - 두 기능의 목적(기기 바꾸기)은 겹치지만 방식이 다르다. 백업 글자가 자동 백업으로 대체되지는 않는다.
- **결론: 자동 백업을 끈다.**
  - 사양(`docs/MASTER_PROMPT.md`)과 CLAUDE.md의 "개인정보는 기기 안에만" 원칙, 그리고 개인정보처리방침의 "기기 밖으로 보내지 않음"과 맞추기 위해서다.
    true로 두면 아동 데이터가 Google 드라이브로 나가므로 방침과 데이터 안전성 답변이 복잡해진다.
  - targetSdk 31 이상에서는 `allowBackup=false`여도 **기기 간 직접 옮기기(케이블이나 무선으로 새 폰 설정할 때)는 계속 된다.** 그래서 Android 12 이상끼리 바꿀 때는 따로 하지 않아도 옮겨진다.
  - 그 밖의 경우(클라우드 복원, iOS나 웹으로 옮기기, Android 11 이하)는 '백업 글자'를 쓴다. 이 기능은 그대로 유지한다.

## 10. 사용자가 직접 할 일

1. **개발자 계정**: 만들고 본인 인증을 한다. 개인이면 2023-11-13 이후 계정인지 확인한다(0절). 등록비를 낸다.
2. **비공개 테스트 시작**: 테스터 12명 이상, 14일 연속 참여. 가장 먼저 시작한다.
3. **업로드 키**: 만들고(`install_and_build.command` 6단계) `.jks`와 비밀번호를 따로 백업한다. 그다음 `tool/build_android.sh`로 출시용 AAB를 만든다.
4. **앱 전용 문의 이메일 만들기**: 개인 메일이 아닌 앱 전용 이메일을 새로 만든다. Play 개발자 연락처는 스토어에 공개되기 때문이다.
   만든 주소로 `web/privacy.html`의 `[앱 전용 문의 이메일 — 출시 전 입력]`(영어 쪽 `[App contact email — to be filled in before release]`)과 이 문서 6절을 바꾸고, Play Console 개발자 연락처 이메일에도 넣는다.
   GitHub Issues는 개발자용 보조 창구로만 둔다.
5. **웹 다시 배포**: privacy.html이 https://ul-dong.github.io/alokdalok/privacy.html 에서 열리는지 확인한다.
6. **데이터 안전성 입력**: B안(진단 정보 신고)으로 확정했다(7.2). 표대로 입력하고, "Google 문서로 최종 확인 필요" 표시가 붙은 두 곳(삭제 요청 답, 목적 매핑)을 Play 도움말과 대조한다.
7. **실기기 점검**: 노치, Android 16 태블릿 가로 고정, 뒤로 가기 예측, INTERNET을 뺀 상태의 눈 지킴이(3절).
8. **그래픽 이미지** 1024×500을 준비한다.
9. 콘텐츠 등급 설문, 타겟층("만 5세 이하"만), 가족 정책 선언, 광고 없음을 입력한다(7절).
10. **ML Kit 얼굴 인식과 가족 정책 SDK 요구사항 확인 (확인 필요)**: 타겟층이 아동뿐인 앱은 아동 대상 서비스에 쓸 수 있는 SDK만 넣어야 한다는 요구가 있다.
    이것은 광고 SDK용 "Families Self-Certified Ads SDK Program"이 아니라 **일반 SDK 요구사항**이다. ML Kit 얼굴 인식(Play 서비스판 `play-services-mlkit-face-detection`)이 이 요구에 맞는지 확인한다.
    정확한 정책 이름과 조항 링크는 아직 확인하지 못했다(확인 필요). Play 정책 센터의 가족 정책 페이지와 Play Console 정책 안내에서 찾는다.
    맞지 않으면 눈 지킴이 기본값이나 얼굴 인식 방식을 다시 정해야 하므로 출시 전에 반드시 확인한다.
11. 실기기에서 첫 실행 부모님 안내 화면을 확인한다: 안내 전에 카메라 표시등이 켜지지 않는지, [허용하고 시작] 뒤에만 권한 창이 뜨는지, 거절해도 앱이 정상인지.
    (2026-11-15 사용자 결정으로 "부모님 안내 → 권한 요청" 순서를 넣었다. `docs/MASTER_PROMPT.md` 눈 보호 항목.)
