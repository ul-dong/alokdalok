import '../character/nickname.dart';
import '../character/zodiac.dart';
import '../data/game_objects.dart';
import '../data/item_catalog.dart';
import '../data/vehicles.dart';
import '../data/game_kinds.dart';
import '../games/common/korean_numbers.dart';
import 'game_state.dart';

/// 녹음 음성 팩에 들어가는 모든 문장 조각.
///
/// 앱이 하는 말은 "빨간 풍선이 / 세 개! / 정말 잘했어요!" 처럼 조각으로 나눌 수 있게 만들어서,
/// 조각 몇 백 개만 녹음해 두면 수천 가지 문장을 이어 붙여 말할 수 있다.
/// 여기 없는 문장(아이 이름 등)은 기기 음성(TTS)으로 말한다.
class VoiceLines {
  VoiceLines._();

  /// 통째로 쓰는 문장
  static const fixed = [
    '같이 세어 볼까요?',
    '정말 잘했어요!',
    '코인을 받았어요.',
    '스티커가 가득 찼어요.',
    '지우개로 떼어 볼까요?',
    '앞 단계를 먼저 놀아 볼까요?',
    '안녕! 오늘은 뭐 하고 놀까?',
    '안녕!',
    '반가워!',
    '숫자 놀이를 해 볼까요?',
    '색깔 놀이를 해 볼까요?',
    '안녕! 함께 놀 친구를 골라 볼까요?',
    '내 이름을 지어 줄래?',
    '목소리 안내를 켰어요.',
    '안녕! 나랑 같이 놀자!',
    '몇 개 있을까요?',
    '몇 마리 있을까요?',
    '찾아볼까요?',
    '정말 멋져요!',
    '출발!',
    '코인 10개가 필요해요.',
    '놀이하면서 모아 볼까요?',
    '화면이 너무 가까워요.',
    '조금 뒤로 가 볼까요?',
    '바르게 앉아서 봐요.',
    '화면을 똑바로 봐 주세요.',
    '잘했어요! 다시 놀아요.',
    // 놀이 시간·눈 쉬기·부모 확인
    '오늘은 여기까지!',
    '내일 또 만나요.',
    '창밖 먼 곳을 봐요.',
    '잘 쉬었어요! 다시 놀아요.',
    '부모님을 불러 주세요.',
    '15분 더 놀 수 있어요.',
    // 모양·크기·짝 맞추기 놀이
    '모양 놀이를 해 볼까요?',
    '크기 놀이를 해 볼까요?',
    '짝 맞추기를 해 볼까요?',
    '다시 찾아볼까요?',
    '똑같은 모양을 찾아볼까요?',
    '똑같은 그림 두 장을 찾아볼까요?',
    '똑같은',
    '똑같아요!',
    '가장',
    // 화면과 버튼 이름 (누르면 말해 준다)
    '놀이터 가기',
    '내 캐릭터',
    '꾸미기 상점',
    '집으로',
    '뒤로',
    '다시 듣기',
    '놀이터에 왔어요!',
    '어디에서 놀까요?',
    '꾹 누르고 있어요.',
  ];

  static String _subject(String w) => '$w${hasBatchim(w) ? '이' : '가'}';
  static String _topic(String w) => '$w${hasBatchim(w) ? '은' : '는'}';
  static String _object(String w) => '$w${hasBatchim(w) ? '을' : '를'}';

  /// 전체 목록 (중복 없음, 순서 고정)
  static List<String> all() {
    final out = <String>{...fixed};

    // 숫자 세기: 하나, 둘 … / 한 개!, 두 마리!
    out.addAll(KoreanNumbers.counting);
    for (var n = 1; n <= 10; n++) {
      for (final unit in ['개', '마리']) {
        out.add('${KoreanNumbers.pieces(n, unit)}!');
      }
    }

    // 사물 이름 (+ 색): 사과가 / 빨간 풍선은 / 파란 자동차를
    final labels = <String>[
      for (final k in ObjectKind.values) k.ko,
      for (final c in GameColor.extended)
        for (final k in ObjectKind.values) '${c.adjective} ${k.ko}',
    ];
    for (final l in labels) {
      out
        ..add(_subject(l))
        ..add(_topic(l))
        ..add(_object(l));
    }

    // 색 이름: 빨간색! / 이건 빨간색이에요. / 빨간색을 찾아볼까요?
    for (final c in GameColor.extended) {
      out
        ..add('${c.name}!')
        ..add('이건 ${c.name}이에요.')
        ..add('${_object(c.name)} 찾아볼까요?');
    }

    // 모양 놀이: 동그라미! / 동그라미를 / 이건 동그라미예요.
    for (final sh in ShapeKind.values) {
      out
        ..add('${sh.ko}!')
        ..add(sh.object)
        ..add(sh.thisIs);
    }

    // 크기 놀이: 큰 사과를 / 작은 오리를 (+ "가장")
    for (final a in SizeAsk.values) {
      for (final k in ObjectKind.values) {
        out.add('${a.adjective} ${k.object}');
      }
    }

    // 짝 맞추기: 사과! / 빨간 사과! (같은 물건 다른 색 단계)
    for (final k in ObjectKind.values) {
      out.add('${k.ko}!');
      for (final c in GameColor.extended) {
        out.add('${c.adjective} ${k.ko}!');
      }
    }

    // 상점: 아이템·탈것 이름
    for (final i in ItemCatalog.all) {
      out.add(i.name);
    }
    for (final v in Vehicles.all) {
      out.add(v.name);
    }

    // 색칠
    for (final p in Vehicles.paints) {
      out
        ..add(p.name)
        ..add('${p.name}으로 칠했어요!')
        ..add(_topic(p.name));
    }

    // 친구 고르기
    for (final z in Zodiac.values) {
      out.add(z.hello);
    }

    // 놀이터 기구: "미끄럼틀! 숫자 놀이를 해 볼까요?"
    for (final g in GameKind.values) {
      out
        ..add('${g.equipment}!')
        ..add(g.invite.substring(g.equipment.length + 2));
    }

    // 이름을 비워 두면 지어 주는 이름 ("별이, 반가워!")
    out.addAll(Nickname.randomPool);
    return out.toList();
  }
}

/// 녹음 음성 팩: 문장 → 파일 목록. 문장을 앞에서부터 가장 긴 조각으로 맞춰 나간다.
class VoicePack {
  VoicePack(Map<String, String> files) : _files = files {
    _maxLen = files.keys.fold(0, (m, k) => k.length > m ? k.length : m);
  }

  final Map<String, String> _files;
  late final int _maxLen;

  bool get isEmpty => _files.isEmpty;

  /// 모든 녹음 파일 이름
  Iterable<String> get files => _files.values.toSet();

  /// 조각 사이 쉼: 쉼표 뒤는 조금 길게 (숫자 세기 박자)
  static const shortPause = Duration(milliseconds: 60);
  static const commaPause = Duration(milliseconds: 380);

  /// [text]를 녹음 조각으로 나눈다. 하나라도 녹음이 없으면 null (기기 음성으로 말한다).
  List<VoiceClip>? plan(String text) {
    if (_files.isEmpty) return null;
    final clips = <VoiceClip>[];
    var i = 0;
    var comma = false;
    while (true) {
      // 조각 사이의 띄어쓰기·쉼표는 건너뛴다
      while (i < text.length && (text[i] == ' ' || text[i] == ',')) {
        if (text[i] == ',') comma = true;
        i++;
      }
      if (i >= text.length) break;
      String? hit;
      final end = (i + _maxLen).clamp(0, text.length);
      for (var j = end; j > i; j--) {
        final key = text.substring(i, j);
        if (_files.containsKey(key)) {
          // 단어 중간에서 끊기지 않게: 조각 뒤는 끝이거나 띄어쓰기/쉼표여야 한다
          if (j == text.length || text[j] == ' ' || text[j] == ',') {
            hit = key;
            break;
          }
        }
      }
      if (hit == null) return null;
      clips.add(
        VoiceClip(
          _files[hit]!,
          pauseBefore: clips.isEmpty
              ? Duration.zero
              : (comma ? commaPause : shortPause),
        ),
      );
      comma = false;
      i += hit.length;
    }
    return clips.isEmpty ? null : clips;
  }
}

class VoiceClip {
  const VoiceClip(this.file, {this.pauseBefore = Duration.zero});
  final String file;
  final Duration pauseBefore;
}
