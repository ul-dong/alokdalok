import 'dart:ui';

/// 탈것 종류. 그림은 lib/vehicle/vehicle_painter.dart
enum VehicleKind { car, rocket, tank, motorcycle, train, balloon, airplane }

/// 탈것 한 종류. 종류마다 한 대씩 있고, 색은 [VehiclePaint]로 칠한다.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    required this.defaultPaint,
  });

  final String id;
  final VehicleKind kind;
  final String name;
  final int price;

  /// 처음 살 때 칠해져 있는 색 (이 탈것에는 공짜)
  final String defaultPaint;
}

/// 탈것 색. 한 번 사면 가진 모든 탈것에 칠할 수 있다.
class VehiclePaint {
  const VehiclePaint({
    required this.id,
    required this.name,
    required this.body,
    required this.trim,
  });

  final String id;

  /// 말할 때 쓰는 색 이름 ("빨간색")
  final String name;

  /// 차체 색
  final Color body;

  /// 창문 테두리·날개·줄무늬 같은 포인트 색
  final Color trim;
}

/// 스티커 모양. 스티커는 탈것을 사면 마음껏 붙일 수 있다 (따로 사지 않음).
enum StickerKind {
  star,
  heart,
  flower,
  lightning,
  moon,
  rainbow,
  paw,
  smile,
  cloud,
  note,
}

/// 탈것에 붙인 스티커 한 장. 위치는 탈것 그림 안의 비율(0~1).
class PlacedSticker {
  const PlacedSticker({
    required this.kind,
    required this.color,
    required this.x,
    required this.y,
  });

  final StickerKind kind;
  final int color; // ARGB
  final double x;
  final double y;

  Map<String, Object> toJson() => {'k': kind.name, 'c': color, 'x': x, 'y': y};

  static PlacedSticker? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = j['k'];
    final kind = StickerKind.values.where((e) => e.name == k).firstOrNull;
    final c = j['c'];
    final x = j['x'];
    final y = j['y'];
    if (kind == null || c is! int || x is! num || y is! num) return null;
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;
    return PlacedSticker(
      kind: kind,
      color: c,
      x: x.toDouble(),
      y: y.toDouble(),
    );
  }
}

class Vehicles {
  Vehicles._();

  /// 탈것 하나에 붙일 수 있는 스티커 수
  static const int maxStickers = 12;

  static const List<Vehicle> all = [
    Vehicle(
      id: 'balloon',
      kind: VehicleKind.balloon,
      name: '열기구',
      price: 20,
      defaultPaint: 'paint_pink',
    ),
    Vehicle(
      id: 'train',
      kind: VehicleKind.train,
      name: '기차',
      price: 25,
      defaultPaint: 'paint_yellow',
    ),
    Vehicle(
      id: 'car',
      kind: VehicleKind.car,
      name: '자동차',
      price: 40,
      defaultPaint: 'paint_red',
    ),
    Vehicle(
      id: 'motorcycle',
      kind: VehicleKind.motorcycle,
      name: '오토바이',
      price: 40,
      defaultPaint: 'paint_blue',
    ),
    Vehicle(
      id: 'tank',
      kind: VehicleKind.tank,
      name: '탱크',
      price: 50,
      defaultPaint: 'paint_green',
    ),
    Vehicle(
      id: 'airplane',
      kind: VehicleKind.airplane,
      name: '비행기',
      price: 50,
      defaultPaint: 'paint_orange',
    ),
    Vehicle(
      id: 'rocket',
      kind: VehicleKind.rocket,
      name: '우주선',
      price: 50,
      defaultPaint: 'paint_white',
    ),
  ];

  /// 색칠 값 (탈것마다 색깔별로 따로 산다)
  static const int paintPrice = 10;

  /// 탈것별로 산 색을 저장하는 이름: 'paint_red@car'
  static String paintKey(String vehicleId, String paintId) =>
      '$paintId@$vehicleId';

  static bool paintKeyValid(String key) {
    final i = key.indexOf('@');
    if (i <= 0) return false;
    return paintExists(key.substring(0, i)) && exists(key.substring(i + 1));
  }

  static const List<VehiclePaint> paints = [
    VehiclePaint(
      id: 'paint_red',
      name: '빨간색',
      body: Color(0xFFE8352B),
      trim: Color(0xFFFFD000),
    ),
    VehiclePaint(
      id: 'paint_orange',
      name: '주황색',
      body: Color(0xFFFF7A00),
      trim: Color(0xFFFFF1C9),
    ),
    VehiclePaint(
      id: 'paint_yellow',
      name: '노란색',
      body: Color(0xFFFFCC00),
      trim: Color(0xFFE8352B),
    ),
    VehiclePaint(
      id: 'paint_green',
      name: '초록색',
      body: Color(0xFF19A84A),
      trim: Color(0xFFFFD000),
    ),
    VehiclePaint(
      id: 'paint_blue',
      name: '파란색',
      body: Color(0xFF1565E0),
      trim: Color(0xFFFFFFFF),
    ),
    VehiclePaint(
      id: 'paint_purple',
      name: '보라색',
      body: Color(0xFF7B3FD1),
      trim: Color(0xFFFFD000),
    ),
    VehiclePaint(
      id: 'paint_pink',
      name: '분홍색',
      body: Color(0xFFFF4F9A),
      trim: Color(0xFFFFFFFF),
    ),
    VehiclePaint(
      id: 'paint_white',
      name: '흰색',
      body: Color(0xFFF6F8FA),
      trim: Color(0xFFE8352B),
    ),
    VehiclePaint(
      id: 'paint_black',
      name: '검은색',
      body: Color(0xFF2E2E36),
      trim: Color(0xFFFFD000),
    ),
  ];

  /// 예전 버전(v3)의 색깔별 탈것 → 지금의 탈것과 색
  static const Map<String, (String vehicle, String paint, int price)> legacy = {
    'car_red': ('car', 'paint_red', 40),
    'car_blue': ('car', 'paint_blue', 40),
    'rocket_white': ('rocket', 'paint_white', 50),
    'rocket_purple': ('rocket', 'paint_purple', 50),
  };

  /// 없어진 탈것 → 대신 주는 탈것과, 없어진 탈것의 처음 색(공짜였던 색).
  /// 다리가 어색하고 스티커 자리가 좁던 자전거·킥보드를 기차·열기구로 바꿨다.
  /// 저장값은 `SaveData.migrate`가 버전과 상관없이 옮긴다 (스티커·색 포함).
  static const Map<String, (String to, String freePaint)> retired = {
    'bicycle': ('train', 'paint_yellow'),
    'kickboard': ('balloon', 'paint_pink'),
  };

  /// 스티커 색 (아이가 고르기 쉬운 선명한 색 6가지)
  static const List<Color> stickerColors = [
    Color(0xFFFFCC00),
    Color(0xFFE8352B),
    Color(0xFFFF4F9A),
    Color(0xFF1E6FE0),
    Color(0xFF19A84A),
    Color(0xFF7E3FD1),
  ];

  static final Map<String, Vehicle> _byId = {for (final v in all) v.id: v};
  static Vehicle? byId(String id) => _byId[id];
  static bool exists(String id) => _byId.containsKey(id);

  static final Map<String, VehiclePaint> _paintById = {
    for (final p in paints) p.id: p,
  };
  static VehiclePaint? paintById(String id) => _paintById[id];
  static bool paintExists(String id) => _paintById.containsKey(id);

  /// 이 탈것의 기본 색
  static VehiclePaint defaultPaintOf(Vehicle v) => _paintById[v.defaultPaint]!;
}
