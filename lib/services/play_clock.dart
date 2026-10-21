/// 아이 안전 기준값 (놀이 시간·눈 쉬기·눈 보호 거리). Flutter 없이 쓰는 순수 값.
class SafetyRules {
  SafetyRules._();

  /// 하루 놀이 시간 선택지 (분). 0은 제한 없음.
  static const limitChoices = [0, 10, 15, 20, 30, 45, 60];
  static const defaultLimit = 10;

  /// 부모 확인 후 더 노는 시간 (분)
  static const extendMinutes = 15;

  /// 눈 쉬기 간격 선택지 (분)
  static const breakChoices = [10, 20];
  static const defaultBreak = 10;

  /// 눈 쉬기 화면을 보여 주는 시간
  static const breakLength = Duration(seconds: 20);

  /// 앱을 이만큼 이상 안 보면(백그라운드) 쉰 것으로 친다
  static const restAfterAway = Duration(minutes: 5);

  /// 눈 보호 거리 선택지 (cm). 이보다 가까우면 경고. 부모님이 조절한다.
  static const eyeDistanceChoices = [25, 30, 35, 40];
  static const defaultEyeDistance = 30;

  /// 시계가 멈췄다 다시 돌 때(기기 잠자기 등) 한 번에 세는 최대 시간.
  /// 이보다 긴 틈은 놀지 않은 것으로 본다.
  static const maxTickGap = Duration(seconds: 30);
}

/// 지금 놀이를 막고 있는 것
enum PlayBlock { none, eyeBreak, limit }

/// 하루 놀이 시간과 눈 쉬기를 세는 순수 로직. 시계([now])를 주입해 테스트한다.
///
/// - [tick]을 주기적으로(1초마다) 부르면 앞 [tick] 이후 흐른 시간을 오늘 논 시간과
///   이어서 논 시간에 더한다. 앱이 뒤로 가 있으면 [pause]/[resume]으로 알린다.
/// - 날짜가 바뀌면 오늘 논 시간과 더 받은 시간이 0으로 돌아간다.
/// - 이어서 [breakMinutes]분 놀면 [SafetyRules.breakLength] 동안 눈 쉬기.
///   [SafetyRules.restAfterAway] 넘게 앱을 안 보면 쉰 것으로 친다.
class PlayClock {
  PlayClock({
    DateTime Function()? now,
    this.limitMinutes = SafetyRules.defaultLimit,
    this.breakMinutes = SafetyRules.defaultBreak,
  }) : _now = now ?? DateTime.now {
    _day = dayKey(_now());
  }

  final DateTime Function() _now;

  /// 하루 놀이 시간 (분, 0이면 제한 없음)
  int limitMinutes;

  /// 눈 쉬기 간격 (분, 0이면 쉬지 않음)
  int breakMinutes;

  late String _day;
  Duration _used = Duration.zero;
  int _bonusMinutes = 0;
  Duration _continuous = Duration.zero;
  Duration _limitIdle = Duration.zero;
  DateTime? _last;
  DateTime? _awaySince;
  DateTime? _breakEnds;

  /// 오늘 날짜 (기기 시간 기준, 예: 2026-10-21)
  String get day => _day;

  /// 오늘 논 시간
  Duration get used => _used;

  /// 오늘 부모님이 더 준 시간 (분)
  int get bonusMinutes => _bonusMinutes;

  /// 쉬지 않고 이어서 논 시간
  Duration get continuous => _continuous;

  bool get away => _awaySince != null;

  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// 저장해 둔 오늘 기록을 되살린다. 다른 날 기록이면 버린다.
  void restore({String? day, int usedSeconds = 0, int bonusMinutes = 0}) {
    final today = dayKey(_now());
    _day = today;
    if (day == today) {
      _used = Duration(seconds: usedSeconds < 0 ? 0 : usedSeconds);
      _bonusMinutes = bonusMinutes < 0 ? 0 : bonusMinutes;
    } else {
      _used = Duration.zero;
      _bonusMinutes = 0;
    }
  }

  /// 오늘 놀 수 있는 전체 시간 (제한 없음이면 null)
  Duration? get allowance => limitMinutes <= 0
      ? null
      : Duration(minutes: limitMinutes + _bonusMinutes);

  /// 오늘 남은 시간 (제한 없음이면 null)
  Duration? get remaining {
    final a = allowance;
    if (a == null) return null;
    final r = a - _used;
    return r.isNegative ? Duration.zero : r;
  }

  bool get limitReached {
    final a = allowance;
    return a != null && _used >= a;
  }

  /// 눈 쉬기 남은 시간 (쉬는 중이 아니면 null)
  Duration? get breakLeft {
    final end = _breakEnds;
    if (end == null) return null;
    final left = end.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  PlayBlock get block {
    if (limitReached) return PlayBlock.limit;
    if (_breakEnds != null) return PlayBlock.eyeBreak;
    return PlayBlock.none;
  }

  /// 흐른 시간을 센다. 막는 상태가 바뀌었으면 true.
  bool tick() {
    final before = block;
    final t = _now();
    _rollDay(t);
    if (_awaySince != null) return block != before;
    final gap = _gapSince(t);
    _last = t;

    final end = _breakEnds;
    if (end != null) {
      // 쉬는 동안은 놀이 시간으로 세지 않는다
      if (!t.isBefore(end)) {
        _breakEnds = null;
        _continuous = Duration.zero;
      }
      return block != before;
    }
    if (limitReached) {
      // "오늘은 여기까지!"가 떠 있는 동안은 놀지 않으니, 쉬는 시간만큼 지나면 눈도 쉰 것
      _limitIdle += gap;
      if (_limitIdle >= SafetyRules.breakLength) _continuous = Duration.zero;
      return block != before;
    }
    _limitIdle = Duration.zero;

    _used += gap;
    _continuous += gap;
    if (!limitReached &&
        breakMinutes > 0 &&
        _continuous >= Duration(minutes: breakMinutes)) {
      _breakEnds = t.add(SafetyRules.breakLength);
    }
    return block != before;
  }

  /// 앱이 뒤로 갔다 (화면을 안 본다)
  void pause() {
    if (_awaySince != null) return;
    tick();
    _awaySince = _now();
  }

  /// 앱으로 돌아왔다. 오래 안 봤으면 쉰 것으로 친다. 막는 상태가 바뀌었으면 true.
  bool resume() {
    final before = block;
    final t = _now();
    final since = _awaySince;
    _awaySince = null;
    _last = t;
    if (since != null && t.difference(since) >= SafetyRules.restAfterAway) {
      _continuous = Duration.zero;
      _breakEnds = null;
    }
    _rollDay(t);
    tick();
    return block != before;
  }

  /// 부모 확인 뒤 15분 더
  void extend([int minutes = SafetyRules.extendMinutes]) {
    _rollDay(_now());
    // 이미 시간이 넘어 있었다면 넘친 만큼은 빼 준다 (지금부터 15분)
    final a = allowance;
    if (a != null && _used > a) _used = a;
    _bonusMinutes += minutes;
    _last = _now();
  }

  /// 눈 쉬기를 바로 끝낸다 (설정에서 간격을 바꿨을 때 등)
  void endBreak() {
    _breakEnds = null;
    _continuous = Duration.zero;
  }

  Duration _gapSince(DateTime t) {
    final last = _last;
    if (last == null) return Duration.zero;
    final gap = t.difference(last);
    if (gap.isNegative || gap > SafetyRules.maxTickGap) return Duration.zero;
    return gap;
  }

  void _rollDay(DateTime t) {
    final k = dayKey(t);
    if (k == _day) return;
    _day = k;
    _used = Duration.zero;
    _bonusMinutes = 0;
  }
}
