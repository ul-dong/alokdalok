import 'package:flutter/widgets.dart' show Locale;

import '../../character/zodiac.dart';
import '../../data/game_objects.dart';
import '../../data/item_catalog.dart';
import '../../data/stages.dart';
import '../../data/vehicles.dart';
import '../../services/game_state.dart';
import '../gen/app_localizations.dart';
import '../phrases.dart';

/// 영어 녹음 음성 팩(assets/voice/en)에 넣을 문장 목록.
///
/// 아직 녹음하지 않았다 (영어에서는 모두 기기 음성 en-US로 읽는다). 녹음할 때는
/// `tool/gen_voice.command en`이 이 목록을 내보내 MeloTTS 영어 모델로 만든다.
/// 한국어 목록(voice_lines_ko.dart)처럼, 놀이 문제는 통문장으로, 나머지는 조각으로 이어 붙인다
/// ("Sunny" + "nice to meet you!", "Robot helmet!" + "So cool!").
class EnVoiceLines {
  EnVoiceLines._();

  static AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));
  static Phrases get _p => Phrases.en;

  /// 이름 자리를 뺀 나머지 조각: "{name}, nice to meet you!" → "nice to meet you!"
  static String tail(String Function(String) sentence) {
    const mark = '\u0001';
    return sentence(mark)
        .split(mark)
        .last
        .replaceFirst(RegExp(r'^[ ,.!?]+'), '');
  }

  /// 화면에서 그대로 말하는 문장 (ARB에서 [음성] 표시가 있는 것)
  static List<String> fixed() {
    final l = _l;
    return [
      l.home_helloSay,
      l.zodiac_askSay,
      l.nickname_askSay,
      l.playground_greetingSay,
      l.stage_lockedSay,
      l.number_countTogetherSay,
      l.game_praiseSay,
      l.game_doneSay,
      l.game_tryAgainSay,
      l.match_promptSay,
      l.match_sameSay,
      l.character_goSay,
      l.garage_fullSay,
      l.settings_voiceOnSay,
      l.settings_voiceSampleSay,
      l.eye_backSay,
      l.eye_tooCloseSay,
      l.eye_postureSay,
      l.hold_hintSay,
      l.gate_callParentSay,
      l.play_limitSay,
      l.play_breakSay,
      l.play_restedSay,
      l.play_moreSay,
      l.poke_helloSay,
      l.poke_ticklesSay,
      l.poke_playSay,
      l.poke_againSay,
      // 버튼 이름 (누르면 말해 준다)
      l.common_home,
      l.common_back,
      l.common_listenAgain,
      l.home_character,
      l.home_shop,
      // 이름 뒤에 붙는 조각
      tail(l.nickname_greetSay),
      tail(l.shop_boughtSay),
    ];
  }

  /// 전체 목록 (중복 없음, 순서 고정)
  static List<String> all() {
    final p = _p;
    final out = <String>{...fixed()};

    // 수 세기: One … Ten
    for (var n = 1; n <= 10; n++) {
      out.add(p.count(n));
    }

    // 물건 이름: Apple! / Red apple! / 이름표 외치기
    for (final k in ObjectKind.values) {
      out.add(p.sayName(k));
      for (final c in GameColor.extended) {
        out
          ..add(p.sayName(k, c))
          ..add(p.exclaim(p.objectLabel(k, c)));
      }
    }

    // 색 이름: Red! Great job! = "Red!" + "Great job!" 대신 통문장
    for (final c in GameColor.extended) {
      out.add(p.colorPraise(c));
      for (final t in GameColor.extended) {
        if (t.id != c.id) out.add(p.colorWrong(c, t));
      }
    }

    // 모양
    for (final s in ShapeKind.values) {
      out
        ..add(p.sayShape(s))
        ..add(p.shapePraise(s))
        ..add(p.findShape(s));
      for (final t in ShapeKind.values) {
        if (t != s) out.add(p.shapeWrong(s, t));
      }
    }
    out.add(p.findSameShape());

    // 상점·탈것: 이름, 이름!(산 뒤 "So cool!" 앞), 색칠
    for (final i in ItemCatalog.all) {
      out
        ..add(p.itemName(i))
        ..add(p.exclaim(p.itemName(i)));
    }
    for (final v in Vehicles.all) {
      out
        ..add(p.vehicleName(v))
        ..add(p.exclaim(p.vehicleName(v)));
    }
    for (final c in Vehicles.paints) {
      out
        ..add(p.paintName(c))
        ..add(p.paintedWith(c))
        ..add(p.paintNeedsCoinsAsk(c, Vehicles.paintPrice));
    }

    // 친구 인사, 놀이 이름
    for (final z in Zodiac.values) {
      out.add(p.friendHello(z));
    }
    for (final g in GameKind.values) {
      out
        ..add(p.gameInvite(g))
        ..add(p.gameNameLine(g));
    }

    // 비워 두면 지어 주는 이름 ("Sunny, nice to meet you!")
    out.addAll(p.randomNames);

    out.addAll(sentences());
    return out.toList();
  }

  /// 놀이 문제에서 나올 수 있는 문장 전부 (단계 자료에서 만든다)
  static List<String> sentences() {
    final p = _p;
    final out = <String>{};

    for (final st in Stages.number) {
      final colored =
          st.mode == NumberMode.mixColors || st.mode == NumberMode.mixBoth;
      for (final k in st.objects) {
        for (final c in colored ? st.colors : const <GameColor?>[null]) {
          for (final scattered in [false, true]) {
            out.add(p.howMany(k, c, scattered: scattered));
          }
          for (var n = st.min; n <= st.max; n++) {
            out.add(p.countAnswer(k, c, n));
          }
        }
      }
    }

    for (final st in Stages.color) {
      for (final c in st.colors) {
        for (final k in st.objects.where((k) => k.tintable)) {
          out.add(p.findColored(c, k));
        }
      }
    }

    for (final st in Stages.size) {
      for (final k in st.objects) {
        for (final a in SizeAsk.values) {
          out
            ..add(p.findSize(a, k, superlative: st.superlative))
            ..add(p.sizeWrong(a, k, superlative: st.superlative));
        }
      }
    }

    for (final st in Stages.match) {
      final faces = st.colorVariant
          ? [
              for (final k in st.objects.where((k) => k.tintable))
                for (final c in st.colors) (k, c),
            ]
          : [for (final k in st.objects) (k, null)];
      for (final (k, c) in faces) {
        out
          ..add(p.exclaim(p.objectLabel(k, c)))
          ..add(p.matchFind(k, c))
          ..add(p.matchWrong(k, c))
          ..add(p.matchMatched(k, c))
          ..add(p.matchFinished(k, c));
      }
    }
    return out.toList();
  }
}
