// 1회 전체 해금 미리보기 (결제 기능 플래그를 테스트에서만 켠 화면, 가짜 스토어).
// shots/billing_stage_<폭>.png        : 단계 고르기 (숫자 4단계부터 해금 필요, 자물쇠만)
// shots/billing_shop_<폭>.png         : 상점 공주 테마 (잠긴 옷, 사기 버튼 자리에 자물쇠)
// shots/billing_unlock_<언어>_<상태>_<폭>.png : 부모용 결제 화면 (ready·pending·offline·done)
// shots/billing_settings_<언어>_<폭>.png : 설정 맨 위 "전체 놀이 열기" 칸
// 실행: flutter test test_preview/billing_preview_test.dart --update-goldens
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/screens/unlock_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/billing_store.dart';
import 'package:alokdalok/services/entitlement.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fixtures/fake_billing.dart';
import '../test/l10n_screens.dart';

Future<GameState> _state(FakeBillingStore store, {SaveData? data}) async {
  final storage = MemoryStorage()
    ..raw =
        (data ??
                (SaveData.initial()
                  ..cameraNoticeSeen = true
                  ..coins = 140
                  ..numberStageUnlocked = 5
                  ..numberStageCleared = {1, 2, 3, 4}
                  ..owned = {'helmet_robot'}
                  ..equipped = {ItemSlot.head: 'helmet_robot'}
                  ..keepStages = {'number': 1}))
            .encode();
  final s = GameState(
    storage: storage,
    audio: RecordingAudio(),
    entitlement: Entitlement(
      enabled: true,
      storeFactory: () => store,
      restoreGrace: Duration.zero,
      autoRestore: false,
    ),
  );
  await s.load();
  await s.setNickname('별이');
  return s;
}

Future<void> _pump(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder _pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

void main() {
  tearDown(() => L10n.use(AppLanguage.fallback));

  for (final size in l10nSizes) {
    final w = size.width.toInt();

    Future<void> setSize(WidgetTester t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    testWidgets('stage $w', (t) async {
      await setSize(t);
      final s = await _state(FakeBillingStore());
      await t.pumpWidget(
        l10nApp(s, const StagePicker(game: GameKind.number), 'ko'),
      );
      await _pump(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/billing_stage_$w.png'),
      );
    });

    testWidgets('shop $w', (t) async {
      await setSize(t);
      final s = await _state(FakeBillingStore());
      await t.pumpWidget(l10nApp(s, const ShopScreen(), 'ko'));
      await _pump(t);
      for (var i = 0;
          i < 5 && _pressable(OutfitTheme.princess.label).evaluate().isEmpty;
          i++) {
        await t.tap(_pressable('다음 쪽').first);
        await _pump(t, 4);
      }
      await t.tap(_pressable(OutfitTheme.princess.label));
      await _pump(t);
      final crown = ItemCatalog.byId('crown_gold')!;
      await t.tap(_pressable('${crown.name}, 잠겨 있음'));
      await _pump(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/billing_shop_$w.png'),
      );
    });

    for (final code in ['ko', 'en']) {
      for (final state in ['ready', 'pending', 'offline', 'done']) {
        testWidgets('unlock $code $state $w', (t) async {
          await setSize(t);
          final store = FakeBillingStore(
            available: state != 'offline',
            price: code == 'ko' ? '₩4,900' : r'$3.99',
          );
          if (state == 'pending') store.nextBuy = StorePurchaseStatus.pending;
          final s = await _state(store);
          await t.pumpWidget(l10nApp(s, const UnlockScreen(), code));
          await _pump(t);
          if (state == 'pending' || state == 'done') {
            await s.entitlement.buy();
            await _pump(t);
          }
          expect(t.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp).first,
            matchesGoldenFile('shots/billing_unlock_${code}_${state}_$w.png'),
          );
        });
      }

      testWidgets('settings $code $w', (t) async {
        await setSize(t);
        final s = await _state(FakeBillingStore());
        await t.pumpWidget(l10nApp(s, const SettingsScreen(), code));
        await _pump(t);
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFile('shots/billing_settings_${code}_$w.png'),
        );
      });
    }
  }
}
