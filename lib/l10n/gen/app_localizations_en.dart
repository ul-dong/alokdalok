// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Balloon Playground';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_languageHint => 'Words on screen and voice';

  @override
  String get settings_languageAuto => 'Auto';

  @override
  String get common_home => 'Home';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_forParents => 'For parents';

  @override
  String get settings_eyeSection => 'Eye care';

  @override
  String get settings_playTimeSection => 'Play time';

  @override
  String get settings_breakSection => 'Eye breaks';

  @override
  String get settings_soundSection => 'Sound';

  @override
  String get settings_voiceGuide => 'Voice guide';

  @override
  String get settings_voiceOnSay => 'Voice guide is on.';

  @override
  String get settings_voice => 'Voice';

  @override
  String get settings_voiceHint => 'Recorded voice or device voice';

  @override
  String get settings_voiceRecorded => 'Recorded';

  @override
  String get settings_voiceDevice => 'Device';

  @override
  String get settings_voiceSampleSay => 'Hi! Let\'s play together!';

  @override
  String get settings_sfx => 'Sound effects';

  @override
  String get settings_music => 'Music';

  @override
  String get settings_noTts =>
      'No English voice was found on this device. Install English text-to-speech in the device settings to hear it.';

  @override
  String get settings_gateSection => 'Parent check';

  @override
  String get settings_gateToggle => 'Addition problem before settings';

  @override
  String get settings_recordSection => 'Records';

  @override
  String get settings_nickname => 'Nickname';

  @override
  String get settings_change => 'Change';

  @override
  String get settings_changeNickname => 'Change nickname';

  @override
  String get settings_parentNotesSection => 'For parents';

  @override
  String get settings_licenses => 'Open source licenses';

  @override
  String settings_toggleState(Object label, Object state) {
    return '$label $state';
  }

  @override
  String get common_on => 'On';

  @override
  String get common_off => 'Off';

  @override
  String get settings_resetAll => 'Erase all records (hold 3 seconds)';

  @override
  String get settings_eyeUnsupported => 'Not available on this device';

  @override
  String get settings_eyeHeatOff => 'The device is hot, so Eye Guard is paused';

  @override
  String get settings_eyeAbout =>
      'Uses the front camera to check screen distance (30 cm or more) and posture';

  @override
  String get settings_eyeIdle =>
      'On the child\'s screens (outside settings), checks distance (30 cm or more) and posture with the front camera';

  @override
  String get settings_eyeSearching => 'Looking for a face…';

  @override
  String get settings_eyePostureGood => 'good posture';

  @override
  String get settings_eyePostureBad => 'head is tilted';

  @override
  String settings_eyeNow(Object cm, Object posture) {
    return 'About $cm cm away now, $posture';
  }

  @override
  String get settings_eyeGuard => 'Eye Guard';

  @override
  String get settings_eyeDistance => 'Take a break when closer than this';

  @override
  String get settings_eyeCalibrate => 'Set 30 cm';

  @override
  String get settings_eyeCalibrated => 'Saved the current distance as 30 cm';

  @override
  String get settings_eyeNoFace =>
      'Can\'t see a face. Look at the camera and tap again';

  @override
  String get settings_eyeCalibrationClear => 'Clear';

  @override
  String get settings_eyeCalibrateHow =>
      'For accuracy: hold the screen 30 cm (one ruler) from your child\'s eyes and tap \"Set 30 cm\" while they look at it.';

  @override
  String settings_minutes(Object n) {
    return '$n min';
  }

  @override
  String get settings_dailyLimit => 'Daily play time';

  @override
  String settings_playUsed(Object time) {
    return 'Played today: $time';
  }

  @override
  String settings_playLeft(Object time) {
    return ', $time left';
  }

  @override
  String settings_playBonus(Object n) {
    return ' (+$n min extra)';
  }

  @override
  String get settings_noLimit => 'No limit';

  @override
  String get settings_limitNote =>
      'When time is up, \"That\'s all for today!\" covers the screen. After a parent check you can add 15 minutes. It resets the next day.';

  @override
  String get settings_break => 'Eye break';

  @override
  String get settings_breakNote =>
      'After playing this long, shows \"Look far out the window\" for 20 seconds. Not using the app for 5+ minutes counts as a break.';

  @override
  String settings_breakEvery(Object n) {
    return 'Every $n min';
  }

  @override
  String get settings_backup => 'Backup';

  @override
  String get settings_backupNote =>
      'Turns the records into text starting with \'ALOK1-\'. Copy it, then paste it on another device to move everything. Nothing is sent to a server.';

  @override
  String get settings_backupMake => 'Make backup text';

  @override
  String get settings_backupRestore => 'Restore from backup text';

  @override
  String get settings_backupText => 'Backup text';

  @override
  String get settings_backupCopied =>
      'Copied. Paste it into a note or message to keep it.';

  @override
  String get settings_backupCopyHint =>
      'Copy it with the button below and keep it somewhere safe.';

  @override
  String get common_close => 'Close';

  @override
  String get settings_copy => 'Copy';

  @override
  String get settings_backupRestored => 'Records restored from backup text';

  @override
  String get settings_backupRestoreNote =>
      'Restoring replaces this device\'s records with the backup.';

  @override
  String get settings_paste => 'Paste';

  @override
  String get settings_restore => 'Restore';

  @override
  String get settings_note1 =>
      'No sign-up, servers, ads, tracking, or real-money payments.';

  @override
  String get settings_note2 =>
      'The nickname and progress are saved only on this device.';

  @override
  String get settings_note3 =>
      'Coins are earned only by playing and spent only on dress-up items.';

  @override
  String get settings_note4 => 'One round is 5 questions (about 1–2 minutes).';

  @override
  String get settings_note5 =>
      'With Eye Guard on, the front camera image is checked only on this device and is never saved or sent.';

  @override
  String get bag_title => 'My bag';

  @override
  String get common_coins => 'Coins';

  @override
  String get common_stars => 'Stars';

  @override
  String get bag_empty =>
      'Play to earn coins,\nthen pick something in the shop';

  @override
  String get character_resetOutfit => 'Back to the start';

  @override
  String get character_changeFriend => 'Change friend';

  @override
  String get character_pickRide => 'Tap what you want to ride';

  @override
  String get character_goSay => 'Let\'s go!';

  @override
  String get character_getOff => 'Get off';

  @override
  String get character_ride => 'Ride';

  @override
  String get character_rideButton => 'Ride!';

  @override
  String get character_decorateRide => 'Decorate ride';

  @override
  String get character_decorate => 'Decorate';

  @override
  String character_riding(Object name) {
    return '$name, riding';
  }

  @override
  String get character_none => 'Nothing yet';

  @override
  String get character_goShop => 'Go to shop';

  @override
  String get home_playground => 'Playground';

  @override
  String get home_replay => 'Play again';

  @override
  String get home_character => 'My friend';

  @override
  String get home_shop => 'Dress-up shop';

  @override
  String get home_helloSay => 'Hi! What shall we play today?';

  @override
  String get home_pet => 'Pet my friend';

  @override
  String get nickname_askSay => 'Will you give me a name?';

  @override
  String nickname_greetSay(Object name) {
    return '$name, nice to meet you!';
  }

  @override
  String get common_back => 'Back';

  @override
  String get nickname_title => 'Give me a name';

  @override
  String get nickname_field => 'Write a name';

  @override
  String get nickname_ok => 'OK';

  @override
  String get nickname_randomHint =>
      'Leave it empty and tap OK to get a random name';

  @override
  String get nickname_parentNote =>
      'For parents: please use a nickname, not a real name or contact info. It is saved only on this device and never sent anywhere. (Up to 8 letters or numbers)';

  @override
  String get playground_greetingSay => 'What shall we play?';

  @override
  String get playground_title => 'Playground';

  @override
  String get stage_lockedSay => 'Let\'s play the step before first!';

  @override
  String get stage_toPlayground => 'To playground';

  @override
  String stage_card(Object n) {
    return 'Step $n';
  }

  @override
  String stage_cardLocked(Object n) {
    return 'Step $n, not open yet';
  }

  @override
  String get zodiac_askSay => 'Hi! Will you pick a friend to play with?';

  @override
  String get zodiac_choose => 'I pick this friend';

  @override
  String get zodiac_change => 'Switch to this friend';

  @override
  String get zodiac_groupZodiac => 'Zodiac';

  @override
  String get zodiac_groupDino => 'Dinosaurs';

  @override
  String common_page(Object page, Object count) {
    return 'Page $page of $count';
  }

  @override
  String get common_nextPage => 'Next page';

  @override
  String get common_prevPage => 'Previous page';

  @override
  String common_progress(Object total, Object done) {
    return '$done of $total done';
  }

  @override
  String get common_rotate => 'Please turn the screen sideways';

  @override
  String get eye_backSay => 'Good job! Let\'s play again.';

  @override
  String get eye_tooCloseSay =>
      'The screen is too close. Can you move back a little?';

  @override
  String get eye_postureSay =>
      'Sit up nicely. Look straight at the screen, please.';

  @override
  String get eye_tooCloseTitle => 'Too close to the screen!';

  @override
  String get eye_postureTitle => 'Sit up nicely!';

  @override
  String get eye_tooCloseHint => 'Move back a hand away to play again';

  @override
  String get eye_postureHint => 'Look straight at the screen to play again';

  @override
  String get eye_parentContinue => 'Parents: hold to continue';

  @override
  String get hold_hintSay => 'Keep holding.';

  @override
  String hold_shownLabel(Object label) {
    return '$label (hold)';
  }

  @override
  String hold_semantic(Object label) {
    return '$label (press and hold)';
  }

  @override
  String get common_listenAgain => 'Listen again';

  @override
  String get gate_callParentSay => 'Please get a grown-up.';

  @override
  String get gate_title => 'Parent check';

  @override
  String get gate_wrong => 'That\'s not right. Please try a new one.';

  @override
  String get gate_hint => 'Enter the sum of the two numbers.';

  @override
  String gate_digit(Object d) {
    return 'Number $d';
  }

  @override
  String get gate_delete => 'Delete';

  @override
  String get gate_ok => 'OK';

  @override
  String get play_limitSay => 'That\'s all for today! See you tomorrow.';

  @override
  String get play_breakSay => 'Look far away out the window.';

  @override
  String get play_restedSay => 'Good rest! Let\'s play again.';

  @override
  String get play_moreSay => 'You can play 15 more minutes.';

  @override
  String get play_limitTitle => 'That\'s all for today!';

  @override
  String get play_limitSub => 'See you tomorrow';

  @override
  String get play_parentMore => 'Parents: 15 more min';

  @override
  String get play_tapToPlay => 'Tap to play again';

  @override
  String get play_breakTitle => 'Look far out the window';

  @override
  String get play_restDone => 'Tap the screen when you are rested';

  @override
  String get poke_friend => 'My friend';

  @override
  String get poke_helloSay => 'Hi!';

  @override
  String get poke_ticklesSay => 'That tickles!';

  @override
  String get poke_playSay => 'Let\'s play!';

  @override
  String get poke_againSay => 'Do it again!';

  @override
  String get shop_vehicles => 'Rides';

  @override
  String shop_tileOwned(Object name) {
    return '$name, owned';
  }

  @override
  String shop_tilePrice(Object name, Object price) {
    return '$name, $price coins';
  }

  @override
  String shop_buyAsk(Object price) {
    return 'Buy for $price?';
  }

  @override
  String get common_no => 'No';

  @override
  String get common_yes => 'Yes';

  @override
  String shop_boughtSay(Object name) {
    return '$name! So cool!';
  }

  @override
  String get shop_pickItem => 'Tap what you want to try on';

  @override
  String get shop_takeOff => 'Take off';

  @override
  String get shop_putOn => 'Put on';

  @override
  String shop_needCoins(Object coins, Object price) {
    return 'Play to collect coins ($coins/$price)';
  }

  @override
  String shop_buyFor(Object price) {
    return 'Buy for $price coins';
  }

  @override
  String shop_coins(Object coins) {
    return '$coins coins';
  }

  @override
  String get garage_fullSay =>
      'No more room for stickers. Shall we use the eraser?';

  @override
  String get garage_empty =>
      'Buy a ride in the shop\nto add stickers and paint it';

  @override
  String garage_tapToSticker(Object name) {
    return '$name, tap to add a sticker';
  }

  @override
  String get garage_pickColor => 'Pick a color on the right';

  @override
  String get garage_eraser => 'Eraser';

  @override
  String get garage_riding => 'Riding';

  @override
  String get garage_stickers => 'Stickers';

  @override
  String get garage_paints => 'Paints';

  @override
  String get garage_paint => 'Paint';

  @override
  String get garage_sticker => 'Sticker';

  @override
  String get garage_color => 'Color';

  @override
  String get game_praiseSay => 'Great job!';

  @override
  String get game_oneMore => 'Shall we try once more?';

  @override
  String get game_doneSay => 'Great job! You got coins.';

  @override
  String get game_pause => 'Pause';

  @override
  String get game_resume => 'Go on';

  @override
  String game_stageOpened(Object n) {
    return 'Step $n is open!';
  }

  @override
  String get game_nextStage => 'Next step';

  @override
  String get game_goal => 'Goal!';

  @override
  String get game_tryAgainSay => 'Let\'s look again!';

  @override
  String get number_countTogetherSay => 'Let\'s count together!';

  @override
  String get match_sameSay => 'They match!';

  @override
  String get match_promptSay => 'Can you find two pictures that match?';

  @override
  String get nickname_errEmpty => 'Please enter a nickname.';

  @override
  String get nickname_errSpace => 'Please write it without spaces.';

  @override
  String nickname_errLength(Object n) {
    return 'Up to $n letters.';
  }

  @override
  String get nickname_errChars => 'Only letters and numbers, please.';

  @override
  String get nickname_errBlocked => 'Please choose a different nickname.';

  @override
  String match_hintLabel(Object name) {
    return 'Find: $name';
  }

  @override
  String match_card(Object name) {
    return 'Card: $name';
  }

  @override
  String get backup_errNotBackup =>
      'That isn\'t backup text. Please paste text that starts with \'ALOK1-\'.';

  @override
  String get backup_errDamaged =>
      'Some text is missing or changed. Please copy all of it again.';

  @override
  String get backup_errTooNew =>
      'This backup is from a newer app. Please update the app and try again.';

  @override
  String get eye_errNoFront => 'No front camera';

  @override
  String get eye_errPermission => 'Please allow camera access';

  @override
  String eye_errBusy(Object code) {
    return 'The camera can\'t be used right now ($code)';
  }

  @override
  String eye_errNoImage(Object code) {
    return 'Couldn\'t get a camera image ($code)';
  }

  @override
  String get eye_errLoad => 'Couldn\'t load Eye Guard';
}
