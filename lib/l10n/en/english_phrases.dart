import '../../character/nickname.dart';
import '../../character/zodiac.dart';
import '../../data/game_objects.dart';
import '../../data/item_catalog.dart';
import '../../data/vehicles.dart';
import '../../games/common/scene_game.dart' show Season;
import '../../services/game_state.dart' show GameKind;
import '../phrases.dart';

/// 영어 문장 조립기. 조사가 없고, 관사(a/an/the)와 복수형("1 balloon" / "3 balloons")이 있다.
/// 3살에게 들려주는 말이라 짧고 다정하게 쓴다 ("Can you find the red balloon?").
/// 영어 녹음 음성이 아직 없어서 모두 기기 음성(TTS, en-US)으로 읽는다.
class EnglishPhrases extends Phrases {
  const EnglishPhrases();

  @override
  String get code => 'en';

  /// 첫 글자를 크게: apple → Apple
  static String cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// a / an
  static String article(String word) =>
      RegExp(r'^[aeiouAEIOU]').hasMatch(word) ? 'an' : 'a';

  // ---------- 낱말 ----------

  @override
  String object(ObjectKind k) => switch (k) {
    ObjectKind.apple => 'apple',
    ObjectKind.car => 'car',
    ObjectKind.star => 'star',
    ObjectKind.fish => 'fish',
    ObjectKind.duck => 'duck',
    ObjectKind.balloon => 'balloon',
    ObjectKind.ball => 'ball',
    ObjectKind.flower => 'flower',
  };

  /// 복수형: apples, fish
  String plural(ObjectKind k) => switch (k) {
    ObjectKind.fish => 'fish',
    _ => '${object(k)}s',
  };

  @override
  String colorName(GameColor c) => switch (c.id) {
    'gray' => 'gray',
    final id => id,
  };

  @override
  String objectLabel(ObjectKind k, [GameColor? c]) =>
      c == null ? object(k) : '${colorName(c)} ${object(k)}';

  /// 수에 맞는 이름: (1) red balloon / (3) red balloons
  String countedLabel(ObjectKind k, GameColor? c, int n) {
    final noun = n == 1 ? object(k) : plural(k);
    return c == null ? noun : '${colorName(c)} $noun';
  }

  @override
  String shape(ShapeKind s) => switch (s) {
    ShapeKind.circle => 'circle',
    ShapeKind.triangle => 'triangle',
    ShapeKind.square => 'square',
    ShapeKind.star => 'star',
    ShapeKind.heart => 'heart',
    ShapeKind.diamond => 'diamond',
  };

  @override
  String coloredShape(GameColor c, ShapeKind s) =>
      '${colorName(c)} ${shape(s)}';

  @override
  String season(Season s) => switch (s) {
    Season.spring => 'Spring',
    Season.summer => 'Summer',
    Season.autumn => 'Fall',
    Season.winter => 'Winter',
  };

  @override
  String gameTitle(GameKind g) => switch (g) {
    GameKind.number => 'Numbers',
    GameKind.color => 'Colors',
    GameKind.shape => 'Shapes',
    GameKind.size => 'Sizes',
    GameKind.match => 'Matching',
  };

  /// 문장 속 동물 이름 (소문자)
  String animalWord(Zodiac z) => switch (z) {
    Zodiac.rat => 'mouse',
    Zodiac.ox => 'cow',
    Zodiac.tiger => 'tiger',
    Zodiac.rabbit => 'bunny',
    Zodiac.dragon => 'dragon',
    Zodiac.snake => 'snake',
    Zodiac.horse => 'horse',
    Zodiac.sheep => 'sheep',
    Zodiac.monkey => 'monkey',
    Zodiac.rooster => 'chicken',
    Zodiac.dog => 'puppy',
    Zodiac.pig => 'pig',
    Zodiac.trex => 'T. rex',
    Zodiac.triceratops => 'triceratops',
    Zodiac.stegosaurus => 'stegosaurus',
    Zodiac.brachiosaurus => 'brachiosaurus',
    Zodiac.ankylosaurus => 'ankylosaurus',
    Zodiac.pteranodon => 'pteranodon',
    Zodiac.parasaurolophus => 'parasaurolophus',
    Zodiac.pachycephalosaurus => 'pachycephalosaurus',
    Zodiac.velociraptor => 'velociraptor',
    Zodiac.spinosaurus => 'spinosaurus',
    Zodiac.iguanodon => 'iguanodon',
    Zodiac.dilophosaurus => 'dilophosaurus',
  };

  @override
  String animal(Zodiac z) => cap(animalWord(z));

  static const _items = {
    'helmet_robot': 'Robot helmet',
    'suit_robot': 'Robot suit',
    'boots_robot': 'Robot boots',
    'visor_robot': 'Robot goggles',
    'jetpack_robot': 'Robot rocket',
    'crown_gold': 'Sparkly crown',
    'dress_princess': 'Princess dress',
    'shoes_magic': 'Glass slippers',
    'ribbon_pink': 'Pink ribbon',
    'wings_fairy': 'Fairy wings',
    'helmet_fire': 'Fire helmet',
    'suit_fire': 'Firefighter suit',
    'boots_fire': 'Fire boots',
    'tank_fire': 'Air tank',
    'cap_police': 'Police hat',
    'suit_police': 'Police uniform',
    'shoes_police': 'Black shoes',
    'badge_police': 'Police badge',
    'helmet_army': 'Army helmet',
    'suit_army': 'Camo uniform',
    'boots_army': 'Army boots',
    'dogtag_army': 'Dog tags',
    'bag_army': 'Army backpack',
    'bone_head': 'Bone headband',
    'suit_cave': 'Leopard outfit',
    'sandal_cave': 'Leather shoes',
    'tooth_necklace': 'Tooth necklace',
    'club_cave': 'Wooden club',
    'astro_helmet': 'Space helmet',
    'astro_suit': 'Space suit',
    'astro_boots': 'Space boots',
    'astro_pack': 'Space backpack',
    'doc_mirror': 'Head mirror',
    'doc_coat': "Doctor's coat",
    'doc_stetho': 'Stethoscope',
    'doc_shoes': 'White slippers',
    'chef_hat': "Chef's hat",
    'chef_coat': "Chef's jacket",
    'chef_spatula': 'Spatula',
    'chef_shoes': "Chef's shoes",
    'farm_hat': 'Straw hat',
    'farm_overall': 'Overalls',
    'farm_boots': 'Green boots',
    'farm_basket': 'Veggie basket',
    'train_cap': 'Train cap',
    'train_suit': 'Train uniform',
    'train_whistle': 'Whistle',
    'train_boots': 'Black boots',
    'pirate_hat': 'Pirate hat',
    'pirate_shirt': 'Pirate shirt',
    'pirate_patch': 'Eye patch',
    'pirate_scope': 'Telescope',
    'wizard_hat': 'Wizard hat',
    'wizard_robe': 'Wizard robe',
    'wizard_wand': 'Magic wand',
    'wizard_shoes': 'Purple shoes',
    'dino_hood': 'Dino hood',
    'dino_suit': 'Dino suit',
    'dino_tail': 'Dino tail',
    'dino_feet': 'Dino feet',
    'hero_mask': 'Hero mask',
    'hero_suit': 'Hero suit',
    'hero_cape': 'Hero cape',
    'hero_boots': 'Red boots',
    'soccer_band': 'Sweatband',
    'soccer_jersey': 'Soccer jersey',
    'soccer_shoes': 'Soccer cleats',
    'soccer_ball': 'Soccer ball',
    'ballet_tiara': 'Sparkly tiara',
    'ballet_tutu': 'Ballet tutu',
    'ballet_shoes': 'Ballet shoes',
  };

  /// 영어 이름이 있는 아이템 id (테스트: 아이템마다 영어 이름이 있는지)
  static Iterable<String> get itemIds => _items.keys;

  @override
  String itemName(Item i) => _items[i.id] ?? i.id;

  @override
  String itemSlot(ItemSlot s) => switch (s) {
    ItemSlot.head => 'Head',
    ItemSlot.outfit => 'Clothes',
    ItemSlot.shoes => 'Shoes',
    ItemSlot.accessory => 'Extras',
    ItemSlot.back => 'Back',
  };

  @override
  String outfitTheme(OutfitTheme t) => switch (t) {
    OutfitTheme.robot => 'Robot',
    OutfitTheme.princess => 'Princess',
    OutfitTheme.fire => 'Firefighter',
    OutfitTheme.police => 'Police',
    OutfitTheme.army => 'Soldier',
    OutfitTheme.caveman => 'Caveman',
    OutfitTheme.astronaut => 'Astronaut',
    OutfitTheme.doctor => 'Doctor',
    OutfitTheme.chef => 'Chef',
    OutfitTheme.farmer => 'Farmer',
    OutfitTheme.train => 'Train driver',
    OutfitTheme.pirate => 'Pirate',
    OutfitTheme.wizard => 'Wizard',
    OutfitTheme.dino => 'Dinosaur',
    OutfitTheme.hero => 'Superhero',
    OutfitTheme.soccer => 'Soccer',
    OutfitTheme.ballet => 'Ballet',
  };

  @override
  String vehicleName(Vehicle v) => switch (v.id) {
    'balloon' => 'Hot air balloon',
    'train' => 'Train',
    'car' => 'Car',
    'motorcycle' => 'Motorcycle',
    'tank' => 'Tank',
    'airplane' => 'Airplane',
    'rocket' => 'Rocket',
    _ => v.id,
  };

  /// 문장 속 색 이름 (paint_red → red)
  String paintWord(VehiclePaint p) => p.id.replaceFirst('paint_', '');

  @override
  String paintName(VehiclePaint p) => cap(paintWord(p));

  // ---------- 수 ----------

  static const _numbers = [
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
  ];

  /// one … ten (11 이상은 숫자 그대로)
  String numberWord(int n) => n >= 1 && n <= 10 ? _numbers[n - 1] : '$n';

  @override
  String count(int n) => cap(numberWord(n));

  @override
  String countUpTo(int n) =>
      cap([for (var i = 1; i <= n; i++) numberWord(i)].join(', '));

  // ---------- 이름 말하기 ----------

  @override
  String sayName(ObjectKind k, [GameColor? c]) =>
      c != null && GameColor.extended.contains(c)
      ? '${cap(objectLabel(k, c))}!'
      : '${cap(object(k))}!';

  @override
  String exclaim(String label) => '${cap(label)}!';

  @override
  String sayShape(ShapeKind s) => '${cap(shape(s))}!';

  @override
  String gameInvite(GameKind g) => '${gameTitle(g)}!';

  @override
  String gameNameLine(GameKind g) => "It's ${gameTitle(g)}!";

  @override
  String friendHello(Zodiac z) {
    final w = animalWord(z);
    return "I'm ${article(w)} $w!";
  }

  // ---------- 숫자 놀이 ----------

  @override
  String howMany(ObjectKind k, GameColor? c, {required bool scattered}) =>
      'How many ${countedLabel(k, scattered ? c : null, 2)}?';

  @override
  String countAnswer(ObjectKind k, GameColor? c, int n) =>
      '${cap(numberWord(n))} ${countedLabel(k, c, n)}!';

  // ---------- 색깔 놀이 ----------

  @override
  String findColored(GameColor c, ObjectKind k) =>
      'Can you find the ${objectLabel(k, c)}?';

  @override
  String colorPraise(GameColor c) => '${cap(colorName(c))}! Great job!';

  @override
  String colorWrong(GameColor picked, GameColor target) =>
      'This is ${colorName(picked)}. Can you find ${colorName(target)}?';

  // ---------- 모양 놀이 ----------

  @override
  String findShape(ShapeKind s) => 'Can you find the ${shape(s)}?';

  @override
  String findSameShape() => 'Can you find the same shape?';

  @override
  String shapeWrong(ShapeKind picked, ShapeKind target) {
    final p = shape(picked);
    return 'This is ${article(p)} $p. Can you find the ${shape(target)}?';
  }

  @override
  String shapePraise(ShapeKind s) => '${cap(shape(s))}! Great job!';

  @override
  String shapeSample(ShapeKind s) => 'Sample: ${shape(s)}';

  // ---------- 크기 놀이 ----------

  String _sizeWord(SizeAsk a, bool superlative) => switch ((a, superlative)) {
    (SizeAsk.big, false) => 'big',
    (SizeAsk.small, false) => 'small',
    (SizeAsk.big, true) => 'biggest',
    (SizeAsk.small, true) => 'smallest',
  };

  @override
  String findSize(SizeAsk a, ObjectKind k, {required bool superlative}) =>
      'Can you find the ${_sizeWord(a, superlative)} ${object(k)}?';

  @override
  String sizeWrong(SizeAsk a, ObjectKind k, {required bool superlative}) =>
      "Let's look again for the ${_sizeWord(a, superlative)} ${object(k)}!";

  @override
  String sizeSide(SizeAsk a) => a == SizeAsk.big ? 'Big one' : 'Small one';

  // ---------- 짝 맞추기 ----------

  @override
  String matchPicked(ObjectKind k, GameColor? c) =>
      '${exclaim(objectLabel(k, c))} ${matchFind(k, c)}';

  @override
  String matchFind(ObjectKind k, GameColor? c) =>
      'Can you find another ${objectLabel(k, c)}?';

  @override
  String matchWrong(ObjectKind k, GameColor? c) =>
      "Let's look again for another ${objectLabel(k, c)}!";

  @override
  String matchMatched(ObjectKind k, GameColor? c) =>
      '${exclaim(objectLabel(k, c))} They match!';

  @override
  String matchFinished(ObjectKind k, GameColor? c) =>
      '${matchMatched(k, c)} Great job!';

  // ---------- 탈것 색칠 ----------

  @override
  String paintedWith(VehiclePaint p) => 'Painted ${paintWord(p)}!';

  @override
  String paintNeedsCoins(VehiclePaint p, int price) =>
      '${paintName(p)} needs $price coins.';

  @override
  String paintNeedsCoinsAsk(VehiclePaint p, int price) =>
      "${paintNeedsCoins(p, price)} Let's play and collect them!";

  // ---------- 이름 짓기 ----------

  static const _names = [
    'Sunny',
    'Cloud',
    'Bean',
    'Sky',
    'Coco',
    'Pip',
    'Daisy',
    'Honey',
    'Bubbles',
    'Moony',
    'Cotton',
    'Acorn',
    'Choco',
    'Berry',
    'Peach',
    'Lovey',
  ];

  @override
  List<String> get randomNames => _names;

  @override
  String nickname(String stored) =>
      stored == Nickname.fallback ? 'Buddy' : stored;
}
