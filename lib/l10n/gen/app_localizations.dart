import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// 앱 이름 (웹 탭 제목 등)
  ///
  /// In ko, this message translates to:
  /// **'알록달록 꼬마 놀이터'**
  String get app_title;

  /// No description provided for @settings_language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settings_language;

  /// No description provided for @settings_languageHint.
  ///
  /// In ko, this message translates to:
  /// **'화면 글자와 목소리'**
  String get settings_languageHint;

  /// 기기(웹은 브라우저) 언어를 따른다
  ///
  /// In ko, this message translates to:
  /// **'자동'**
  String get settings_languageAuto;

  /// [음성] 집(홈)으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'집으로'**
  String get common_home;

  /// No description provided for @settings_title.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings_title;

  /// No description provided for @settings_forParents.
  ///
  /// In ko, this message translates to:
  /// **'부모님용'**
  String get settings_forParents;

  /// No description provided for @settings_eyeSection.
  ///
  /// In ko, this message translates to:
  /// **'눈 보호'**
  String get settings_eyeSection;

  /// No description provided for @settings_playTimeSection.
  ///
  /// In ko, this message translates to:
  /// **'놀이 시간'**
  String get settings_playTimeSection;

  /// No description provided for @settings_breakSection.
  ///
  /// In ko, this message translates to:
  /// **'눈 쉬기 간격'**
  String get settings_breakSection;

  /// No description provided for @settings_soundSection.
  ///
  /// In ko, this message translates to:
  /// **'소리'**
  String get settings_soundSection;

  /// No description provided for @settings_voiceGuide.
  ///
  /// In ko, this message translates to:
  /// **'목소리 안내'**
  String get settings_voiceGuide;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'목소리 안내를 켰어요.'**
  String get settings_voiceOnSay;

  /// No description provided for @settings_voice.
  ///
  /// In ko, this message translates to:
  /// **'목소리'**
  String get settings_voice;

  /// No description provided for @settings_voiceHint.
  ///
  /// In ko, this message translates to:
  /// **'녹음한 목소리 또는 기기 음성'**
  String get settings_voiceHint;

  /// No description provided for @settings_voiceRecorded.
  ///
  /// In ko, this message translates to:
  /// **'녹음'**
  String get settings_voiceRecorded;

  /// No description provided for @settings_voiceDevice.
  ///
  /// In ko, this message translates to:
  /// **'기기'**
  String get settings_voiceDevice;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'안녕! 나랑 같이 놀자!'**
  String get settings_voiceSampleSay;

  /// No description provided for @settings_sfx.
  ///
  /// In ko, this message translates to:
  /// **'효과음'**
  String get settings_sfx;

  /// No description provided for @settings_music.
  ///
  /// In ko, this message translates to:
  /// **'배경 음악'**
  String get settings_music;

  /// No description provided for @settings_noTts.
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서는 한국어 음성을 찾지 못했어요. 기기 설정에서 한국어 TTS를 설치하면 들을 수 있어요.'**
  String get settings_noTts;

  /// No description provided for @settings_gateSection.
  ///
  /// In ko, this message translates to:
  /// **'부모 확인'**
  String get settings_gateSection;

  /// No description provided for @settings_gateToggle.
  ///
  /// In ko, this message translates to:
  /// **'설정 전에 덧셈 문제'**
  String get settings_gateToggle;

  /// No description provided for @settings_recordSection.
  ///
  /// In ko, this message translates to:
  /// **'기록'**
  String get settings_recordSection;

  /// No description provided for @settings_nickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get settings_nickname;

  /// No description provided for @settings_change.
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get settings_change;

  /// No description provided for @settings_changeNickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 바꾸기'**
  String get settings_changeNickname;

  /// No description provided for @settings_parentNotesSection.
  ///
  /// In ko, this message translates to:
  /// **'부모님께'**
  String get settings_parentNotesSection;

  /// No description provided for @settings_licenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get settings_licenses;

  /// No description provided for @settings_toggleState.
  ///
  /// In ko, this message translates to:
  /// **'{label} {state}'**
  String settings_toggleState(Object label, Object state);

  /// No description provided for @common_on.
  ///
  /// In ko, this message translates to:
  /// **'켜짐'**
  String get common_on;

  /// No description provided for @common_off.
  ///
  /// In ko, this message translates to:
  /// **'꺼짐'**
  String get common_off;

  /// No description provided for @settings_resetAll.
  ///
  /// In ko, this message translates to:
  /// **'기록 모두 지우기 (3초 꾹 누르기)'**
  String get settings_resetAll;

  /// No description provided for @settings_eyeUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서는 쓸 수 없어요'**
  String get settings_eyeUnsupported;

  /// No description provided for @settings_eyeHeatOff.
  ///
  /// In ko, this message translates to:
  /// **'기기가 뜨거워서 눈 지킴이를 잠시 껐어요'**
  String get settings_eyeHeatOff;

  /// No description provided for @settings_eyeAbout.
  ///
  /// In ko, this message translates to:
  /// **'앞카메라로 화면과의 거리(30cm 이상)와 바른 자세를 살펴봐요'**
  String get settings_eyeAbout;

  /// No description provided for @settings_eyeIdle.
  ///
  /// In ko, this message translates to:
  /// **'아이 화면(설정 밖)에서 앞카메라로 거리(30cm 이상)와 바른 자세를 살펴봐요'**
  String get settings_eyeIdle;

  /// No description provided for @settings_eyeSearching.
  ///
  /// In ko, this message translates to:
  /// **'얼굴을 찾는 중이에요…'**
  String get settings_eyeSearching;

  /// No description provided for @settings_eyePostureGood.
  ///
  /// In ko, this message translates to:
  /// **'자세 좋아요'**
  String get settings_eyePostureGood;

  /// No description provided for @settings_eyePostureBad.
  ///
  /// In ko, this message translates to:
  /// **'자세가 비뚤어졌어요'**
  String get settings_eyePostureBad;

  /// No description provided for @settings_eyeNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 거리 약 {cm}cm, {posture}'**
  String settings_eyeNow(Object cm, Object posture);

  /// No description provided for @settings_eyeGuard.
  ///
  /// In ko, this message translates to:
  /// **'눈 지킴이'**
  String get settings_eyeGuard;

  /// No description provided for @settings_eyeDistance.
  ///
  /// In ko, this message translates to:
  /// **'이보다 가까우면 쉬어 가요'**
  String get settings_eyeDistance;

  /// No description provided for @settings_eyeCalibrate.
  ///
  /// In ko, this message translates to:
  /// **'30cm 기준 맞추기'**
  String get settings_eyeCalibrate;

  /// No description provided for @settings_eyeCalibrated.
  ///
  /// In ko, this message translates to:
  /// **'지금 거리를 30cm 기준으로 저장했어요'**
  String get settings_eyeCalibrated;

  /// No description provided for @settings_eyeNoFace.
  ///
  /// In ko, this message translates to:
  /// **'얼굴이 보이지 않아요. 카메라를 보고 다시 눌러 주세요'**
  String get settings_eyeNoFace;

  /// No description provided for @settings_eyeCalibrationClear.
  ///
  /// In ko, this message translates to:
  /// **'기준 지우기'**
  String get settings_eyeCalibrationClear;

  /// No description provided for @settings_eyeCalibrateHow.
  ///
  /// In ko, this message translates to:
  /// **'정확하게 하려면: 아이 눈에서 30cm(자 하나) 떨어진 곳에 화면을 두고, 아이가 화면을 볼 때 \"30cm 기준 맞추기\"를 눌러 주세요.'**
  String get settings_eyeCalibrateHow;

  /// No description provided for @settings_minutes.
  ///
  /// In ko, this message translates to:
  /// **'{n}분'**
  String settings_minutes(Object n);

  /// No description provided for @settings_dailyLimit.
  ///
  /// In ko, this message translates to:
  /// **'하루 놀이 시간'**
  String get settings_dailyLimit;

  /// No description provided for @settings_playUsed.
  ///
  /// In ko, this message translates to:
  /// **'오늘 논 시간 {time}'**
  String settings_playUsed(Object time);

  /// No description provided for @settings_playLeft.
  ///
  /// In ko, this message translates to:
  /// **', 남은 시간 {time}'**
  String settings_playLeft(Object time);

  /// No description provided for @settings_playBonus.
  ///
  /// In ko, this message translates to:
  /// **' (더 준 시간 {n}분)'**
  String settings_playBonus(Object n);

  /// No description provided for @settings_noLimit.
  ///
  /// In ko, this message translates to:
  /// **'제한 없음'**
  String get settings_noLimit;

  /// No description provided for @settings_limitNote.
  ///
  /// In ko, this message translates to:
  /// **'다 되면 \"오늘은 여기까지!\"가 화면을 덮어요. 부모 확인 후 15분 더 놀 수 있고, 다음 날 다시 풀려요.'**
  String get settings_limitNote;

  /// No description provided for @settings_break.
  ///
  /// In ko, this message translates to:
  /// **'눈 쉬기'**
  String get settings_break;

  /// No description provided for @settings_breakNote.
  ///
  /// In ko, this message translates to:
  /// **'이어서 놀면 20초 동안 \"창밖 먼 곳을 봐요\"를 보여 줘요. 앱을 5분 넘게 안 보면 쉰 것으로 쳐요.'**
  String get settings_breakNote;

  /// No description provided for @settings_breakEvery.
  ///
  /// In ko, this message translates to:
  /// **'{n}분마다'**
  String settings_breakEvery(Object n);

  /// No description provided for @settings_backup.
  ///
  /// In ko, this message translates to:
  /// **'백업'**
  String get settings_backup;

  /// No description provided for @settings_backupNote.
  ///
  /// In ko, this message translates to:
  /// **'기록을 \'ALOK1-\'로 시작하는 글자로 만들어 복사해 두었다가, 다른 기기에 붙여 넣으면 그대로 옮겨져요. 서버로 보내지 않아요.'**
  String get settings_backupNote;

  /// No description provided for @settings_backupMake.
  ///
  /// In ko, this message translates to:
  /// **'백업 글자 만들기'**
  String get settings_backupMake;

  /// No description provided for @settings_backupRestore.
  ///
  /// In ko, this message translates to:
  /// **'백업 글자로 복구'**
  String get settings_backupRestore;

  /// No description provided for @settings_backupText.
  ///
  /// In ko, this message translates to:
  /// **'백업 글자'**
  String get settings_backupText;

  /// No description provided for @settings_backupCopied.
  ///
  /// In ko, this message translates to:
  /// **'복사했어요. 메모나 메시지에 붙여 넣어 보관해 주세요.'**
  String get settings_backupCopied;

  /// No description provided for @settings_backupCopyHint.
  ///
  /// In ko, this message translates to:
  /// **'아래 버튼으로 복사해서 안전한 곳에 보관해 주세요.'**
  String get settings_backupCopyHint;

  /// No description provided for @common_close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get common_close;

  /// No description provided for @settings_copy.
  ///
  /// In ko, this message translates to:
  /// **'복사하기'**
  String get settings_copy;

  /// No description provided for @settings_backupRestored.
  ///
  /// In ko, this message translates to:
  /// **'백업 글자로 기록을 되살렸어요'**
  String get settings_backupRestored;

  /// No description provided for @settings_backupRestoreNote.
  ///
  /// In ko, this message translates to:
  /// **'복구하면 지금 기기의 기록이 백업 기록으로 바뀌어요.'**
  String get settings_backupRestoreNote;

  /// No description provided for @settings_paste.
  ///
  /// In ko, this message translates to:
  /// **'붙여 넣기'**
  String get settings_paste;

  /// No description provided for @settings_restore.
  ///
  /// In ko, this message translates to:
  /// **'복구하기'**
  String get settings_restore;

  /// No description provided for @settings_note1.
  ///
  /// In ko, this message translates to:
  /// **'회원가입, 서버, 광고, 추적, 현금 결제가 없습니다.'**
  String get settings_note1;

  /// No description provided for @settings_note2.
  ///
  /// In ko, this message translates to:
  /// **'닉네임과 진행 기록은 이 기기 안에만 저장됩니다.'**
  String get settings_note2;

  /// No description provided for @settings_note3.
  ///
  /// In ko, this message translates to:
  /// **'코인은 놀이로만 모으고, 꾸미기 아이템에만 씁니다.'**
  String get settings_note3;

  /// No description provided for @settings_note4.
  ///
  /// In ko, this message translates to:
  /// **'한 판은 5문제(약 1~2분)입니다.'**
  String get settings_note4;

  /// No description provided for @settings_note5.
  ///
  /// In ko, this message translates to:
  /// **'눈 지킴이를 켜면 앞카메라 영상을 이 기기 안에서만 살펴보고, 저장하거나 보내지 않습니다.'**
  String get settings_note5;

  /// No description provided for @bag_title.
  ///
  /// In ko, this message translates to:
  /// **'내 가방'**
  String get bag_title;

  /// No description provided for @common_coins.
  ///
  /// In ko, this message translates to:
  /// **'코인'**
  String get common_coins;

  /// No description provided for @common_stars.
  ///
  /// In ko, this message translates to:
  /// **'별'**
  String get common_stars;

  /// No description provided for @bag_empty.
  ///
  /// In ko, this message translates to:
  /// **'놀이로 코인을 모아\n상점에서 골라 보세요'**
  String get bag_empty;

  /// No description provided for @character_resetOutfit.
  ///
  /// In ko, this message translates to:
  /// **'처음 모습으로'**
  String get character_resetOutfit;

  /// No description provided for @character_changeFriend.
  ///
  /// In ko, this message translates to:
  /// **'친구 바꾸기'**
  String get character_changeFriend;

  /// No description provided for @character_pickRide.
  ///
  /// In ko, this message translates to:
  /// **'타고 싶은 걸 눌러요'**
  String get character_pickRide;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'출발!'**
  String get character_goSay;

  /// No description provided for @character_getOff.
  ///
  /// In ko, this message translates to:
  /// **'내리기'**
  String get character_getOff;

  /// No description provided for @character_ride.
  ///
  /// In ko, this message translates to:
  /// **'탑승'**
  String get character_ride;

  /// No description provided for @character_rideButton.
  ///
  /// In ko, this message translates to:
  /// **'탑승!'**
  String get character_rideButton;

  /// No description provided for @character_decorateRide.
  ///
  /// In ko, this message translates to:
  /// **'탈것 꾸미기'**
  String get character_decorateRide;

  /// No description provided for @character_decorate.
  ///
  /// In ko, this message translates to:
  /// **'꾸미기'**
  String get character_decorate;

  /// No description provided for @character_riding.
  ///
  /// In ko, this message translates to:
  /// **'{name}, 타는 중'**
  String character_riding(Object name);

  /// No description provided for @character_none.
  ///
  /// In ko, this message translates to:
  /// **'아직 없어요'**
  String get character_none;

  /// No description provided for @character_goShop.
  ///
  /// In ko, this message translates to:
  /// **'상점 가기'**
  String get character_goShop;

  /// No description provided for @home_playground.
  ///
  /// In ko, this message translates to:
  /// **'놀이터 가기'**
  String get home_playground;

  /// No description provided for @home_replay.
  ///
  /// In ko, this message translates to:
  /// **'또 하기'**
  String get home_replay;

  /// [음성] 홈 버튼
  ///
  /// In ko, this message translates to:
  /// **'내 캐릭터'**
  String get home_character;

  /// [음성] 홈 버튼
  ///
  /// In ko, this message translates to:
  /// **'꾸미기 상점'**
  String get home_shop;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'안녕! 오늘은 뭐 하고 놀까?'**
  String get home_helloSay;

  /// No description provided for @home_pet.
  ///
  /// In ko, this message translates to:
  /// **'내 친구 쓰다듬기'**
  String get home_pet;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'내 이름을 지어 줄래?'**
  String get nickname_askSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'{name}, 반가워!'**
  String nickname_greetSay(Object name);

  /// [음성] 뒤로 버튼
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get common_back;

  /// No description provided for @nickname_title.
  ///
  /// In ko, this message translates to:
  /// **'이름을 지어 주세요'**
  String get nickname_title;

  /// No description provided for @nickname_field.
  ///
  /// In ko, this message translates to:
  /// **'이름 쓰기'**
  String get nickname_field;

  /// No description provided for @nickname_ok.
  ///
  /// In ko, this message translates to:
  /// **'좋아요'**
  String get nickname_ok;

  /// No description provided for @nickname_randomHint.
  ///
  /// In ko, this message translates to:
  /// **'비워 두고 좋아요를 누르면 이름을 아무거나 지어 줘요'**
  String get nickname_randomHint;

  /// No description provided for @nickname_parentNote.
  ///
  /// In ko, this message translates to:
  /// **'부모님께: 실명이나 연락처 대신 별명을 써 주세요. 닉네임은 이 기기 안에만 저장되고 어디로도 보내지 않아요. (한글, 영문, 숫자 8글자까지)'**
  String get nickname_parentNote;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'뭘 하고 놀까요?'**
  String get playground_greetingSay;

  /// No description provided for @playground_title.
  ///
  /// In ko, this message translates to:
  /// **'놀이터'**
  String get playground_title;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'앞 단계를 먼저 놀아 볼까요?'**
  String get stage_lockedSay;

  /// No description provided for @stage_toPlayground.
  ///
  /// In ko, this message translates to:
  /// **'놀이터로'**
  String get stage_toPlayground;

  /// No description provided for @stage_card.
  ///
  /// In ko, this message translates to:
  /// **'{n}단계'**
  String stage_card(Object n);

  /// No description provided for @stage_cardLocked.
  ///
  /// In ko, this message translates to:
  /// **'{n}단계 아직 열리지 않음'**
  String stage_cardLocked(Object n);

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'안녕! 함께 놀 친구를 골라 볼까요?'**
  String get zodiac_askSay;

  /// No description provided for @zodiac_choose.
  ///
  /// In ko, this message translates to:
  /// **'이 친구로 할래요'**
  String get zodiac_choose;

  /// No description provided for @zodiac_change.
  ///
  /// In ko, this message translates to:
  /// **'이 친구로 바꾸기'**
  String get zodiac_change;

  /// No description provided for @zodiac_groupZodiac.
  ///
  /// In ko, this message translates to:
  /// **'12지신'**
  String get zodiac_groupZodiac;

  /// No description provided for @zodiac_groupDino.
  ///
  /// In ko, this message translates to:
  /// **'공룡'**
  String get zodiac_groupDino;

  /// No description provided for @common_page.
  ///
  /// In ko, this message translates to:
  /// **'{page}쪽 / {count}쪽'**
  String common_page(Object page, Object count);

  /// No description provided for @common_nextPage.
  ///
  /// In ko, this message translates to:
  /// **'다음 쪽'**
  String get common_nextPage;

  /// No description provided for @common_prevPage.
  ///
  /// In ko, this message translates to:
  /// **'앞 쪽'**
  String get common_prevPage;

  /// No description provided for @common_progress.
  ///
  /// In ko, this message translates to:
  /// **'{total}개 중 {done}개 완료'**
  String common_progress(Object total, Object done);

  /// No description provided for @common_rotate.
  ///
  /// In ko, this message translates to:
  /// **'화면을 옆으로 돌려 주세요'**
  String get common_rotate;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'잘했어요! 다시 놀아요.'**
  String get eye_backSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'화면이 너무 가까워요. 조금 뒤로 가 볼까요?'**
  String get eye_tooCloseSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'바르게 앉아서 봐요. 화면을 똑바로 봐 주세요.'**
  String get eye_postureSay;

  /// No description provided for @eye_tooCloseTitle.
  ///
  /// In ko, this message translates to:
  /// **'화면이 너무 가까워요!'**
  String get eye_tooCloseTitle;

  /// No description provided for @eye_postureTitle.
  ///
  /// In ko, this message translates to:
  /// **'바르게 앉아서 봐요!'**
  String get eye_postureTitle;

  /// No description provided for @eye_tooCloseHint.
  ///
  /// In ko, this message translates to:
  /// **'한 뼘 더 뒤로 가면 다시 놀 수 있어요'**
  String get eye_tooCloseHint;

  /// No description provided for @eye_postureHint.
  ///
  /// In ko, this message translates to:
  /// **'화면을 똑바로 보면 다시 놀 수 있어요'**
  String get eye_postureHint;

  /// No description provided for @eye_parentContinue.
  ///
  /// In ko, this message translates to:
  /// **'부모님: 길게 눌러 계속하기'**
  String get eye_parentContinue;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'꾹 누르고 있어요.'**
  String get hold_hintSay;

  /// No description provided for @hold_shownLabel.
  ///
  /// In ko, this message translates to:
  /// **'{label} (꾹)'**
  String hold_shownLabel(Object label);

  /// No description provided for @hold_semantic.
  ///
  /// In ko, this message translates to:
  /// **'{label} (꾹 누르기)'**
  String hold_semantic(Object label);

  /// [음성] 다시 듣기 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 듣기'**
  String get common_listenAgain;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'부모님을 불러 주세요.'**
  String get gate_callParentSay;

  /// No description provided for @gate_title.
  ///
  /// In ko, this message translates to:
  /// **'부모님 확인'**
  String get gate_title;

  /// No description provided for @gate_wrong.
  ///
  /// In ko, this message translates to:
  /// **'답이 달라요. 새 문제를 풀어 주세요.'**
  String get gate_wrong;

  /// No description provided for @gate_hint.
  ///
  /// In ko, this message translates to:
  /// **'두 수를 더한 답을 눌러 주세요.'**
  String get gate_hint;

  /// No description provided for @gate_digit.
  ///
  /// In ko, this message translates to:
  /// **'숫자 {d}'**
  String gate_digit(Object d);

  /// No description provided for @gate_delete.
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get gate_delete;

  /// No description provided for @gate_ok.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get gate_ok;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'오늘은 여기까지! 내일 또 만나요.'**
  String get play_limitSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'창밖 먼 곳을 봐요.'**
  String get play_breakSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'잘 쉬었어요! 다시 놀아요.'**
  String get play_restedSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'15분 더 놀 수 있어요.'**
  String get play_moreSay;

  /// No description provided for @play_limitTitle.
  ///
  /// In ko, this message translates to:
  /// **'오늘은 여기까지!'**
  String get play_limitTitle;

  /// No description provided for @play_limitSub.
  ///
  /// In ko, this message translates to:
  /// **'내일 또 만나요'**
  String get play_limitSub;

  /// No description provided for @play_parentMore.
  ///
  /// In ko, this message translates to:
  /// **'부모님: 15분 더'**
  String get play_parentMore;

  /// No description provided for @play_tapToPlay.
  ///
  /// In ko, this message translates to:
  /// **'눌러서 다시 놀기'**
  String get play_tapToPlay;

  /// No description provided for @play_breakTitle.
  ///
  /// In ko, this message translates to:
  /// **'창밖 먼 곳을 봐요'**
  String get play_breakTitle;

  /// No description provided for @play_restDone.
  ///
  /// In ko, this message translates to:
  /// **'다 쉬었으면 화면을 눌러요'**
  String get play_restDone;

  /// No description provided for @poke_friend.
  ///
  /// In ko, this message translates to:
  /// **'내 친구'**
  String get poke_friend;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'안녕!'**
  String get poke_helloSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'간지러워!'**
  String get poke_ticklesSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'같이 놀자!'**
  String get poke_playSay;

  /// [음성] 말한다
  ///
  /// In ko, this message translates to:
  /// **'또 만져 줘!'**
  String get poke_againSay;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
