import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceHeat: DeviceHeatChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlokDeviceHeat") {
      deviceHeat = DeviceHeatChannel(messenger: registrar.messenger())
    }
  }
}

/// 눈 지킴이 발열·절전 백오프용 기기 상태 채널 (플러그인 없이 직접, 안드로이드 MainActivity와 같은 모양).
///
/// `alokdalok/device_heat`:
/// - 앱 → `start`: 지금 상태를 돌려주고, 이때부터 바뀔 때마다 앱으로 `changed`를 보낸다.
/// - 상태 = { thermal: 안드로이드 THERMAL_STATUS 숫자로 맞춤 (nominal 0, fair 2 = MODERATE,
///            serious 3 = SEVERE, critical 4), powerSave: 저전력 모드, battery: 0~100 (모르면 -1) }
final class DeviceHeatChannel: NSObject {
  private let channel: FlutterMethodChannel
  private var watching = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "alokdalok/device_heat", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "start":
        self.watch()
        result(self.status())
      case "read":
        result(self.status())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func thermal() -> Int {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return 0
    case .fair: return 2
    case .serious: return 3
    case .critical: return 4
    @unknown default: return -1
    }
  }

  private func battery() -> Int {
    let level = UIDevice.current.batteryLevel  // 모르면(시뮬레이터) -1
    return level < 0 ? -1 : Int((level * 100).rounded())
  }

  private func status() -> [String: Any] {
    return [
      "thermal": thermal(),
      "powerSave": ProcessInfo.processInfo.isLowPowerModeEnabled,
      "battery": battery(),
    ]
  }

  private func watch() {
    if watching { return }
    watching = true
    UIDevice.current.isBatteryMonitoringEnabled = true
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      ProcessInfo.thermalStateDidChangeNotification,
      Notification.Name.NSProcessInfoPowerStateDidChange,
      UIDevice.batteryLevelDidChangeNotification,
    ]
    for name in names {
      center.addObserver(self, selector: #selector(changed), name: name, object: nil)
    }
  }

  @objc private func changed() {
    // 열·절전 알림은 아무 스레드에서나 온다: 채널은 메인 스레드에서
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.channel.invokeMethod("changed", arguments: self.status())
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
