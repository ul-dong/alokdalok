import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/features.dart';
import '../data/item_catalog.dart';
import 'billing_store.dart';
import 'game_state.dart';

/// 결제 없이 열려 있는 범위 (`docs/MONETIZATION.md` 2절). 결제가 꺼져 있으면 쓰지 않는다.
abstract final class FreeTier {
  /// 놀이별로 결제 없이 열리는 가장 높은 단계
  static int stages(GameKind g) => switch (g) {
    GameKind.number => 3, // 8단계 중 1~3 (한 가지 물건 줄 맞춰 세기 전부)
    GameKind.color => 2, // 5단계 중 1~2
    GameKind.shape => 1,
    GameKind.size => 1,
    GameKind.match => 1,
  };

  /// 결제 없이 코인으로 살 수 있는 옷 테마 (상점 첫 탭, 5개)
  static const themes = {OutfitTheme.robot};

  /// 결제 없이 코인으로 살 수 있는 탈것 (가장 싼 열기구 한 대: 타기·꾸미기를 맛보게)
  static const vehicles = {'balloon'};
}

/// 부모용 결제 화면이 보여 주는 진행 상태
enum UnlockFlow {
  /// 아직 아무것도 하지 않음 (스토어 연결 전)
  idle,

  /// 스토어에 연결하고 상품 값을 묻는 중
  connecting,

  /// 살 수 있음 (값을 받았다)
  ready,

  /// 스토어에 연결할 수 없음 (오프라인, 스토어 앱 없음, 상품 미등록). 캐시된 해금은 그대로.
  unavailable,

  /// 결제 창이 떠 있음
  purchasing,

  /// 결제 보류 (보호자 승인 대기, 편의점 결제 등). 승인되면 저절로 열린다.
  pending,

  /// 구매 복원 중
  restoring,

  /// 복원했지만 산 기록이 없음
  nothingToRestore,

  /// 결제를 취소함
  canceled,

  /// 결제 실패
  failed,

  /// 열림 (샀거나 복원함)
  unlocked,
}

/// 1회 전체 해금 (비소모성 상품 1종).
///
/// - 결제가 꺼져 있으면([enabled] false) 스토어를 전혀 건드리지 않고 [fullAccess]가 항상 true다.
/// - 결제가 켜져 있으면 기기에 저장한 값([restoreCached])을 먼저 믿고, 스토어는 뒤에서 조용히 연결한다.
///   스토어에 닿지 못해도(오프라인) 캐시된 해금은 그대로이고 앱은 멈추지 않는다.
/// - 영수증은 서버 없이 기기 안에서만 믿는다(로컬 신뢰). 한계는 `docs/MONETIZATION.md` 5절.
/// - 코인과는 아무 관계가 없다: 코인으로 해금을 사는 길은 없다.
class Entitlement extends ChangeNotifier {
  Entitlement({
    bool? enabled,
    BillingStore Function()? storeFactory,
    this.restoreGrace = const Duration(seconds: 4),
    bool? autoRestore,
  }) : enabled = enabled ?? Features.billing,
       _storeFactory = storeFactory ?? defaultBillingStore,
       _autoRestore =
           autoRestore ?? defaultTargetPlatform == TargetPlatform.android;

  /// 스토어에 등록하는 상품 id (Play Console·App Store Connect 모두 같은 id, 비소모성)
  static const productId = 'full_unlock';

  /// 결제를 쓰는지 (꺼져 있으면 전부 열림)
  final bool enabled;

  final BillingStore Function() _storeFactory;

  /// 구매 복원을 누른 뒤 복원 결과를 기다리는 시간 (이 안에 산 기록이 안 오면 "산 기록이 없어요")
  final Duration restoreGrace;

  /// 앱을 열 때 해금이 없으면 조용히 복원해 볼지. 안드로이드만 (iOS 복원은 Apple ID 로그인 창이
  /// 뜰 수 있어 아이 앞에서 저절로 하지 않는다).
  final bool _autoRestore;

  BillingStore? _store;
  StreamSubscription<List<StorePurchase>>? _sub;
  StoreProduct? _product;
  bool _unlocked = false;
  UnlockFlow _flow = UnlockFlow.idle;

  /// 해금이 새로 생겼을 때 (저장값에 옮겨 적는다: `GameState`)
  ValueChanged<bool>? onChanged;

  /// 산 기록이 있는지 (캐시 포함)
  bool get unlocked => _unlocked;

  /// 모든 단계·아이템·탈것을 쓸 수 있는지 (결제가 꺼져 있으면 항상 true)
  bool get fullAccess => !enabled || _unlocked;

  UnlockFlow get flow => _flow;

  /// 스토어가 준 현지 가격 글자 ("₩4,900", "$3.99"). 아직 모르면 null. 하드코딩하지 않는다.
  String? get price => _product?.price;

  /// 스토어에 연결했는지 (start 이후)
  bool get started => _store != null;

  /// 기기에 저장해 둔 해금 값으로 시작한다 (스토어에 묻기 전)
  void restoreCached(bool unlocked) {
    if (_unlocked == unlocked) return;
    _unlocked = unlocked;
    if (unlocked) _flow = UnlockFlow.unlocked;
    notifyListeners();
  }

  /// 스토어에 연결한다. 결제가 꺼져 있으면 아무것도 하지 않는다 (in_app_purchase 초기화도 안 함).
  /// 실패해도 예외를 밖으로 던지지 않는다.
  Future<void> start() async {
    if (!enabled || _store != null) return;
    _setFlow(_unlocked ? UnlockFlow.unlocked : UnlockFlow.connecting);
    try {
      final store = _store = _storeFactory();
      _sub = store.purchases.listen(_onPurchases, onError: (_) {});
      if (!await store.isAvailable()) {
        if (!_unlocked) _setFlow(UnlockFlow.unavailable);
        return;
      }
      _product = await store.product(productId);
      if (!_unlocked) {
        _setFlow(_product == null ? UnlockFlow.unavailable : UnlockFlow.ready);
        if (_autoRestore && _product != null) await store.restore();
      } else {
        notifyListeners();
      }
    } catch (_) {
      if (!_unlocked) _setFlow(UnlockFlow.unavailable);
    }
  }

  /// 부모용 결제 화면이 열릴 때: 아직 값을 못 받았으면 다시 연결해 본다
  Future<void> refresh() async {
    if (!enabled) return;
    if (_store == null) return start();
    if (_product != null || _unlocked) return;
    _setFlow(UnlockFlow.connecting);
    try {
      final store = _store!;
      if (await store.isAvailable()) _product = await store.product(productId);
    } catch (_) {
      _product = null;
    }
    if (!_unlocked) {
      _setFlow(_product == null ? UnlockFlow.unavailable : UnlockFlow.ready);
    }
  }

  /// 결제 창을 연다 (부모 확인을 지난 부모용 화면에서만 부른다)
  Future<void> buy() async {
    if (!enabled || _unlocked) return;
    final store = _store, product = _product;
    if (store == null || product == null) {
      _setFlow(UnlockFlow.unavailable);
      return;
    }
    _setFlow(UnlockFlow.purchasing);
    try {
      if (!await store.buy(product)) _setFlow(UnlockFlow.failed);
    } catch (_) {
      _setFlow(UnlockFlow.failed);
    }
  }

  /// 구매 복원 (재설치·기기 변경). 산 기록은 [_onPurchases]로 들어온다.
  Future<void> restore() async {
    if (!enabled) return;
    if (_unlocked) {
      _setFlow(UnlockFlow.unlocked);
      return;
    }
    if (_store == null) await start();
    // 상품 값을 못 받았어도 복원은 해 본다 (값 조회만 실패했을 수 있다)
    final store = _store;
    if (store == null || _unlocked) return;
    _setFlow(UnlockFlow.restoring);
    try {
      await store.restore();
      if (restoreGrace > Duration.zero) await Future.delayed(restoreGrace);
      if (!_unlocked && _flow == UnlockFlow.restoring) {
        _setFlow(UnlockFlow.nothingToRestore);
      }
    } catch (_) {
      if (!_unlocked) _setFlow(UnlockFlow.unavailable);
    }
  }

  Future<void> _onPurchases(List<StorePurchase> list) async {
    for (final p in list) {
      if (p.productId != productId) continue;
      switch (p.status) {
        case StorePurchaseStatus.pending:
          if (!_unlocked) _setFlow(UnlockFlow.pending);
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          _grant();
        case StorePurchaseStatus.canceled:
          if (!_unlocked) _setFlow(UnlockFlow.canceled);
        case StorePurchaseStatus.error:
          if (!_unlocked) _setFlow(UnlockFlow.failed);
      }
      // 안드로이드는 3일 안에 확인(acknowledge)하지 않으면 자동 환불된다
      if (p.needsComplete) {
        try {
          await _store?.complete(p);
        } catch (_) {}
      }
    }
  }

  void _grant() {
    final wasUnlocked = _unlocked;
    _unlocked = true;
    _flow = UnlockFlow.unlocked;
    notifyListeners();
    if (!wasUnlocked) onChanged?.call(true);
  }

  void _setFlow(UnlockFlow f) {
    if (_flow == f) return;
    _flow = f;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
