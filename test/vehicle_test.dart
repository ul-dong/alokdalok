import 'dart:convert';
import 'dart:ui' as ui;

import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/vehicle/sticker_art.dart';
import 'package:alokdalok/vehicle/vehicle_painter.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/paged_grid.dart';
import 'package:alokdalok/services/backup_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탈것 7종: 가격, 저장값 옮기기(자전거·킥보드 → 기차·열기구), 사기 규칙, 탑승 흐름, 한 화면 배치.

Future<GameState> fresh({int rewards = 0}) async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  for (var i = 0; i < rewards; i++) {
    await s.rewardCorrect(firstTry: true);
  }
  return s;
}

List<String> spoken(GameState s) => (s.audio as RecordingAudio).spoken;

Widget wrap(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(home: home),
);

Future<void> setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

/// 자전거·킥보드를 가졌던 예전 저장값
Map<String, Object?> oldSave(int version) => {
  'version': version,
  'nickname': '별이',
  'nicknameChosen': true,
  'zodiac': 'tiger',
  'coins': 7,
  'owned': [
    'bicycle',
    'kickboard',
    'car',
    'paint_red@bicycle',
    'paint_blue@kickboard',
    'paint_green@car',
  ],
  'ride': 'bicycle',
  'stickers': {
    'bicycle': [
      {'k': 'star', 'c': 0xFFFFCC00, 'x': .3, 'y': .6},
      {'k': 'heart', 'c': 0xFFE8352B, 'x': .5, 'y': .6},
    ],
    'kickboard': [
      {'k': 'moon', 'c': 0xFF1E6FE0, 'x': .4, 'y': .2},
    ],
    'car': [
      {'k': 'paw', 'c': 0xFF19A84A, 'x': .5, 'y': .6},
    ],
  },
  'paints': {'bicycle': 'paint_red', 'kickboard': 'paint_pink'},
  'voiceStyle': 'pack',
};

void main() {
  group('탈것 7종과 가격', () {
    test('열기구 20 · 기차 25 · 자동차 40 · 오토바이 40 · 탱크 50 · 비행기 50 · 우주선 50', () {
      expect(
        {for (final v in Vehicles.all) v.name: v.price},
        {
          '열기구': 20,
          '기차': 25,
          '자동차': 40,
          '오토바이': 40,
          '탱크': 50,
          '비행기': 50,
          '우주선': 50,
        },
      );
      expect(Vehicles.all.map((v) => v.id), [
        'balloon',
        'train',
        'car',
        'motorcycle',
        'tank',
        'airplane',
        'rocket',
      ]);
      // 자전거·킥보드는 없다 (다리가 어색하고 스티커 자리가 좁아서 뺐다)
      expect(Vehicles.exists('bicycle'), isFalse);
      expect(Vehicles.exists('kickboard'), isFalse);
      for (final old in Vehicles.retired.keys) {
        expect(Vehicles.exists(old), isFalse, reason: old);
        expect(Vehicles.exists(Vehicles.retired[old]!.$1), isTrue);
      }
    });

    test('스티커 10종 × 원색 6가지, 색칠은 한 색 10코인', () {
      expect(StickerKind.values.length, 10);
      expect(Vehicles.stickerColors.length, 6);
      expect(Vehicles.stickerColors.toSet().length, 6);
      expect(Vehicles.paintPrice, 10);
      expect(Vehicles.maxStickers, greaterThanOrEqualTo(10));
    });

    test('기차·열기구는 스티커 붙일 자리가 넓다 (자동차의 4분의 3 이상)', () {
      double area(VehicleKind k) {
        final path = VehiclePainter.bodyPath(k);
        final b = path.getBounds();
        var hit = 0;
        for (var x = b.left; x < b.right; x += 2) {
          for (var y = b.top; y < b.bottom; y += 2) {
            if (path.contains(Offset(x, y))) hit++;
          }
        }
        return hit * 4.0;
      }

      final car = area(VehicleKind.car);
      expect(area(VehicleKind.train), greaterThan(car * .75));
      expect(area(VehicleKind.balloon), greaterThan(car * .75));
      expect(
        VehiclePainter.stickerRadius(VehicleKind.train),
        VehiclePainter.stickerRadius(VehicleKind.car),
      );
      expect(
        VehiclePainter.stickerRadius(VehicleKind.balloon),
        VehiclePainter.stickerRadius(VehicleKind.car),
      );
    });
  });

  group('저장값 옮기기 (자전거 → 기차, 킥보드 → 열기구)', () {
    test('가진 탈것·타는 탈것·스티커·칠한 색·산 색을 함께 옮긴다', () {
      final d = SaveData.decode(jsonEncode(oldSave(5)));
      expect(d.ownsVehicle('train'), isTrue);
      expect(d.ownsVehicle('balloon'), isTrue);
      expect(d.ownsVehicle('car'), isTrue);
      expect(d.owned.any((id) => id.contains('bicycle')), isFalse);
      expect(d.owned.any((id) => id.contains('kickboard')), isFalse);
      expect(d.ride, 'train');
      expect(d.stickers['train']!.map((s) => s.kind), [
        StickerKind.star,
        StickerKind.heart,
      ]);
      expect(d.stickers['balloon']!.single.kind, StickerKind.moon);
      expect(d.stickers['car']!.single.kind, StickerKind.paw);
      expect(d.paints['train'], 'paint_red');
      expect(d.paints['balloon'], 'paint_pink', reason: '킥보드 처음 색 = 열기구 처음 색');
      expect(d.canPaint('train', 'paint_red'), isTrue, reason: '자전거용으로 산 색');
      expect(d.canPaint('balloon', 'paint_blue'), isTrue, reason: '킥보드용으로 산 색');
      expect(d.canPaint('car', 'paint_green'), isTrue);
      expect(d.coins, 7, reason: '코인은 그대로');
    });

    test('버전 번호와 상관없이 옮긴다 (예전 버전·지금 버전·앞으로의 버전)', () {
      for (final v in [0, 3, 4, SaveData.currentVersion, 99]) {
        final d = SaveData.decode(jsonEncode(oldSave(v)));
        expect(d.ownsVehicle('train'), isTrue, reason: 'v$v');
        expect(d.ownsVehicle('balloon'), isTrue, reason: 'v$v');
        expect(d.ride, 'train', reason: 'v$v');
        expect(d.stickers['train']?.length, 2, reason: 'v$v');
        expect(d.canPaint('train', 'paint_red'), isTrue, reason: 'v$v');
      }
    });

    test('여러 번 돌려도 결과가 같다', () {
      final once = SaveData.migrate(oldSave(SaveData.currentVersion));
      final twice = SaveData.migrate(Map.of(once));
      final thrice = SaveData.migrate(
        Map<String, Object?>.from(jsonDecode(jsonEncode(twice)) as Map),
      );
      expect(jsonEncode(twice), jsonEncode(once));
      expect(jsonEncode(thrice), jsonEncode(once));
      // 저장 → 다시 읽기를 거쳐도 같다
      final a = SaveData.decode(jsonEncode(oldSave(5)));
      final b = SaveData.decode(a.encode());
      expect(b.encode(), a.encode());
    });

    test('없어진 탈것이 없으면 아무것도 바꾸지 않는다 (버전 번호도 그대로)', () {
      final json = <String, Object?>{
        'version': SaveData.currentVersion,
        'owned': ['car', 'paint_blue@car'],
        'ride': 'car',
        'stickers': <String, Object?>{},
        'paints': {'car': 'paint_blue'},
        'voiceStyle': 'pack',
      };
      final out = SaveData.migrate(Map.of(json));
      expect(jsonEncode(out), jsonEncode(json));
    });

    test('새 탈것이 이미 있으면 스티커는 합치고(최대 12장) 칠한 색은 새 탈것 것을 둔다', () {
      final json = oldSave(5);
      (json['owned'] as List).add('train');
      (json['stickers'] as Map)['train'] = [
        for (var i = 0; i < 11; i++)
          {'k': 'note', 'c': 0xFF7E3FD1, 'x': .5, 'y': .6},
      ];
      (json['paints'] as Map)['train'] = 'paint_yellow';
      final d = SaveData.decode(jsonEncode(json));
      expect(d.owned.where((id) => id == 'train').length, 1);
      expect(d.stickers['train']!.length, Vehicles.maxStickers);
      expect(d.stickers['train']!.first.kind, StickerKind.note);
      expect(d.stickers['train']!.last.kind, StickerKind.star);
      expect(d.paints['train'], 'paint_yellow');
    });

    test('없어진 탈것의 처음 색(공짜)은 새 탈것에서도 공짜로 쓸 수 있다', () {
      for (final e in Vehicles.retired.entries) {
        final (to, free) = e.value;
        final d = SaveData.decode(
          jsonEncode({
            'version': 4,
            'owned': [e.key],
            'paints': {e.key: free},
          }),
        );
        expect(d.paints[to], free, reason: e.key);
        expect(d.canPaint(to, free), isTrue, reason: e.key);
      }
    });

    test('ALOK1- 백업 글자로 복구할 때도 옮긴다', () {
      final json = oldSave(5);
      final body = base64Url
          .encode(utf8.encode(jsonEncode(json)))
          .replaceAll('=', '');
      final text = '${BackupCode.prefix}$body-${BackupCode.checksum(body)}';
      final d = BackupCode.decode(text).data!;
      expect(d.ownsVehicle('train'), isTrue);
      expect(d.ownsVehicle('balloon'), isTrue);
      expect(d.ride, 'train');
      expect(d.stickers['train']!.length, 2);
      expect(d.canPaint('train', 'paint_red'), isTrue);
    });

    test('타고 있던 킥보드는 열기구로, 손상된 값은 버린다', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 2,
          'owned': ['kickboard', 7, null],
          'ride': 'kickboard',
          'stickers': {'kickboard': 'garbage', 'ufo': []},
          'paints': {'kickboard': 'paint_gold'},
        }),
      );
      expect(d.ride, 'balloon');
      expect(d.stickers, isEmpty);
      expect(d.paints, isEmpty);
    });
  });

  group('사기 규칙', () {
    test('사면 코인이 줄지만 바로 타지는 않는다. 코인이 모자라면 못 산다', () async {
      final s = await fresh(rewards: 20);
      final before = s.coins;
      expect(await s.buyVehicle('balloon'), PurchaseResult.ok);
      expect(s.coins, before - 20);
      expect(s.ride, isNull);
      final poor = await fresh();
      final coins = poor.coins;
      expect(await poor.buyVehicle('train'), PurchaseResult.notEnoughCoins);
      expect(poor.coins, coins);
      expect(poor.ownsVehicle('train'), isFalse);
    });

    test('처음 색은 공짜, 다른 색은 탈것마다 따로 10코인', () async {
      final s = await fresh(rewards: 60);
      await s.buyVehicle('train');
      await s.buyVehicle('balloon');
      expect(s.canPaint('train', 'paint_yellow'), isTrue, reason: '기차 처음 색');
      expect(s.canPaint('balloon', 'paint_pink'), isTrue, reason: '열기구 처음 색');
      final before = s.coins;
      expect(
        await s.buyPaint('train', 'paint_yellow'),
        PurchaseResult.alreadyOwned,
      );
      expect(s.coins, before, reason: '처음 색은 사지 않는다');
      expect(await s.buyPaint('train', 'paint_blue'), PurchaseResult.ok);
      expect(s.coins, before - 10);
      expect(s.canPaint('balloon', 'paint_blue'), isFalse, reason: '탈것마다 따로');
      expect(await s.buyPaint('balloon', 'paint_blue'), PurchaseResult.ok);
      expect(s.coins, before - 20);
      expect(
        await s.buyPaint('rocket', 'paint_red'),
        PurchaseResult.unknownItem,
        reason: '안 산 탈것',
      );
    });
  });

  group('탄 모습 (옆을 보고 앉기)', () {
    test('24마리 × 7종 모두 그려진다 (옷 입은 친구 포함)', () {
      final fire = {
        for (final i in ItemCatalog.byTheme(OutfitTheme.fire)) i.slot: i,
      };
      for (final v in Vehicles.all) {
        for (final z in Zodiac.values) {
          for (final moving in [false, true]) {
            final rec = ui.PictureRecorder();
            VehiclePainter(
              vehicle: v,
              stickers: const [],
              zodiac: z,
              items: z.index.isEven ? fire : const {},
              moving: moving,
              phase: .4,
              mood: CharMood.happy,
            ).paint(Canvas(rec), const Size(300, 200));
            rec.endRecording().dispose();
          }
        }
      }
    });

    test('옆모습은 다시 그릴 조건에 들어간다', () {
      final a = AnimalPainter(zodiac: Zodiac.tiger, items: const {});
      final b = AnimalPainter(
        zodiac: Zodiac.tiger,
        items: const {},
        sideways: true,
      );
      expect(b.shouldRepaint(a), isTrue);
    });
  });

  group('탑승 흐름', () {
    testWidgets('내 친구 화면: 탈것을 누르면 이름만 말하고, "탑승!"을 눌러야 탄다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await fresh(rewards: 60);
      await s.buyVehicle('train');
      await s.buyVehicle('balloon');
      await t.pumpWidget(wrap(s, const CharacterScreen()));
      await settle(t);
      await t.tap(pressable('탈것'));
      await settle(t, 300);
      await t.tap(pressable('기차'));
      await settle(t, 300);
      expect(spoken(s).last, '기차');
      expect(s.ride, isNull, reason: '고르기만 하면 타지 않는다');
      await t.tap(pressable('탑승'));
      await settle(t, 300);
      expect(s.ride, 'train');
      expect(spoken(s).last, '출발!');
      // 다른 탈것을 골라도 타던 탈것은 그대로, 다시 탑승해야 바뀐다
      await t.tap(pressable('열기구'));
      await settle(t, 300);
      expect(spoken(s).last, '열기구');
      expect(s.ride, 'train');
      await t.tap(pressable('탑승'));
      await settle(t, 300);
      expect(s.ride, 'balloon');
      await t.tap(pressable('내리기'));
      await settle(t, 300);
      expect(s.ride, isNull);
      expect(t.takeException(), isNull);
    });

    testWidgets('꾸미기 화면: 탈것을 바꾸면 이름을 말하고, "탑승!"을 눌러야 탄다', (t) async {
      await setSize(t, const Size(1280, 800));
      final s = await fresh(rewards: 60);
      await s.buyVehicle('train');
      await s.buyVehicle('car');
      await t.pumpWidget(wrap(s, const GarageScreen(vehicleId: 'train')));
      await settle(t);
      await t.tap(pressable('자동차'));
      await settle(t, 300);
      expect(spoken(s).last, '자동차');
      expect(s.ride, isNull);
      await t.tap(pressable('탑승'));
      await settle(t, 300);
      expect(s.ride, 'car');
      expect(t.takeException(), isNull);
    });

    testWidgets('상점: 탈것을 누르면 이름을 말하고, 산 다음 "탑승!"으로 탄다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await fresh(rewards: 20);
      await t.pumpWidget(wrap(s, const ShopScreen(startWithVehicles: true)));
      await settle(t);
      await t.tap(pressable('열기구, 코인 20개'));
      await settle(t, 300);
      expect(spoken(s).last, '열기구');
      await t.tap(pressable('코인 20개로 사기'));
      await settle(t, 400);
      expect(find.byType(Dialog), findsOneWidget, reason: '큰 ✔ / ✖ 확인 창');
      await t.tap(pressable('네'));
      await settle(t, 600);
      expect(s.ownsVehicle('balloon'), isTrue);
      expect(s.ride, isNull);
      await t.tap(pressable('탑승!'));
      await settle(t, 300);
      expect(s.ride, 'balloon');
      expect(t.takeException(), isNull);
    });
  });

  group('한 화면에 모두 (밀어서 보기 없음)', () {
    for (final size in const [
      Size(568, 320),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('꾸미기: $name에서 탈것 7종·스티커 10종·색 6가지가 넘치지 않고 보인다', (t) async {
        await setSize(t, size);
        final s = await fresh(rewards: 160);
        for (final v in Vehicles.all) {
          await s.buyVehicle(v.id);
        }
        await t.pumpWidget(wrap(s, const GarageScreen()));
        await settle(t);
        expect(t.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        final screen = Offset.zero & size;
        void allOnScreen(List<Finder> fs) {
          for (final f in fs) {
            for (final e in f.evaluate()) {
              final r = t.getRect(find.byWidget(e.widget));
              expect(
                screen.contains(r.bottomRight - const Offset(1, 1)),
                isTrue,
              );
            }
          }
        }

        final stickers = pressable('스티커');
        expect(stickers, findsNWidgets(StickerKind.values.length + 1));
        allOnScreen([stickers, pressable('지우개')]);
        // 좁은 판은 색을 '물감' 탭에서 크게 고른다 (칸을 60px 이상으로)
        if (pressable('물감').evaluate().isNotEmpty) {
          expect(pressable('색'), findsNothing);
          await t.tap(pressable('물감'));
          await settle(t, 300);
        }
        expect(pressable('색'), findsNWidgets(6));
        allOnScreen([pressable('색')]);
        expect(t.takeException(), isNull);
        // 고르기: 모두 보이거나, 큰 화살표로 하나씩 넘긴다
        final all = Vehicles.all.every(
          (v) => pressable(v.name).evaluate().isNotEmpty,
        );
        if (!all) {
          expect(pressable('다음 쪽'), findsOneWidget);
          await t.tap(pressable('다음 쪽'));
          await settle(t, 300);
          expect(t.takeException(), isNull);
        }
      });

      testWidgets('꾸미기: $name에서 스티커·색·색칠 칸이 모두 60px 이상', (t) async {
        await setSize(t, size);
        final s = await fresh(rewards: 160);
        for (final v in Vehicles.all) {
          await s.buyVehicle(v.id);
        }
        await t.pumpWidget(wrap(s, const GarageScreen()));
        await settle(t);
        void atLeast60(Finder f, int count, String what) {
          expect(f, findsNWidgets(count), reason: what);
          for (final e in f.evaluate()) {
            final r = t.getRect(find.byWidget(e.widget));
            expect(
              r.width >= 60 && r.height >= 60,
              isTrue,
              reason:
                  '$what ${r.width.toStringAsFixed(1)}x'
                  '${r.height.toStringAsFixed(1)}',
            );
          }
        }

        // 스티커 칸 (탭 '스티커'는 빼고 StickerIcon이 든 칸만)
        final stickerCells = find.ancestor(
          of: find.byType(StickerIcon),
          matching: pressable('스티커'),
        );
        atLeast60(stickerCells, StickerKind.values.length, '스티커');
        if (pressable('물감').evaluate().isNotEmpty) {
          await t.tap(pressable('물감'));
          await settle(t, 300);
        }
        atLeast60(pressable('색'), 6, '색');
        await t.tap(pressable('색칠'));
        await settle(t, 300);
        final paints = find.byWidgetPredicate(
          (w) =>
              w is Pressable &&
              Vehicles.paints.any(
                (p) => w.semanticLabel?.startsWith(p.name) ?? false,
              ),
        );
        atLeast60(paints, Vehicles.paints.length, '색칠');
        expect(t.takeException(), isNull);
      });

      testWidgets('색칠: $name에서 코인이 모자라면 모으자는 안내와 진행 막대', (t) async {
        await setSize(t, size);
        final s = await fresh(rewards: 6);
        await s.buyVehicle('balloon');
        expect(s.coins, lessThan(Vehicles.paintPrice));
        await t.pumpWidget(wrap(s, const GarageScreen()));
        await settle(t);
        await t.tap(pressable('색칠'));
        await settle(t, 300);
        await t.tap(pressable('파란색, 코인 10개'));
        await settle(t, 300);
        expect(find.byType(Dialog), findsNothing, reason: '결제·구매 창으로 보내지 않는다');
        expect(find.textContaining('놀이하면서 코인을 모아요'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(s.paintOf('balloon').id, 'paint_pink');
        expect(t.takeException(), isNull);
      });

      testWidgets('내 친구·상점 탈것: $name에서 7종이 모두 화면 안에', (t) async {
        await setSize(t, size);
        final s = await fresh(rewards: 160);
        for (final v in Vehicles.all) {
          await s.buyVehicle(v.id);
        }
        final screen = Offset.zero & size;
        await t.pumpWidget(wrap(s, const CharacterScreen()));
        await settle(t);
        await t.tap(pressable('탈것'));
        await settle(t, 300);
        expect(find.byType(PagedGrid), findsWidgets);
        for (final v in Vehicles.all) {
          final r = t.getRect(pressable(v.name));
          expect(
            screen.contains(r.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: v.name,
          );
        }
        await t.pumpWidget(wrap(s, const ShopScreen(startWithVehicles: true)));
        await settle(t);
        for (final v in Vehicles.all) {
          final r = t.getRect(pressable('${v.name}, 가지고 있음'));
          expect(
            screen.contains(r.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: v.name,
          );
        }
        expect(t.takeException(), isNull);
      });
    }
  });
}
