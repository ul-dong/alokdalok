import 'package:flutter/foundation.dart';

/// 기능 플래그. 결제(1회 전체 해금)는 모두 여기서 켜고 끈다 (`docs/MONETIZATION.md`).
///
/// **기본은 꺼짐.** 꺼져 있으면:
/// - 스토어(in_app_purchase)를 초기화하지도, 연결하지도 않는다 (런타임 영향 0).
/// - 모든 단계·아이템·탈것이 지금처럼 열려 있다 (전부 해금된 것처럼 동작).
/// - 설정에 결제 칸이 보이지 않는다.
///
/// 켜는 것은 Play Console·App Store Connect에 상품을 등록하고, 부모용 화면과 데이터 안전성 신고를
/// 마친 뒤 사용자가 결정한다. 결제를 켠 채로 머지하지 않는다.
const bool kBillingEnabled = false;

/// 앱에서 읽는 실제 값. 웹은 스토어가 없어서 항상 꺼짐(전부 열림).
abstract final class Features {
  static bool? _billingOverride;

  /// 결제를 쓰는지. 꺼져 있으면 전부 해금된 것처럼 동작한다.
  static bool get billing => _billingOverride ?? (kBillingEnabled && !kIsWeb);

  /// 테스트·미리보기 그림 전용: 결제가 켜진 화면을 그려 볼 때만 쓴다 (null이면 원래 값).
  @visibleForTesting
  static set billingOverride(bool? on) => _billingOverride = on;
}
