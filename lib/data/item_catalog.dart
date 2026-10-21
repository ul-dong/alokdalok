import 'dart:ui';

/// 꾸미기 아이템을 장착하는 부위. 그리는 순서(레이어)는 AnimalPainter가 정한다.
enum ItemSlot { head, outfit, shoes, accessory, back }

extension ItemSlotInfo on ItemSlot {
  String get label => switch (this) {
    ItemSlot.head => '머리',
    ItemSlot.outfit => '옷',
    ItemSlot.shoes => '신발',
    ItemSlot.accessory => '장식',
    ItemSlot.back => '등',
  };
}

/// 옷 테마 (상점·옷장의 탭). 새 테마는 여기에 추가하고 아이템 목록에 넣으면 된다.
enum OutfitTheme {
  robot,
  princess,
  fire,
  police,
  army,
  caveman,
  astronaut,
  doctor,
  chef,
  farmer,
  train,
  pirate,
  wizard,
  dino,
  hero,
  soccer,
  ballet,
}

extension OutfitThemeInfo on OutfitTheme {
  String get label => switch (this) {
    OutfitTheme.robot => '로봇',
    OutfitTheme.princess => '공주',
    OutfitTheme.fire => '소방관',
    OutfitTheme.police => '경찰',
    OutfitTheme.army => '군인',
    OutfitTheme.caveman => '원시인',
    OutfitTheme.astronaut => '우주비행사',
    OutfitTheme.doctor => '의사',
    OutfitTheme.chef => '요리사',
    OutfitTheme.farmer => '농부',
    OutfitTheme.train => '기관사',
    OutfitTheme.pirate => '해적',
    OutfitTheme.wizard => '마법사',
    OutfitTheme.dino => '공룡',
    OutfitTheme.hero => '슈퍼히어로',
    OutfitTheme.soccer => '축구선수',
    OutfitTheme.ballet => '발레리나',
  };

  /// 탭 그림으로 쓸 대표 아이템
  String get sampleId => switch (this) {
    OutfitTheme.robot => 'helmet_robot',
    OutfitTheme.princess => 'crown_gold',
    OutfitTheme.fire => 'helmet_fire',
    OutfitTheme.police => 'cap_police',
    OutfitTheme.army => 'helmet_army',
    OutfitTheme.caveman => 'bone_head',
    OutfitTheme.astronaut => 'astro_helmet',
    OutfitTheme.doctor => 'doc_mirror',
    OutfitTheme.chef => 'chef_hat',
    OutfitTheme.farmer => 'farm_hat',
    OutfitTheme.train => 'train_cap',
    OutfitTheme.pirate => 'pirate_hat',
    OutfitTheme.wizard => 'wizard_hat',
    OutfitTheme.dino => 'dino_hood',
    OutfitTheme.hero => 'hero_mask',
    OutfitTheme.soccer => 'soccer_band',
    OutfitTheme.ballet => 'ballet_tiara',
  };
}

/// 아이템 한 개의 데이터.
///
/// [style]은 그리는 방법(모양)이고, [colors]로 색을 바꾼다.
/// 같은 style에 색만 다른 아이템은 코드 수정 없이 이 목록에 한 줄만 추가하면 된다.
/// 새 모양이 필요할 때만 lib/character/item_art.dart에 style을 추가한다.
class Item {
  const Item({
    required this.id,
    required this.slot,
    required this.name,
    required this.price,
    required this.style,
    required this.colors,
    required this.theme,
  });

  final String id;
  final ItemSlot slot;
  final String name;
  final int price;
  final String style;
  final List<Color> colors;
  final OutfitTheme theme;

  /// 몸통 위(목) 쪽에 거는 장식인지 (얼굴보다 먼저 그린다)
  bool get isNecklace => const {
    'necklace',
    'badge',
    'dogtag',
    'tooth',
    'stethoscope',
    'whistle',
  }.contains(style);
}

/// 전체 아이템 목록. 모든 아이템은 성별 구분 없이 누구나 쓸 수 있다.
class ItemCatalog {
  ItemCatalog._();

  static const List<Item> all = [
    // 로봇
    Item(
      id: 'helmet_robot',
      slot: ItemSlot.head,
      name: '로봇 헬멧',
      price: 30,
      style: 'robothelmet',
      colors: [Color(0xFFC9D1DA), Color(0xFF6FC3E8), Color(0xFFF2726F)],
      theme: OutfitTheme.robot,
    ),
    Item(
      id: 'suit_robot',
      slot: ItemSlot.outfit,
      name: '로봇 슈트',
      price: 40,
      style: 'robot',
      colors: [Color(0xFFC9D1DA), Color(0xFF6FC3E8), Color(0xFFF2726F)],
      theme: OutfitTheme.robot,
    ),
    Item(
      id: 'boots_robot',
      slot: ItemSlot.shoes,
      name: '로봇 부츠',
      price: 20,
      style: 'robotboots',
      colors: [Color(0xFFC9D1DA), Color(0xFF6FC3E8)],
      theme: OutfitTheme.robot,
    ),
    Item(
      id: 'visor_robot',
      slot: ItemSlot.accessory,
      name: '로봇 고글',
      price: 15,
      style: 'visor',
      colors: [Color(0xFF6FD6F2)],
      theme: OutfitTheme.robot,
    ),
    Item(
      id: 'jetpack_robot',
      slot: ItemSlot.back,
      name: '로봇 로켓',
      price: 40,
      style: 'jetpack',
      colors: [Color(0xFFC9D1DA), Color(0xFFF2726F), Color(0xFFFFCF4D)],
      theme: OutfitTheme.robot,
    ),

    // 공주
    Item(
      id: 'crown_gold',
      slot: ItemSlot.head,
      name: '반짝 왕관',
      price: 30,
      style: 'crown',
      colors: [Color(0xFFFFCF4D), Color(0xFFF59AB5), Color(0xFF8FD3F5)],
      theme: OutfitTheme.princess,
    ),
    Item(
      id: 'dress_princess',
      slot: ItemSlot.outfit,
      name: '공주 드레스',
      price: 40,
      style: 'dress',
      colors: [Color(0xFFF7A8C4), Color(0xFFFFE3EC), Color(0xFFFFCF4D)],
      theme: OutfitTheme.princess,
    ),
    Item(
      id: 'shoes_magic',
      slot: ItemSlot.shoes,
      name: '유리 구두',
      price: 25,
      style: 'magic',
      colors: [Color(0xFFBFE8FF), Color(0xFFFFE97A)],
      theme: OutfitTheme.princess,
    ),
    Item(
      id: 'ribbon_pink',
      slot: ItemSlot.accessory,
      name: '분홍 리본',
      price: 10,
      style: 'ribbon',
      colors: [Color(0xFFF58BB0), Color(0xFFFFD1E0)],
      theme: OutfitTheme.princess,
    ),
    Item(
      id: 'wings_fairy',
      slot: ItemSlot.back,
      name: '요정 날개',
      price: 35,
      style: 'wings',
      colors: [Color(0xFFBDE6FF), Color(0xFFFFFFFF)],
      theme: OutfitTheme.princess,
    ),

    // 소방관
    Item(
      id: 'helmet_fire',
      slot: ItemSlot.head,
      name: '소방 헬멧',
      price: 30,
      style: 'firehelmet',
      colors: [Color(0xFFE8433A), Color(0xFFFFCF4D)],
      theme: OutfitTheme.fire,
    ),
    Item(
      id: 'suit_fire',
      slot: ItemSlot.outfit,
      name: '소방복',
      price: 40,
      style: 'firesuit',
      colors: [Color(0xFFE2B66A), Color(0xFFFFE14D)],
      theme: OutfitTheme.fire,
    ),
    Item(
      id: 'boots_fire',
      slot: ItemSlot.shoes,
      name: '소방 장화',
      price: 20,
      style: 'boots',
      colors: [Color(0xFF3D3D3D), Color(0xFFFFE14D)],
      theme: OutfitTheme.fire,
    ),
    Item(
      id: 'tank_fire',
      slot: ItemSlot.back,
      name: '공기통',
      price: 35,
      style: 'firetank',
      colors: [Color(0xFFE8433A), Color(0xFFFFE14D)],
      theme: OutfitTheme.fire,
    ),

    // 경찰
    Item(
      id: 'cap_police',
      slot: ItemSlot.head,
      name: '경찰 모자',
      price: 25,
      style: 'policecap',
      colors: [Color(0xFF2F4F86), Color(0xFF1E2F52)],
      theme: OutfitTheme.police,
    ),
    Item(
      id: 'suit_police',
      slot: ItemSlot.outfit,
      name: '경찰복',
      price: 40,
      style: 'police',
      colors: [Color(0xFF6D9BD6), Color(0xFF2F4F86)],
      theme: OutfitTheme.police,
    ),
    Item(
      id: 'shoes_police',
      slot: ItemSlot.shoes,
      name: '검정 구두',
      price: 15,
      style: 'loafer',
      colors: [Color(0xFF2E2A28)],
      theme: OutfitTheme.police,
    ),
    Item(
      id: 'badge_police',
      slot: ItemSlot.accessory,
      name: '경찰 배지',
      price: 15,
      style: 'badge',
      colors: [Color(0xFFFFCF4D), Color(0xFF2F4F86)],
      theme: OutfitTheme.police,
    ),

    // 군인
    Item(
      id: 'helmet_army',
      slot: ItemSlot.head,
      name: '군인 헬멧',
      price: 30,
      style: 'armyhelmet',
      colors: [Color(0xFF7E8C4A), Color(0xFF5E6B36)],
      theme: OutfitTheme.army,
    ),
    Item(
      id: 'suit_army',
      slot: ItemSlot.outfit,
      name: '얼룩무늬 군복',
      price: 40,
      style: 'camo',
      colors: [Color(0xFF8C9A58), Color(0xFF5E6B36), Color(0xFFB8A774)],
      theme: OutfitTheme.army,
    ),
    Item(
      id: 'boots_army',
      slot: ItemSlot.shoes,
      name: '군화',
      price: 20,
      style: 'boots',
      colors: [Color(0xFF4A3A2C), Color(0xFF6B5A44)],
      theme: OutfitTheme.army,
    ),
    Item(
      id: 'dogtag_army',
      slot: ItemSlot.accessory,
      name: '군번줄',
      price: 10,
      style: 'dogtag',
      colors: [Color(0xFF9AA3AD), Color(0xFFD5DCE4)],
      theme: OutfitTheme.army,
    ),
    Item(
      id: 'bag_army',
      slot: ItemSlot.back,
      name: '군용 배낭',
      price: 25,
      style: 'backpack',
      colors: [Color(0xFF6E7C3E), Color(0xFFB8A774)],
      theme: OutfitTheme.army,
    ),

    // 원시인
    Item(
      id: 'bone_head',
      slot: ItemSlot.head,
      name: '뼈다귀 머리띠',
      price: 20,
      style: 'bonehead',
      colors: [Color(0xFFFFF8E7), Color(0xFF9A6646)],
      theme: OutfitTheme.caveman,
    ),
    Item(
      id: 'suit_cave',
      slot: ItemSlot.outfit,
      name: '표범 무늬 옷',
      price: 35,
      style: 'caveman',
      colors: [Color(0xFFF2B65A), Color(0xFF7A4A2A)],
      theme: OutfitTheme.caveman,
    ),
    Item(
      id: 'sandal_cave',
      slot: ItemSlot.shoes,
      name: '가죽 신발',
      price: 10,
      style: 'sandal',
      colors: [Color(0xFFB98552), Color(0xFF7A4A2A)],
      theme: OutfitTheme.caveman,
    ),
    Item(
      id: 'tooth_necklace',
      slot: ItemSlot.accessory,
      name: '이빨 목걸이',
      price: 15,
      style: 'tooth',
      colors: [Color(0xFFFFFBF0), Color(0xFF9A6646)],
      theme: OutfitTheme.caveman,
    ),
    Item(
      id: 'club_cave',
      slot: ItemSlot.back,
      name: '나무 방망이',
      price: 25,
      style: 'club',
      colors: [Color(0xFFB98552), Color(0xFF7A4A2A)],
      theme: OutfitTheme.caveman,
    ),

    // 우주비행사
    Item(
      id: 'astro_helmet',
      slot: ItemSlot.head,
      name: '우주 헬멧',
      price: 35,
      style: 'spacehelmet',
      colors: [Color(0xFFBFE8FF), Color(0xFFDDE3EA)],
      theme: OutfitTheme.astronaut,
    ),
    Item(
      id: 'astro_suit',
      slot: ItemSlot.outfit,
      name: '우주복',
      price: 45,
      style: 'spacesuit',
      colors: [Color(0xFFF4F7FA), Color(0xFFC9D1DA), Color(0xFF5B9BE6)],
      theme: OutfitTheme.astronaut,
    ),
    Item(
      id: 'astro_boots',
      slot: ItemSlot.shoes,
      name: '우주 부츠',
      price: 20,
      style: 'robotboots',
      colors: [Color(0xFFF4F7FA), Color(0xFF5B9BE6)],
      theme: OutfitTheme.astronaut,
    ),
    Item(
      id: 'astro_pack',
      slot: ItemSlot.back,
      name: '우주 배낭',
      price: 35,
      style: 'jetpack',
      colors: [Color(0xFFF4F7FA), Color(0xFF5B9BE6), Color(0xFFFFB13B)],
      theme: OutfitTheme.astronaut,
    ),

    // 의사
    Item(
      id: 'doc_mirror',
      slot: ItemSlot.head,
      name: '의사 머리거울',
      price: 20,
      style: 'doctorcap',
      colors: [Color(0xFFFFFFFF), Color(0xFFC9D1DA)],
      theme: OutfitTheme.doctor,
    ),
    Item(
      id: 'doc_coat',
      slot: ItemSlot.outfit,
      name: '의사 가운',
      price: 40,
      style: 'doctorcoat',
      colors: [Color(0xFFFFFFFF), Color(0xFF8FD3F5), Color(0xFF5B9BE6)],
      theme: OutfitTheme.doctor,
    ),
    Item(
      id: 'doc_stetho',
      slot: ItemSlot.accessory,
      name: '청진기',
      price: 20,
      style: 'stethoscope',
      colors: [Color(0xFF5B6B7A), Color(0xFFC9D1DA)],
      theme: OutfitTheme.doctor,
    ),
    Item(
      id: 'doc_shoes',
      slot: ItemSlot.shoes,
      name: '하얀 실내화',
      price: 10,
      style: 'loafer',
      colors: [Color(0xFFF4F7FA)],
      theme: OutfitTheme.doctor,
    ),

    // 요리사
    Item(
      id: 'chef_hat',
      slot: ItemSlot.head,
      name: '요리사 모자',
      price: 25,
      style: 'chefhat',
      colors: [Color(0xFFFFFFFF), Color(0xFFE8E1D6)],
      theme: OutfitTheme.chef,
    ),
    Item(
      id: 'chef_coat',
      slot: ItemSlot.outfit,
      name: '요리사 옷',
      price: 40,
      style: 'chefcoat',
      colors: [Color(0xFFFFFFFF), Color(0xFFF26B5E), Color(0xFF3D3D3D)],
      theme: OutfitTheme.chef,
    ),
    Item(
      id: 'chef_spatula',
      slot: ItemSlot.back,
      name: '뒤집개',
      price: 20,
      style: 'spatula',
      colors: [Color(0xFFC9D1DA), Color(0xFF8C6346)],
      theme: OutfitTheme.chef,
    ),
    Item(
      id: 'chef_shoes',
      slot: ItemSlot.shoes,
      name: '요리사 신발',
      price: 10,
      style: 'loafer',
      colors: [Color(0xFF3D3D3D)],
      theme: OutfitTheme.chef,
    ),

    // 농부
    Item(
      id: 'farm_hat',
      slot: ItemSlot.head,
      name: '밀짚모자',
      price: 20,
      style: 'strawhat',
      colors: [Color(0xFFF2D27A), Color(0xFFF26B5E)],
      theme: OutfitTheme.farmer,
    ),
    Item(
      id: 'farm_overall',
      slot: ItemSlot.outfit,
      name: '멜빵바지',
      price: 35,
      style: 'overalls',
      colors: [Color(0xFF5B8FD6), Color(0xFFF26B5E), Color(0xFFFFFFFF)],
      theme: OutfitTheme.farmer,
    ),
    Item(
      id: 'farm_boots',
      slot: ItemSlot.shoes,
      name: '초록 장화',
      price: 15,
      style: 'boots',
      colors: [Color(0xFF6FBF5A), Color(0xFF4E9A3F)],
      theme: OutfitTheme.farmer,
    ),
    Item(
      id: 'farm_basket',
      slot: ItemSlot.back,
      name: '채소 바구니',
      price: 25,
      style: 'veggiebasket',
      colors: [Color(0xFFE8C07A), Color(0xFFFF9F45), Color(0xFF6FBF5A)],
      theme: OutfitTheme.farmer,
    ),

    // 기관사
    Item(
      id: 'train_cap',
      slot: ItemSlot.head,
      name: '기관사 모자',
      price: 25,
      style: 'conductorcap',
      colors: [Color(0xFF3F5F9A), Color(0xFFFFFFFF)],
      theme: OutfitTheme.train,
    ),
    Item(
      id: 'train_suit',
      slot: ItemSlot.outfit,
      name: '기관사 옷',
      price: 40,
      style: 'conductor',
      colors: [Color(0xFF3F5F9A), Color(0xFFDCE6F5), Color(0xFFF26B5E)],
      theme: OutfitTheme.train,
    ),
    Item(
      id: 'train_whistle',
      slot: ItemSlot.accessory,
      name: '호루라기',
      price: 10,
      style: 'whistle',
      colors: [Color(0xFFC9D1DA), Color(0xFFF26B5E)],
      theme: OutfitTheme.train,
    ),
    Item(
      id: 'train_boots',
      slot: ItemSlot.shoes,
      name: '까만 장화',
      price: 15,
      style: 'boots',
      colors: [Color(0xFF3D3D3D), Color(0xFF6E6E6E)],
      theme: OutfitTheme.train,
    ),

    // 해적
    Item(
      id: 'pirate_hat',
      slot: ItemSlot.head,
      name: '해적 모자',
      price: 30,
      style: 'piratehat',
      colors: [Color(0xFF3D3D3D), Color(0xFFFFCF4D), Color(0xFFFFFFFF)],
      theme: OutfitTheme.pirate,
    ),
    Item(
      id: 'pirate_shirt',
      slot: ItemSlot.outfit,
      name: '해적 옷',
      price: 35,
      style: 'pirate',
      colors: [Color(0xFFFFFFFF), Color(0xFFF26B5E), Color(0xFF7A4A2A)],
      theme: OutfitTheme.pirate,
    ),
    Item(
      id: 'pirate_patch',
      slot: ItemSlot.accessory,
      name: '해적 안대',
      price: 10,
      style: 'eyepatch',
      colors: [Color(0xFF3D3D3D)],
      theme: OutfitTheme.pirate,
    ),
    Item(
      id: 'pirate_scope',
      slot: ItemSlot.back,
      name: '망원경',
      price: 25,
      style: 'telescope',
      colors: [Color(0xFFE0A84A), Color(0xFF7A4A2A)],
      theme: OutfitTheme.pirate,
    ),

    // 마법사
    Item(
      id: 'wizard_hat',
      slot: ItemSlot.head,
      name: '마법사 모자',
      price: 30,
      style: 'wizardhat',
      colors: [Color(0xFF7C5CC4), Color(0xFFFFCF4D)],
      theme: OutfitTheme.wizard,
    ),
    Item(
      id: 'wizard_robe',
      slot: ItemSlot.outfit,
      name: '마법사 옷',
      price: 45,
      style: 'robe',
      colors: [Color(0xFF7C5CC4), Color(0xFFFFCF4D)],
      theme: OutfitTheme.wizard,
    ),
    Item(
      id: 'wizard_wand',
      slot: ItemSlot.back,
      name: '요술봉',
      price: 25,
      style: 'wand',
      colors: [Color(0xFF7A4A2A), Color(0xFFFFCF4D)],
      theme: OutfitTheme.wizard,
    ),
    Item(
      id: 'wizard_shoes',
      slot: ItemSlot.shoes,
      name: '보라 구두',
      price: 15,
      style: 'loafer',
      colors: [Color(0xFF9B7AD8)],
      theme: OutfitTheme.wizard,
    ),

    // 공룡
    Item(
      id: 'dino_hood',
      slot: ItemSlot.head,
      name: '공룡 모자',
      price: 30,
      style: 'dinohood',
      colors: [Color(0xFF7BC86C), Color(0xFFFFCF4D)],
      theme: OutfitTheme.dino,
    ),
    Item(
      id: 'dino_suit',
      slot: ItemSlot.outfit,
      name: '공룡 옷',
      price: 40,
      style: 'dinosuit',
      colors: [Color(0xFF7BC86C), Color(0xFFD9F2B4)],
      theme: OutfitTheme.dino,
    ),
    Item(
      id: 'dino_tail',
      slot: ItemSlot.back,
      name: '공룡 꼬리',
      price: 30,
      style: 'dinotail',
      colors: [Color(0xFF7BC86C), Color(0xFFFFCF4D)],
      theme: OutfitTheme.dino,
    ),
    Item(
      id: 'dino_feet',
      slot: ItemSlot.shoes,
      name: '공룡 발',
      price: 20,
      style: 'dinofeet',
      colors: [Color(0xFF7BC86C), Color(0xFFFFFFFF)],
      theme: OutfitTheme.dino,
    ),

    // 슈퍼히어로
    Item(
      id: 'hero_mask',
      slot: ItemSlot.accessory,
      name: '히어로 가면',
      price: 15,
      style: 'mask',
      colors: [Color(0xFFF26B5E)],
      theme: OutfitTheme.hero,
    ),
    Item(
      id: 'hero_suit',
      slot: ItemSlot.outfit,
      name: '히어로 옷',
      price: 45,
      style: 'hero',
      colors: [Color(0xFF4A7FD6), Color(0xFFF26B5E), Color(0xFFFFCF4D)],
      theme: OutfitTheme.hero,
    ),
    Item(
      id: 'hero_cape',
      slot: ItemSlot.back,
      name: '히어로 망토',
      price: 35,
      style: 'cape',
      colors: [Color(0xFFF26B5E), Color(0xFFFFCF4D)],
      theme: OutfitTheme.hero,
    ),
    Item(
      id: 'hero_boots',
      slot: ItemSlot.shoes,
      name: '빨간 부츠',
      price: 20,
      style: 'boots',
      colors: [Color(0xFFF26B5E), Color(0xFFFFCF4D)],
      theme: OutfitTheme.hero,
    ),

    // 축구선수
    Item(
      id: 'soccer_band',
      slot: ItemSlot.head,
      name: '땀 머리띠',
      price: 10,
      style: 'headband',
      colors: [Color(0xFFF26B5E), Color(0xFFFFFFFF)],
      theme: OutfitTheme.soccer,
    ),
    Item(
      id: 'soccer_jersey',
      slot: ItemSlot.outfit,
      name: '축구복',
      price: 35,
      style: 'jersey',
      colors: [Color(0xFFF26B5E), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      theme: OutfitTheme.soccer,
    ),
    Item(
      id: 'soccer_shoes',
      slot: ItemSlot.shoes,
      name: '축구화',
      price: 20,
      style: 'cleats',
      colors: [Color(0xFF3D3D3D), Color(0xFFFFCF4D)],
      theme: OutfitTheme.soccer,
    ),
    Item(
      id: 'soccer_ball',
      slot: ItemSlot.back,
      name: '축구공',
      price: 15,
      style: 'ball',
      colors: [Color(0xFFFFFFFF), Color(0xFF3D3D3D)],
      theme: OutfitTheme.soccer,
    ),

    // 발레리나
    Item(
      id: 'ballet_tiara',
      slot: ItemSlot.head,
      name: '반짝 티아라',
      price: 25,
      style: 'tiara',
      colors: [Color(0xFFD5DCE4), Color(0xFFF59AB5)],
      theme: OutfitTheme.ballet,
    ),
    Item(
      id: 'ballet_tutu',
      slot: ItemSlot.outfit,
      name: '발레 튀튀',
      price: 40,
      style: 'tutu',
      colors: [Color(0xFFF59AB5), Color(0xFFFFE3EC)],
      theme: OutfitTheme.ballet,
    ),
    Item(
      id: 'ballet_shoes',
      slot: ItemSlot.shoes,
      name: '발레 슈즈',
      price: 20,
      style: 'ballet',
      colors: [Color(0xFFF7B8CC), Color(0xFFF59AB5)],
      theme: OutfitTheme.ballet,
    ),
  ];

  /// 이전 버전에만 있던 아이템과 가격 (저장값을 옮길 때 코인으로 돌려준다)
  static const Map<String, int> retired = {
    'cap_red': 10,
    'helmet_space': 35,
    'hat_explorer': 20,
    'hood_dino': 25,
    'tee_stripe': 10,
    'armor_knight': 40,
    'suit_space': 45,
    'suit_dino': 35,
    'shoes_sneaker': 10,
    'shoes_boots': 15,
    'glasses_round': 15,
    'necklace_star': 20,
    'bag_small': 15,
  };

  static final Map<String, Item> _byId = {for (final i in all) i.id: i};

  static Item? byId(String id) => _byId[id];

  static bool exists(String id) => _byId.containsKey(id);

  static List<Item> bySlot(ItemSlot slot) =>
      all.where((i) => i.slot == slot).toList(growable: false);

  static List<Item> byTheme(OutfitTheme theme) =>
      all.where((i) => i.theme == theme).toList(growable: false);
}
