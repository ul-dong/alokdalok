// 1회 전체 해금 결제 골격 (2026-11-15, docs/MONETIZATION.md). 기능 플래그 kBillingEnabled는 기본 꺼짐.
import 'dart:convert';
import 'dart:io';

import 'package:alokdalok/core/economy.dart';
import 'package:alokdalok/core/features.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/screens/unlock_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/backup_code.dart';
import 'package:alokdalok/services/billing_store.dart';
import 'package:alokdalok/services/entitlement.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/item_widgets.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fake_billing.dart';
import 'l10n_screens.dart';

/// 결제가 켜진 GameState (가짜 스토어). [data]가 없으면 새로 설치한 상태.
Future<(GameState, FakeBillingStore, MemoryStorage)> billingState({
  SaveData? data,
  FakeBillingStore? store,
  MemoryStorage? storage,
  bool autoRestore = false,
}) async {
  final st =
      storage ??
      (MemoryStorage()
        ..raw = (data ?? (SaveData.initial()..cameraNoticeSeen = true))
            .encode());
  final fake = store ?? FakeBillingStore();
  final s = GameState(
    storage: st,
    audio: RecordingAudio(),
    entitlement: Entitlement(
      enabled: true,
      storeFactory: () => fake,
      restoreGrace: Duration.zero,
      autoRestore: autoRestore,
    ),
  );
  await s.load();
  await _flush();
  return (s, fake, st);
}

/// 스토어 연결(뒤에서 도는 비동기)이 끝나게 한다
Future<void> _flush() async {
  // 타이머 없이 마이크로태스크만 돌린다 (testWidgets의 가짜 시계에서도 멈추지 않게)
  for (var i = 0; i < 50; i++) {
    await Future<void>.value();
  }
}

/// 다 깬 저장값 (모든 놀이 마지막 단계까지 열림)
SaveData _allOpen() => SaveData.initial()
  ..cameraNoticeSeen = true
  ..numberStageUnlocked = 8
  ..colorStageUnlocked = 5
  ..shapeStageUnlocked = 5
  ..sizeStageUnlocked = 5
  ..matchStageUnlocked = 5;

Widget _wrap(GameState s, Widget home) => l10nApp(s, home, 'ko');

Future<void> _size(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder _pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

Future<void> _solveGate(WidgetTester t) async {
  final q = t.widget<Text>(find.byKey(ParentalGate.questionKey)).data!;
  for (final d in '${ParentalGate.answerOf(q)}'.split('')) {
    await t.tap(_pressable('숫자 $d'));
    await t.pump(const Duration(milliseconds: 50));
  }
  await _settle(t, 800);
}

/// 화면 글자 전체 (가격·결제 글자가 아이 화면에 없는지 본다)
String _allText(WidgetTester t) => [
  for (final e in find.byType(Text).evaluate())
    (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
].join('\n');

void main() {
  group('플래그 꺼짐 (기본) = 지금과 똑같다', () {
    test('kBillingEnabled는 꺼져 있고, 기본 GameState는 결제를 쓰지 않는다', () async {
      expect(kBillingEnabled, isFalse);
      expect(Features.billing, isFalse);
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      expect(s.entitlement.enabled, isFalse);
      expect(s.fullAccess, isTrue);
      expect(s.entitlement.started, isFalse, reason: '스토어에 연결하지 않는다');
    });

    test('꺼져 있으면 스토어를 만들지도 연결하지도 않는다 (in_app_purchase 초기화 없음)', () async {
      var made = 0;
      final e = Entitlement(
        enabled: false,
        storeFactory: () {
          made++;
          return FakeBillingStore();
        },
      );
      await e.start();
      await e.refresh();
      await e.buy();
      await e.restore();
      expect(made, 0);
      expect(e.fullAccess, isTrue);
      expect(e.flow, UnlockFlow.idle);
    });

    test('모든 단계·아이템·탈것이 열려 있고, 지켜 줄 단계도 정하지 않는다', () async {
      final storage = MemoryStorage()..raw = _allOpen().encode();
      final s = GameState(storage: storage, audio: RecordingAudio());
      await s.load();
      for (final g in GameKind.values) {
        expect(s.unlockedStage(g), g.stageCount, reason: '$g');
        expect(s.stageCap(g), g.stageCount);
        for (var id = 1; id <= g.stageCount; id++) {
          expect(s.stageNeedsUnlock(g, id), isFalse);
        }
      }
      for (final i in ItemCatalog.all) {
        expect(s.itemLocked(i.id), isFalse, reason: i.id);
      }
      for (final v in Vehicles.all) {
        expect(s.vehicleLocked(v.id), isFalse, reason: v.id);
      }
      expect(jsonDecode(storage.raw!)['keepStages'], isNull);
    });

    test('코인으로 아무 옷·탈것이나 지금처럼 산다', () async {
      final storage = MemoryStorage()
        ..raw = (SaveData.initial()..coins = 200).encode();
      final s = GameState(storage: storage, audio: RecordingAudio());
      await s.load();
      expect(await s.purchase('crown_gold'), PurchaseResult.ok);
      expect(await s.buyVehicle('rocket'), PurchaseResult.ok);
    });

    testWidgets('설정에 결제 칸이 없고, 안내 글은 예전 그대로', (t) async {
      await _size(t, const Size(844, 390));
      final s = await l10nState('ko');
      await t.pumpWidget(_wrap(s, const SettingsScreen()));
      await _settle(t);
      expect(find.byKey(SettingsScreen.unlockKey), findsNothing);
      expect(find.text('전체 놀이 열기'), findsNothing);
      expect(find.text('회원가입, 서버, 광고, 추적, 현금 결제가 없습니다.'), findsOneWidget);
    });

    testWidgets('잠긴 단계를 누르면 예전처럼 흔들고 말한다 (부모 확인 없음)', (t) async {
      await _size(t, const Size(844, 390));
      final s = await l10nState('ko');
      await t.pumpWidget(_wrap(s, const StagePicker(game: GameKind.number)));
      await _settle(t);
      await t.tap(_pressable('2단계 아직 열리지 않음'));
      await _settle(t);
      expect(find.byType(ParentalGate), findsNothing);
      expect(
        (s.audio as RecordingAudio).spoken,
        contains(StagePicker.lockedLine),
      );
    });
  });

  group('플래그 켜짐 + 해금 없음: 무료 범위만', () {
    test('무료 범위: 숫자 1~3, 색깔 1~2, 모양·크기·짝 1단계', () async {
      final storage = MemoryStorage()
        ..raw = (_allOpen()..keepStages = {for (final g in GameKind.values) g.name: 1})
            .encode();
      final (s, _, _) = await billingState(storage: storage);
      expect(s.fullAccess, isFalse);
      expect(s.unlockedStage(GameKind.number), 3);
      expect(s.unlockedStage(GameKind.color), 2);
      expect(s.unlockedStage(GameKind.shape), 1);
      expect(s.unlockedStage(GameKind.size), 1);
      expect(s.unlockedStage(GameKind.match), 1);
      expect(s.progressStage(GameKind.number), 8, reason: '깬 기록은 그대로');
      expect(s.stageNeedsUnlock(GameKind.number, 3), isFalse);
      expect(s.stageNeedsUnlock(GameKind.number, 4), isTrue);
      expect(s.stageNeedsUnlock(GameKind.color, 3), isTrue);
    });

    test('새로 설치: 지켜 줄 단계는 모두 1단계로 정해 저장한다', () async {
      final (s, _, storage) = await billingState();
      expect(jsonDecode(storage.raw!)['keepStages'], {
        for (final g in GameKind.values) g.name: 1,
      });
      expect(s.unlockedStage(GameKind.number), 1);
      expect(s.stageCap(GameKind.number), 3);
    });

    test('기존 사용자: 결제가 처음 켜질 때 이미 열린 단계는 계속 논다', () async {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..numberStageUnlocked = 6
        ..shapeStageUnlocked = 4;
      final (s, _, storage) = await billingState(data: d);
      expect(s.unlockedStage(GameKind.number), 6);
      expect(s.unlockedStage(GameKind.shape), 4);
      expect(s.unlockedStage(GameKind.color), 1);
      expect(s.stageNeedsUnlock(GameKind.number, 6), isFalse);
      expect(s.stageNeedsUnlock(GameKind.number, 7), isTrue);
      expect(jsonDecode(storage.raw!)['keepStages']['number'], 6);
      // 한 번 정하면 더 깨도 바뀌지 않는다 (다음 실행에서도)
      final again = GameState(
        storage: storage,
        audio: RecordingAudio(),
        entitlement: Entitlement(
          enabled: true,
          storeFactory: () => FakeBillingStore(available: false),
        ),
      );
      await again.load();
      expect(again.stageCap(GameKind.number), 6);
    });

    test('무료 마지막 단계를 깨면 진행은 기억하지만 "열렸어요"라고 하지 않는다', () async {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..numberStageUnlocked = 3
        ..keepStages = {'number': 1};
      final (s, _, _) = await billingState(data: d);
      final r = await s.completeSession(GameKind.number, 3);
      expect(r.unlockedStage, isNull);
      expect(s.progressStage(GameKind.number), 4);
      expect(s.unlockedStage(GameKind.number), 3);
      expect(s.replayStage(GameKind.number), 3, reason: '또 하기도 열린 단계까지만');
      // 코인 보상은 그대로 (틀려도·잠겨도 줄지 않는다)
      expect(r.total, greaterThan(0));
    });

    test('잠긴 옷·탈것은 코인이 많아도 살 수 없다 (코인 그대로)', () async {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..coins = Economy.maxCoins;
      final (s, _, _) = await billingState(data: d);
      expect(await s.purchase('crown_gold'), PurchaseResult.locked);
      expect(await s.buyVehicle('rocket'), PurchaseResult.locked);
      expect(s.coins, Economy.maxCoins);
      // 무료 범위: 로봇 옷과 열기구
      expect(await s.purchase('helmet_robot'), PurchaseResult.ok);
      expect(await s.buyVehicle('balloon'), PurchaseResult.ok);
      expect(s.itemLocked('helmet_robot'), isFalse);
      expect(s.vehicleLocked('balloon'), isFalse);
    });

    test('이미 가진 옷·탈것은 해금과 상관없이 입고 타고 꾸민다', () async {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..coins = 100
        ..owned = {'crown_gold', 'rocket'};
      final (s, _, _) = await billingState(data: d);
      expect(s.itemLocked('crown_gold'), isFalse);
      expect(s.vehicleLocked('rocket'), isFalse);
      expect(await s.equip('crown_gold'), isTrue);
      await s.setRide('rocket');
      expect(s.ride, 'rocket');
      expect(await s.buyPaint('rocket', 'paint_red'), PurchaseResult.ok);
    });

    for (final size in l10nSizes) {
      testWidgets(
        '잠긴 단계: 자물쇠만 보이고, 누르면 놀이 대신 부모 확인 (${size.width.toInt()})',
        (t) async {
          await _size(t, size);
          final d = SaveData.initial()
            ..cameraNoticeSeen = true
            ..numberStageUnlocked = 4
            ..keepStages = {'number': 1};
          final (s, _, _) = await billingState(data: d);
          await t.pumpWidget(
            _wrap(s, const StagePicker(game: GameKind.number)),
          );
          await _settle(t);
          expect(t.takeException(), isNull);
          final locked = _pressable('4단계 아직 열리지 않음');
          expect(locked, findsOneWidget);
          expect(
            find.descendant(of: locked, matching: find.byType(BigLock)),
            findsOneWidget,
          );
          // 아이 화면에는 가격·결제 글자가 없다
          final text = _allText(t);
          expect(text, isNot(contains('₩')));
          expect(text, isNot(contains('결제')));
          expect(text, isNot(contains('4,900')));
          // 누르면: 놀이가 시작되지 않고 부모 확인
          await t.tap(locked);
          await _settle(t);
          expect(find.byType(NumberGameScreen), findsNothing);
          expect(find.byType(ParentalGate), findsOneWidget);
          await _solveGate(t);
          expect(find.byType(UnlockScreen), findsOneWidget);
          expect(find.byType(NumberGameScreen), findsNothing);
          expect(t.takeException(), isNull);
        },
      );
    }

    testWidgets('부모 확인을 꺼 두었어도 결제 화면 앞에서는 항상 묻는다', (t) async {
      await _size(t, const Size(844, 390));
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..parentGateOn = false
        ..numberStageUnlocked = 4
        ..keepStages = {'number': 1};
      final (s, _, _) = await billingState(data: d);
      await t.pumpWidget(_wrap(s, const StagePicker(game: GameKind.number)));
      await _settle(t);
      await t.tap(_pressable('4단계 아직 열리지 않음'));
      await _settle(t);
      expect(find.byType(ParentalGate), findsOneWidget);
      expect(find.byType(UnlockScreen), findsNothing);
    });

    testWidgets('부모 확인을 닫으면 놀이도 결제 화면도 열리지 않는다', (t) async {
      await _size(t, const Size(844, 390));
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..keepStages = {'color': 1};
      final (s, _, _) = await billingState(data: d);
      await t.pumpWidget(_wrap(s, const StagePicker(game: GameKind.color)));
      await _settle(t);
      // 3단계는 아직 깨지 못했지만 해금이 있어야 하는 단계: 흔들기 대신 부모 확인
      await t.tap(_pressable('3단계 아직 열리지 않음'));
      await _settle(t);
      expect(find.byType(ParentalGate), findsOneWidget);
      await t.tap(_pressable('닫기'));
      await _settle(t);
      expect(find.byType(ParentalGate), findsNothing);
      expect(find.byType(UnlockScreen), findsNothing);
      // 무료 범위 안의 아직 안 깬 단계는 예전처럼 흔든다
      await t.tap(_pressable('2단계 아직 열리지 않음'));
      await _settle(t);
      expect(find.byType(ParentalGate), findsNothing);
    });

    for (final size in l10nSizes) {
      testWidgets('상점: 잠긴 옷은 가격 대신 자물쇠, 사기 버튼 대신 자물쇠 (${size.width.toInt()})', (
        t,
      ) async {
        await _size(t, size);
        final d = SaveData.initial()
          ..cameraNoticeSeen = true
          ..coins = 500
          ..keepStages = {};
        final (s, _, _) = await billingState(data: d);
        await t.pumpWidget(_wrap(s, const ShopScreen()));
        await _settle(t);
        expect(t.takeException(), isNull);
        // 첫 탭(로봇)은 무료: 가격표가 있다
        expect(find.byType(PriceTag), findsWidgets);
        // 공주 탭으로
        // 작은 화면은 테마 탭도 화살표로 넘긴다
        for (var i = 0;
            i < 5 && _pressable(OutfitTheme.princess.label).evaluate().isEmpty;
            i++) {
          await t.tap(_pressable('다음 쪽').first);
          await _settle(t);
        }
        await t.tap(_pressable(OutfitTheme.princess.label));
        await _settle(t);
        expect(find.byType(PriceTag), findsNothing, reason: '잠긴 옷에 가격 없음');
        final crown = ItemCatalog.byId('crown_gold')!;
        await t.tap(_pressable('${crown.name}, 잠겨 있음'));
        await _settle(t);
        expect(_pressable('부모님께 보여 주세요'), findsOneWidget);
        expect(t.takeException(), isNull);
        expect(_allText(t), isNot(contains('₩')));
        await t.tap(_pressable('부모님께 보여 주세요'));
        await _settle(t);
        expect(find.byType(ParentalGate), findsOneWidget);
        expect(s.owns('crown_gold'), isFalse);
        expect(s.coins, 500);
      });
    }
  });

  group('구매', () {
    test('구매 성공 → 저장 → 앱을 다시 켜도(오프라인이어도) 유지', () async {
      final (s, store, storage) = await billingState();
      expect(s.entitlement.flow, UnlockFlow.ready);
      expect(s.entitlement.price, '₩4,900');
      await s.entitlement.buy();
      await _flush();
      expect(store.buys, 1);
      expect(s.fullAccess, isTrue);
      expect(s.entitlement.flow, UnlockFlow.unlocked);
      expect(store.completes, 1, reason: '안드로이드 acknowledge');
      expect(jsonDecode(storage.raw!)['unlocked'], isTrue);
      for (final g in GameKind.values) {
        expect(s.stageCap(g), g.stageCount);
      }

      // 다시 켬: 스토어에 닿지 못해도 캐시로 열려 있다
      final (again, _, _) = await billingState(
        storage: storage,
        store: FakeBillingStore(available: false),
      );
      expect(again.fullAccess, isTrue);
      expect(again.entitlement.flow, UnlockFlow.unlocked);
      expect(again.itemLocked('crown_gold'), isFalse);
    });

    test('보류(보호자 승인 대기) → 승인되면 저절로 열린다', () async {
      final store = FakeBillingStore()..nextBuy = StorePurchaseStatus.pending;
      final (s, _, storage) = await billingState(store: store);
      await s.entitlement.buy();
      await _flush();
      expect(s.entitlement.flow, UnlockFlow.pending);
      expect(s.fullAccess, isFalse);
      expect(jsonDecode(storage.raw!)['unlocked'], isFalse);
      store.push(StorePurchaseStatus.purchased);
      await _flush();
      expect(s.fullAccess, isTrue);
      expect(jsonDecode(storage.raw!)['unlocked'], isTrue);
    });

    test('취소·실패는 잠긴 그대로', () async {
      final store = FakeBillingStore()..nextBuy = StorePurchaseStatus.canceled;
      final (s, _, _) = await billingState(store: store);
      await s.entitlement.buy();
      await _flush();
      expect(s.entitlement.flow, UnlockFlow.canceled);
      expect(s.fullAccess, isFalse);
      store.nextBuy = StorePurchaseStatus.error;
      await s.entitlement.buy();
      await _flush();
      expect(s.entitlement.flow, UnlockFlow.failed);
      expect(s.fullAccess, isFalse);
    });

    test('구매 복원: 산 기록이 있으면 열리고, 없으면 "산 기록이 없어요"', () async {
      final (s, _, _) = await billingState(
        store: FakeBillingStore(owned: true),
      );
      expect(s.fullAccess, isFalse);
      await s.entitlement.restore();
      await _flush();
      expect(s.fullAccess, isTrue);

      final (n, _, _) = await billingState();
      await n.entitlement.restore();
      await _flush();
      expect(n.fullAccess, isFalse);
      expect(n.entitlement.flow, UnlockFlow.nothingToRestore);
    });

    test('재설치(안드로이드): 앱을 열면 조용히 복원한다', () async {
      final (s, store, _) = await billingState(
        store: FakeBillingStore(owned: true),
        autoRestore: true,
      );
      expect(store.restores, 1);
      expect(s.fullAccess, isTrue);
    });

    test('기록 지우기·백업 복구를 해도 산 해금은 이 기기에 남는다', () async {
      final (s, _, storage) = await billingState();
      await s.entitlement.buy();
      await _flush();
      final code = s.exportBackup();
      expect(jsonDecode(utf8.decode(base64Url.decode(_body(code))))['unlocked'],
          isNull, reason: '백업 글자에는 해금을 넣지 않는다');
      await s.resetAll();
      expect(jsonDecode(storage.raw!)['unlocked'], isTrue);
      expect(await s.restoreBackup(code), isNull);
      expect(jsonDecode(storage.raw!)['unlocked'], isTrue);
    });
  });

  group('스토어 연결 실패', () {
    test('오프라인: 캐시된 해금 유지, 멈추지 않음', () async {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..unlocked = true;
      final (s, store, _) = await billingState(
        data: d,
        store: FakeBillingStore(available: false),
      );
      expect(store.connects, 1);
      expect(s.fullAccess, isTrue);
      expect(s.entitlement.flow, UnlockFlow.unlocked);
    });

    test('플러그인 오류(예외)도 밖으로 던지지 않는다', () async {
      final (s, _, _) = await billingState(
        store: FakeBillingStore(throwOnConnect: true),
      );
      expect(s.fullAccess, isFalse);
      expect(s.entitlement.flow, UnlockFlow.unavailable);
      await s.entitlement.buy();
      await s.entitlement.restore();
      await s.entitlement.refresh();
      expect(s.fullAccess, isFalse);

      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..unlocked = true;
      final (u, _, _) = await billingState(
        data: d,
        store: FakeBillingStore(throwOnConnect: true),
      );
      expect(u.fullAccess, isTrue);
    });

    testWidgets('부모용 화면: 연결할 수 없으면 가격 없이 "다시 연결"', (t) async {
      await _size(t, const Size(844, 390));
      final (s, store, _) = await billingState(
        store: FakeBillingStore(available: false),
      );
      await t.pumpWidget(_wrap(s, const UnlockScreen()));
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(find.byKey(UnlockScreen.buyKey), findsNothing);
      expect(find.text('다시 연결'), findsOneWidget);
      // 다시 연결되면 스토어 값으로 사기 버튼이 생긴다
      store.available = true;
      await t.tap(find.text('다시 연결'));
      await _settle(t);
      expect(find.text('₩4,900에 모두 열기'), findsOneWidget);
    });
  });

  group('코인으로 결제하는 길은 없다', () {
    test('코인으로 모든 것을 사 봐도 해금은 생기지 않는다', () async {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..coins = Economy.maxCoins;
      final (s, store, _) = await billingState(data: d);
      for (final i in ItemCatalog.all) {
        await s.purchase(i.id);
      }
      for (final v in Vehicles.all) {
        await s.buyVehicle(v.id);
        for (final p in Vehicles.paints) {
          await s.buyPaint(v.id, p.id);
        }
      }
      expect(s.fullAccess, isFalse);
      expect(s.entitlement.unlocked, isFalse);
      expect(store.buys, 0);
    });

    test('해금 코드는 코인을 모르고, 결제 창은 부모용 화면만 연다', () {
      String read(String p) => File(p).readAsStringSync();
      for (final p in [
        'lib/services/entitlement.dart',
        'lib/services/billing_store.dart',
      ]) {
        final src = read(p);
        expect(src.contains('coins'), isFalse, reason: p);
        expect(src.contains('Economy'), isFalse, reason: p);
      }
      final callers = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (RegExp(r'\b(entitlement|_ent)\.buy\(|_ent\.buy\b').hasMatch(
          read(f.path),
        )) {
          callers.add(f.path.split(Platform.pathSeparator).last);
        }
      }
      expect(callers, ['unlock_screen.dart']);
      // 코인을 바꾸는 GameState 함수는 해금을 건드리지 않는다
      final gs = read('lib/services/game_state.dart');
      expect(RegExp(r'_d\.unlocked\s*=(?!=)').allMatches(gs).length, 1);
    });
  });

  group('저장 v10', () {
    test('v9 → v10: 산 기록 없음, 지켜 줄 단계는 결제가 켜질 때 정한다', () {
      final json = SaveData.migrate({
        'version': 9,
        'coins': 42,
        'numberStageUnlocked': 5,
        'keepStages': {'number': 8},
        'unlocked': true,
      });
      expect(json['version'], 10);
      expect(json['unlocked'], isFalse);
      expect(json.containsKey('keepStages'), isFalse);
      final d = SaveData.fromJson(json);
      expect(d.unlocked, isFalse);
      expect(d.keepStages, isNull);
      expect(d.coins, 42);
      expect(d.numberStageUnlocked, 5);
    });

    test('새로 설치: 산 기록 없음', () {
      final d = SaveData.decode(null);
      expect(SaveData.currentVersion, 10);
      expect(d.unlocked, isFalse);
      expect(d.keepStages, isNull);
    });

    test('저장하고 다시 읽어도 같고, 이상한 값은 걸러 낸다', () {
      final d = SaveData.initial()
        ..unlocked = true
        ..keepStages = {'number': 6, 'color': 2};
      final back = SaveData.decode(d.encode());
      expect(back.unlocked, isTrue);
      expect(back.keepStages, {'number': 6, 'color': 2});
      final bad = SaveData.fromJson({
        'version': 10,
        'unlocked': 'yes',
        'keepStages': {'number': 99, 'nope': 3, 'color': 'x'},
      });
      expect(bad.unlocked, isFalse);
      expect(bad.keepStages, {'number': 1, 'color': 1});
    });

    test('백업 글자: 해금은 빼고(스토어 복원), 지켜 줄 단계는 넣는다', () {
      final d = SaveData.initial()
        ..unlocked = true
        ..keepStages = {'number': 5};
      final r = BackupCode.decode(BackupCode.encode(d));
      expect(r.data!.unlocked, isFalse);
      expect(r.data!.keepStages, {'number': 5});
    });
  });

  group('부모용 화면 크기', () {
    for (final code in ['ko', 'en']) {
      for (final size in l10nSizes) {
        for (final (name, store) in [
          ('ready', () => FakeBillingStore()),
          ('offline', () => FakeBillingStore(available: false)),
          ('pending', () => FakeBillingStore()..nextBuy = StorePurchaseStatus.pending),
        ]) {
          testWidgets('전체 놀이 열기 $code $name ${size.width.toInt()}', (t) async {
            await _size(t, size);
            final (s, _, _) = await billingState(store: store());
            if (name == 'pending') {
              await s.entitlement.buy();
              await _flush();
            }
            await t.pumpWidget(l10nApp(s, const UnlockScreen(), code));
            await _settle(t);
            expect(t.takeException(), isNull);
            if (name == 'ready') {
              expect(find.byKey(UnlockScreen.buyKey), findsOneWidget);
              final h = t.getSize(find.byKey(UnlockScreen.buyKey)).height;
              expect(h, greaterThanOrEqualTo(60));
            }
          });
        }
        testWidgets('설정 결제 칸 $code ${size.width.toInt()}', (t) async {
          await _size(t, size);
          final (s, _, _) = await billingState();
          await t.pumpWidget(l10nApp(s, const SettingsScreen(), code));
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(find.byKey(SettingsScreen.unlockKey), findsOneWidget);
        });
      }
    }
  });
}

String _body(String code) {
  final rest = code.substring(BackupCode.prefix.length);
  final b = rest.substring(0, rest.lastIndexOf('-'));
  final r = b.length % 4;
  return r == 0 ? b : b + '=' * (4 - r);
}
