// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get app_title => '알록달록 꼬마 놀이터';

  @override
  String get settings_language => '언어';

  @override
  String get settings_languageHint => '화면 글자와 목소리';

  @override
  String get settings_languageAuto => '자동';

  @override
  String get common_home => '집으로';

  @override
  String get settings_title => '설정';

  @override
  String get settings_forParents => '부모님용';

  @override
  String get settings_eyeSection => '눈 보호';

  @override
  String get settings_playTimeSection => '놀이 시간';

  @override
  String get settings_breakSection => '눈 쉬기 간격';

  @override
  String get settings_soundSection => '소리';

  @override
  String get settings_voiceGuide => '목소리 안내';

  @override
  String get settings_voiceOnSay => '목소리 안내를 켰어요.';

  @override
  String get settings_voice => '목소리';

  @override
  String get settings_voiceHint => '녹음한 목소리 또는 기기 음성';

  @override
  String get settings_voiceRecorded => '녹음';

  @override
  String get settings_voiceDevice => '기기';

  @override
  String get settings_voiceSampleSay => '안녕! 나랑 같이 놀자!';

  @override
  String get settings_sfx => '효과음';

  @override
  String get settings_music => '배경 음악';

  @override
  String get settings_noTts =>
      '이 기기에서는 한국어 음성을 찾지 못했어요. 기기 설정에서 한국어 TTS를 설치하면 들을 수 있어요.';

  @override
  String get settings_gateSection => '부모 확인';

  @override
  String get settings_gateToggle => '설정 전에 덧셈 문제';

  @override
  String get settings_recordSection => '기록';

  @override
  String get settings_nickname => '닉네임';

  @override
  String get settings_change => '바꾸기';

  @override
  String get settings_changeNickname => '닉네임 바꾸기';

  @override
  String get settings_parentNotesSection => '부모님께';

  @override
  String get settings_licenses => '오픈소스 라이선스';

  @override
  String settings_toggleState(Object label, Object state) {
    return '$label $state';
  }

  @override
  String get common_on => '켜짐';

  @override
  String get common_off => '꺼짐';

  @override
  String get settings_resetAll => '기록 모두 지우기 (3초 꾹 누르기)';

  @override
  String get settings_eyeUnsupported => '이 기기에서는 쓸 수 없어요';

  @override
  String get settings_eyeHeatOff => '기기가 뜨거워서 눈 지킴이를 잠시 껐어요';

  @override
  String get settings_eyeAbout => '앞카메라로 화면과의 거리(30cm 이상)와 바른 자세를 살펴봐요';

  @override
  String get settings_eyeIdle => '아이 화면(설정 밖)에서 앞카메라로 거리(30cm 이상)와 바른 자세를 살펴봐요';

  @override
  String get settings_eyeSearching => '얼굴을 찾는 중이에요…';

  @override
  String get settings_eyePostureGood => '자세 좋아요';

  @override
  String get settings_eyePostureBad => '자세가 비뚤어졌어요';

  @override
  String settings_eyeNow(Object cm, Object posture) {
    return '지금 거리 약 ${cm}cm, $posture';
  }

  @override
  String get settings_eyeGuard => '눈 지킴이';

  @override
  String get settings_eyeDistance => '이보다 가까우면 쉬어 가요';

  @override
  String get settings_eyeCalibrate => '30cm 기준 맞추기';

  @override
  String get settings_eyeCalibrated => '지금 거리를 30cm 기준으로 저장했어요';

  @override
  String get settings_eyeNoFace => '얼굴이 보이지 않아요. 카메라를 보고 다시 눌러 주세요';

  @override
  String get settings_eyeCalibrationClear => '기준 지우기';

  @override
  String get settings_eyeCalibrateHow =>
      '정확하게 하려면: 아이 눈에서 30cm(자 하나) 떨어진 곳에 화면을 두고, 아이가 화면을 볼 때 \"30cm 기준 맞추기\"를 눌러 주세요.';

  @override
  String settings_minutes(Object n) {
    return '$n분';
  }

  @override
  String get settings_dailyLimit => '하루 놀이 시간';

  @override
  String settings_playUsed(Object time) {
    return '오늘 논 시간 $time';
  }

  @override
  String settings_playLeft(Object time) {
    return ', 남은 시간 $time';
  }

  @override
  String settings_playBonus(Object n) {
    return ' (더 준 시간 $n분)';
  }

  @override
  String get settings_noLimit => '제한 없음';

  @override
  String get settings_limitNote =>
      '다 되면 \"오늘은 여기까지!\"가 화면을 덮어요. 부모 확인 후 15분 더 놀 수 있고, 다음 날 다시 풀려요.';

  @override
  String get settings_break => '눈 쉬기';

  @override
  String get settings_breakNote =>
      '이어서 놀면 20초 동안 \"창밖 먼 곳을 봐요\"를 보여 줘요. 앱을 5분 넘게 안 보면 쉰 것으로 쳐요.';

  @override
  String settings_breakEvery(Object n) {
    return '$n분마다';
  }

  @override
  String get settings_backup => '백업';

  @override
  String get settings_backupNote =>
      '기록을 \'ALOK1-\'로 시작하는 글자로 만들어 복사해 두었다가, 다른 기기에 붙여 넣으면 그대로 옮겨져요. 서버로 보내지 않아요.';

  @override
  String get settings_backupMake => '백업 글자 만들기';

  @override
  String get settings_backupRestore => '백업 글자로 복구';

  @override
  String get settings_backupText => '백업 글자';

  @override
  String get settings_backupCopied => '복사했어요. 메모나 메시지에 붙여 넣어 보관해 주세요.';

  @override
  String get settings_backupCopyHint => '아래 버튼으로 복사해서 안전한 곳에 보관해 주세요.';

  @override
  String get common_close => '닫기';

  @override
  String get settings_copy => '복사하기';

  @override
  String get settings_backupRestored => '백업 글자로 기록을 되살렸어요';

  @override
  String get settings_backupRestoreNote => '복구하면 지금 기기의 기록이 백업 기록으로 바뀌어요.';

  @override
  String get settings_paste => '붙여 넣기';

  @override
  String get settings_restore => '복구하기';

  @override
  String get settings_note1 => '회원가입, 서버, 광고, 추적, 현금 결제가 없습니다.';

  @override
  String get settings_note2 => '닉네임과 진행 기록은 이 기기 안에만 저장됩니다.';

  @override
  String get settings_note3 => '코인은 놀이로만 모으고, 꾸미기 아이템에만 씁니다.';

  @override
  String get settings_note4 => '한 판은 5문제(약 1~2분)입니다.';

  @override
  String get settings_note5 =>
      '눈 지킴이를 켜면 앞카메라 영상을 이 기기 안에서만 살펴보고, 저장하거나 보내지 않습니다.';

  @override
  String get bag_title => '내 가방';

  @override
  String get common_coins => '코인';

  @override
  String get common_stars => '별';

  @override
  String get bag_empty => '놀이로 코인을 모아\n상점에서 골라 보세요';

  @override
  String get character_resetOutfit => '처음 모습으로';

  @override
  String get character_changeFriend => '친구 바꾸기';

  @override
  String get character_pickRide => '타고 싶은 걸 눌러요';

  @override
  String get character_goSay => '출발!';

  @override
  String get character_getOff => '내리기';

  @override
  String get character_ride => '탑승';

  @override
  String get character_rideButton => '탑승!';

  @override
  String get character_decorateRide => '탈것 꾸미기';

  @override
  String get character_decorate => '꾸미기';

  @override
  String character_riding(Object name) {
    return '$name, 타는 중';
  }

  @override
  String get character_none => '아직 없어요';

  @override
  String get character_goShop => '상점 가기';

  @override
  String get home_playground => '놀이터 가기';

  @override
  String get home_replay => '또 하기';

  @override
  String get home_character => '내 캐릭터';

  @override
  String get home_shop => '꾸미기 상점';

  @override
  String get home_helloSay => '안녕! 오늘은 뭐 하고 놀까?';

  @override
  String get home_pet => '내 친구 쓰다듬기';

  @override
  String get nickname_askSay => '내 이름을 지어 줄래?';

  @override
  String nickname_greetSay(Object name) {
    return '$name, 반가워!';
  }

  @override
  String get common_back => '뒤로';

  @override
  String get nickname_title => '이름을 지어 주세요';

  @override
  String get nickname_field => '이름 쓰기';

  @override
  String get nickname_ok => '좋아요';

  @override
  String get nickname_randomHint => '비워 두고 좋아요를 누르면 이름을 아무거나 지어 줘요';

  @override
  String get nickname_parentNote =>
      '부모님께: 실명이나 연락처 대신 별명을 써 주세요. 닉네임은 이 기기 안에만 저장되고 어디로도 보내지 않아요. (한글, 영문, 숫자 8글자까지)';

  @override
  String get playground_greetingSay => '뭘 하고 놀까요?';

  @override
  String get playground_title => '놀이터';

  @override
  String get stage_lockedSay => '앞 단계를 먼저 놀아 볼까요?';

  @override
  String get stage_toPlayground => '놀이터로';

  @override
  String stage_card(Object n) {
    return '$n단계';
  }

  @override
  String stage_cardLocked(Object n) {
    return '$n단계 아직 열리지 않음';
  }

  @override
  String get zodiac_askSay => '안녕! 함께 놀 친구를 골라 볼까요?';

  @override
  String get zodiac_choose => '이 친구로 할래요';

  @override
  String get zodiac_change => '이 친구로 바꾸기';

  @override
  String get zodiac_groupZodiac => '12지신';

  @override
  String get zodiac_groupDino => '공룡';

  @override
  String common_page(Object page, Object count) {
    return '$page쪽 / $count쪽';
  }

  @override
  String get common_nextPage => '다음 쪽';

  @override
  String get common_prevPage => '앞 쪽';

  @override
  String common_progress(Object total, Object done) {
    return '$total개 중 $done개 완료';
  }

  @override
  String get common_rotate => '화면을 옆으로 돌려 주세요';

  @override
  String get eye_backSay => '잘했어요! 다시 놀아요.';

  @override
  String get eye_tooCloseSay => '화면이 너무 가까워요. 조금 뒤로 가 볼까요?';

  @override
  String get eye_postureSay => '바르게 앉아서 봐요. 화면을 똑바로 봐 주세요.';

  @override
  String get eye_tooCloseTitle => '화면이 너무 가까워요!';

  @override
  String get eye_postureTitle => '바르게 앉아서 봐요!';

  @override
  String get eye_tooCloseHint => '한 뼘 더 뒤로 가면 다시 놀 수 있어요';

  @override
  String get eye_postureHint => '화면을 똑바로 보면 다시 놀 수 있어요';

  @override
  String get eye_parentContinue => '부모님: 길게 눌러 계속하기';

  @override
  String get hold_hintSay => '꾹 누르고 있어요.';

  @override
  String hold_shownLabel(Object label) {
    return '$label (꾹)';
  }

  @override
  String hold_semantic(Object label) {
    return '$label (꾹 누르기)';
  }

  @override
  String get common_listenAgain => '다시 듣기';

  @override
  String get gate_callParentSay => '부모님을 불러 주세요.';

  @override
  String get gate_title => '부모님 확인';

  @override
  String get gate_wrong => '답이 달라요. 새 문제를 풀어 주세요.';

  @override
  String get gate_hint => '두 수를 더한 답을 눌러 주세요.';

  @override
  String gate_digit(Object d) {
    return '숫자 $d';
  }

  @override
  String get gate_delete => '지우기';

  @override
  String get gate_ok => '확인';

  @override
  String get play_limitSay => '오늘은 여기까지! 내일 또 만나요.';

  @override
  String get play_breakSay => '창밖 먼 곳을 봐요.';

  @override
  String get play_restedSay => '잘 쉬었어요! 다시 놀아요.';

  @override
  String get play_moreSay => '15분 더 놀 수 있어요.';

  @override
  String get play_limitTitle => '오늘은 여기까지!';

  @override
  String get play_limitSub => '내일 또 만나요';

  @override
  String get play_parentMore => '부모님: 15분 더';

  @override
  String get play_tapToPlay => '눌러서 다시 놀기';

  @override
  String get play_breakTitle => '창밖 먼 곳을 봐요';

  @override
  String get play_restDone => '다 쉬었으면 화면을 눌러요';

  @override
  String get poke_friend => '내 친구';

  @override
  String get poke_helloSay => '안녕!';

  @override
  String get poke_ticklesSay => '간지러워!';

  @override
  String get poke_playSay => '같이 놀자!';

  @override
  String get poke_againSay => '또 만져 줘!';
}
