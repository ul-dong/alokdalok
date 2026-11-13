import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 기기 열 상태. 안드로이드 `PowerManager.THERMAL_STATUS_*`(0~6) 순서와 같다.
/// iOS `ProcessInfo.thermalState`는 nominal → none, fair → moderate, serious → severe, critical → critical.
enum HeatLevel {
  /// 알 수 없음 (안드로이드 10 미만, 웹, 채널 없음)
  unknown,
  none,
  light,
  moderate,
  severe,
  critical,
  emergency,
  shutdown;

  /// 플랫폼 채널 값(-1 = 모름, 0~6) → 단계
  static HeatLevel fromRaw(Object? raw) {
    final i = raw is int ? raw : -1;
    if (i < 0 || i > 6) return HeatLevel.unknown;
    return HeatLevel.values[i + 1];
  }

  bool atLeast(HeatLevel other) =>
      this != HeatLevel.unknown && index >= other.index;

  /// 진단 칸 이름
  String get label => switch (this) {
    HeatLevel.unknown => '모름',
    HeatLevel.none => '보통',
    HeatLevel.light => '조금 따뜻함',
    HeatLevel.moderate => '따뜻함 (MODERATE)',
    HeatLevel.severe => '뜨거움 (SEVERE)',
    HeatLevel.critical => '아주 뜨거움 (CRITICAL)',
    HeatLevel.emergency => '아주 뜨거움 (EMERGENCY)',
    HeatLevel.shutdown => '아주 뜨거움 (SHUTDOWN)',
  };
}

/// 기기 열·절전·배터리 상태 (한 번 읽은 값)
@immutable
class HeatStatus {
  const HeatStatus({
    this.thermal = HeatLevel.unknown,
    this.powerSave,
    this.battery,
  });

  final HeatLevel thermal;

  /// 절전 모드 (iOS 저전력 모드). 모르면 null
  final bool? powerSave;

  /// 배터리 % (0~100). 모르면 null
  final int? battery;

  static HeatStatus fromMap(Object? m) {
    if (m is! Map) return const HeatStatus();
    final b = m['battery'];
    final p = m['powerSave'];
    return HeatStatus(
      thermal: HeatLevel.fromRaw(m['thermal']),
      powerSave: p is bool ? p : null,
      battery: b is int && b >= 0 && b <= 100 ? b : null,
    );
  }
}

/// 기기가 따뜻한지·절전 중인지 알려 준다 (눈 지킴이 창 주기 백오프).
///
/// 플러그인 없이 플랫폼 채널 `alokdalok/device_heat`로 직접 읽는다:
/// - 안드로이드 `MainActivity`: `PowerManager.getCurrentThermalStatus()` +
///   `addThermalStatusListener` (API 29+, 그 아래는 모름), `isPowerSaveMode`, 배터리 %.
/// - iOS `AppDelegate`: `ProcessInfo.thermalState`, `isLowPowerModeEnabled`, `UIDevice` 배터리.
/// - 웹: 열 정보가 없어 백오프하지 않는다 ([bind]를 부르지 않는다).
///
/// 앱이 `start`를 부르면 지금 값을 돌려주고, 바뀔 때마다 네이티브가 `changed`를 부른다.
class DeviceHeat extends ChangeNotifier {
  DeviceHeat([HeatStatus status = const HeatStatus()]) : _status = status;

  /// 앱 전체가 같이 쓰는 값 (main에서 [bind])
  static final DeviceHeat instance = DeviceHeat();

  static const channel = MethodChannel('alokdalok/device_heat');

  /// 배터리가 이 % 이하면 창 주기를 늘린다
  static const lowBattery = 20;

  HeatStatus _status;
  HeatStatus get status => _status;

  /// 플랫폼 채널에 연결됐는지 (진단 칸)
  bool get bound => _bound;
  bool _bound = false;

  /// 새 값 (네이티브 알림, 테스트)
  void update(HeatStatus s) {
    _status = s;
    notifyListeners();
  }

  /// 열 상태 MODERATE 이상: 창 주기 2배
  bool get warm => _status.thermal.atLeast(HeatLevel.moderate);

  /// 열 상태 SEVERE 이상: 이번 실행 동안 눈 지킴이를 끈다
  bool get tooHot => _status.thermal.atLeast(HeatLevel.severe);

  /// 절전 모드이거나 배터리 20% 이하: 창 주기 2배
  bool get saving =>
      _status.powerSave == true ||
      (_status.battery != null && _status.battery! <= lowBattery);

  /// 창 주기를 몇 배로 늘릴지 (따뜻함·절전이 겹쳐도 2배)
  int get backoff => warm || saving ? 2 : 1;

  /// 네이티브 채널에 연결한다 (앱 시작 때 한 번, 웹 제외). 채널이 없으면 모름으로 둔다.
  Future<void> bind() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') update(HeatStatus.fromMap(call.arguments));
      return null;
    });
    try {
      final m = await channel.invokeMethod<Object?>('start');
      _bound = true;
      update(HeatStatus.fromMap(m));
    } on MissingPluginException {
      // 이 플랫폼에는 없음
    } on PlatformException catch (e) {
      debugPrint('device heat: $e');
    }
  }
}
