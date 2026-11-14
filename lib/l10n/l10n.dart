import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// 앱 언어 고르기: 설정값('auto' / 'ko' / 'en') → 실제로 쓸 언어.
class AppLanguage {
  AppLanguage._();

  static const auto = 'auto';

  /// 기기 언어가 지원하지 않는 언어면 한국어
  static const fallback = Locale('ko');
  static const supported = [Locale('ko'), Locale('en')];

  /// 언어 이름은 그 언어로 쓴다 (설정의 언어 고르기: 자동 / 한국어 / English)
  static String nativeName(String code) => switch (code) {
    'ko' => '한국어',
    'en' => 'English',
    _ => code,
  };

  static bool isSupported(String code) =>
      supported.any((l) => l.languageCode == code);

  /// [setting]이 'ko'·'en'이면 그것, 'auto'면 기기(웹은 브라우저) 언어 목록에서 처음 지원하는 언어,
  /// 없으면 한국어.
  static Locale resolve(String setting, Iterable<Locale>? device) {
    if (setting != auto && isSupported(setting)) return Locale(setting);
    for (final l in device ?? const <Locale>[]) {
      if (isSupported(l.languageCode)) return Locale(l.languageCode);
    }
    return fallback;
  }
}

/// 지금 쓰는 언어의 화면 문구.
///
/// 위젯은 [L10n.of] (또는 `context.l10n`)로 읽는다. 놀이 규칙·상태처럼 BuildContext가 없는
/// 코드는 [L10n.current]를 쓴다. 앱은 MaterialApp이 정한 언어를 [L10n.use]로 알려 준다
/// (`GameState.applyLocale`). 언어를 알려 주기 전(테스트 등)에는 한국어다.
class L10n {
  L10n._();

  static Locale _locale = AppLanguage.fallback;
  static AppLocalizations _strings = lookupAppLocalizations(_locale);
  static final _listeners = <void Function(Locale)>[];

  static Locale get locale => _locale;

  /// 'ko' / 'en'
  static String get code => _locale.languageCode;

  static AppLocalizations get current => _strings;

  /// 쓸 언어를 바꾼다. 바뀌었으면 true.
  static bool use(Locale locale) {
    final l = Locale(locale.languageCode);
    if (l == _locale || !AppLanguage.isSupported(l.languageCode)) return false;
    _locale = l;
    _strings = lookupAppLocalizations(l);
    for (final f in List.of(_listeners)) {
      f(l);
    }
    return true;
  }

  /// 언어가 바뀔 때 부른다 (문장 조립기 등)
  static void addListener(void Function(Locale) f) => _listeners.add(f);
  static void removeListener(void Function(Locale) f) => _listeners.remove(f);

  /// 위젯용. 번역 대리자(delegate)가 없는 곳(테스트용 간단한 MaterialApp)에서는 [current].
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? _strings;
}

extension L10nContext on BuildContext {
  /// 화면 문구 (`context.l10n.home_play`)
  AppLocalizations get l10n => L10n.of(this);
}
