import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// 스토어(Google Play 결제·App Store) 얇은 포장. [Entitlement]가 이것만 보고, 테스트는 가짜를 넣는다.
///
/// 결제 기능 플래그가 꺼져 있으면 아무도 이 객체를 만들지 않는다 (in_app_purchase 초기화 없음).
abstract class BillingStore {
  /// 스토어에 연결할 수 있는지 (오프라인이거나 스토어 앱이 없으면 false)
  Future<bool> isAvailable();

  /// 산 것·복원한 것·보류·취소·실패 알림
  Stream<List<StorePurchase>> get purchases;

  /// 상품 정보 (현지 가격 글자 포함). 스토어에 없으면 null.
  Future<StoreProduct?> product(String id);

  /// 비소모성 상품 결제 창을 연다. 결과는 [purchases]로 온다.
  Future<bool> buy(StoreProduct product);

  /// 예전에 산 비소모성 상품을 다시 받는다. 결과는 [purchases]로 온다.
  Future<void> restore();

  /// 결제를 마무리한다 (안드로이드 acknowledge). 하지 않으면 3일 뒤 자동 환불된다.
  Future<void> complete(StorePurchase purchase);
}

/// 상품 하나
class StoreProduct {
  const StoreProduct({required this.id, required this.price, this.raw});

  final String id;

  /// 스토어가 준 현지 가격 글자 (예: "₩4,900", "$3.99")
  final String price;

  /// 스토어 원본 객체 (in_app_purchase `ProductDetails`)
  final Object? raw;
}

enum StorePurchaseStatus { pending, purchased, restored, canceled, error }

/// 결제 알림 하나
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.needsComplete = false,
    this.raw,
  });

  final String productId;
  final StorePurchaseStatus status;
  final bool needsComplete;

  /// 스토어 원본 객체 (in_app_purchase `PurchaseDetails`)
  final Object? raw;
}

/// 실제 앱에서 쓰는 스토어 (결제가 켜져 있을 때만 만들어진다)
BillingStore defaultBillingStore() => IapBillingStore();

/// in_app_purchase 패키지로 만든 스토어
class IapBillingStore implements BillingStore {
  IapBillingStore([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Stream<List<StorePurchase>> get purchases => _iap.purchaseStream.map(
    (list) => [
      for (final p in list)
        StorePurchase(
          productId: p.productID,
          status: switch (p.status) {
            PurchaseStatus.pending => StorePurchaseStatus.pending,
            PurchaseStatus.purchased => StorePurchaseStatus.purchased,
            PurchaseStatus.restored => StorePurchaseStatus.restored,
            PurchaseStatus.canceled => StorePurchaseStatus.canceled,
            PurchaseStatus.error => StorePurchaseStatus.error,
          },
          needsComplete: p.pendingCompletePurchase,
          raw: p,
        ),
    ],
  );

  @override
  Future<StoreProduct?> product(String id) async {
    final r = await _iap.queryProductDetails({id});
    for (final d in r.productDetails) {
      if (d.id == id) return StoreProduct(id: d.id, price: d.price, raw: d);
    }
    return null;
  }

  @override
  Future<bool> buy(StoreProduct product) {
    final details = product.raw;
    if (details is! ProductDetails) return Future.value(false);
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(StorePurchase purchase) async {
    final p = purchase.raw;
    if (p is PurchaseDetails) await _iap.completePurchase(p);
  }
}
