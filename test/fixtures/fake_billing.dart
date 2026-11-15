// 가짜 스토어 (결제 테스트·미리보기 그림 전용). 실제 in_app_purchase는 건드리지 않는다.
import 'dart:async';

import 'package:alokdalok/services/billing_store.dart';
import 'package:alokdalok/services/entitlement.dart';

class FakeBillingStore implements BillingStore {
  FakeBillingStore({
    this.available = true,
    this.price = '₩4,900',
    this.owned = false,
    this.throwOnConnect = false,
  });

  /// 스토어에 연결할 수 있는지 (false = 오프라인)
  bool available;

  /// 상품 값 (null = 스토어에 상품이 없음)
  String? price;

  /// 이 계정으로 이미 산 적이 있는지 (복원하면 돌려준다)
  bool owned;

  /// 연결할 때 예외를 던지는 스토어 (플러그인 오류 흉내)
  bool throwOnConnect;

  /// 결제 창을 열면 바로 이 결과를 보낸다 (null이면 아무것도 보내지 않음 = 창이 떠 있는 상태)
  StorePurchaseStatus? nextBuy = StorePurchaseStatus.purchased;

  int connects = 0, buys = 0, restores = 0, completes = 0;

  final _ctrl = StreamController<List<StorePurchase>>.broadcast();

  @override
  Stream<List<StorePurchase>> get purchases => _ctrl.stream;

  /// 스토어가 나중에 알려 주는 결과 (보류 → 승인 등)
  void push(StorePurchaseStatus status, {bool needsComplete = true}) =>
      _ctrl.add([
        StorePurchase(
          productId: Entitlement.productId,
          status: status,
          needsComplete: needsComplete,
        ),
      ]);

  @override
  Future<bool> isAvailable() async {
    connects++;
    if (throwOnConnect) throw StateError('billing unavailable');
    return available;
  }

  @override
  Future<StoreProduct?> product(String id) async {
    if (!available || price == null) return null;
    return StoreProduct(id: id, price: price!);
  }

  @override
  Future<bool> buy(StoreProduct product) async {
    buys++;
    final s = nextBuy;
    if (s != null) {
      if (s == StorePurchaseStatus.purchased) owned = true;
      scheduleMicrotask(() => push(s));
    }
    return true;
  }

  @override
  Future<void> restore() async {
    restores++;
    if (owned) scheduleMicrotask(() => push(StorePurchaseStatus.restored));
  }

  @override
  Future<void> complete(StorePurchase purchase) async => completes++;
}
