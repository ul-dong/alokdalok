import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../l10n/l10n.dart';
import '../services/eye_guard.dart';
import 'common.dart';
import 'eye_guard_overlay.dart';

/// 부모 확인을 연다. 덧셈 문제(각 6~9)를 숫자 패드로 맞히면 true,
/// 닫으면 false. 설정에서 부모 확인을 꺼 두었으면 바로 true.
///
/// 홈의 톱니바퀴(설정 들어가기)처럼 부모님만 해야 하는 일 앞에서 부른다:
/// ```dart
/// if (await confirmParent(context)) { /* 설정 열기 */ }
/// ```
///
/// [force]가 true면 설정에서 부모 확인을 꺼 두었어도 항상 묻는다 (부모용 결제 화면 앞).
Future<bool> confirmParent(
  BuildContext context, {
  Random? random,
  bool force = false,
}) async {
  final state = context.getInheritedWidgetOfExactType<AppScope>()?.notifier;
  if (state != null && !state.parentGateOn && !force) return true;
  state?.audio.say(L10n.current.gate_callParentSay);
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: L10n.current.settings_gateSection,
    barrierColor: const Color(0x99402A1C),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) => Material(
      type: MaterialType.transparency,
      child: ParentalGate(
        random: random,
        onResult: (ok) => Navigator.of(ctx).pop(ok),
      ),
    ),
    transitionBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
  return ok ?? false;
}

/// 부모 확인 판: 왼쪽에 "7 + 8 = ?", 오른쪽에 큰 숫자 패드.
/// 맞히면 `onResult(true)`, 닫기를 누르면 `onResult(false)`.
/// 틀리면 새 문제를 낸다 (아이가 숫자를 마구 눌러서 통과하기 어렵게).
class ParentalGate extends StatefulWidget {
  const ParentalGate({super.key, required this.onResult, this.random});

  final ValueChanged<bool> onResult;
  final Random? random;

  /// 문제 글자 ("7 + 8")를 찾는 키 (테스트용)
  static const questionKey = ValueKey('parental-question');

  /// 각 수는 6~9 (합 12~18, 항상 두 자리)
  static const minAddend = 6;
  static const maxAddend = 9;

  static (int, int) makeQuestion(Random r) => (
    minAddend + r.nextInt(maxAddend - minAddend + 1),
    minAddend + r.nextInt(maxAddend - minAddend + 1),
  );

  /// 화면에 보이는 문제 글자에서 답을 계산한다 (테스트용)
  static int answerOf(String question) => question
      .split('+')
      .map((p) => int.parse(p.trim()))
      .fold(0, (a, b) => a + b);

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate> {
  late final Random _rng = widget.random ?? Random();
  late (int, int) _q = ParentalGate.makeQuestion(_rng);
  String _input = '';
  bool _wrong = false;

  int get _answer => _q.$1 + _q.$2;

  void _press(int digit) {
    if (_input.length >= 2) return;
    setState(() {
      _wrong = false;
      _input += '$digit';
    });
    if (_input.length == 2) _check();
  }

  void _erase() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _check() {
    if (_input.isEmpty) return;
    if (int.tryParse(_input) == _answer) {
      widget.onResult(true);
      return;
    }
    setState(() {
      _wrong = true;
      _input = '';
      _q = ParentalGate.makeQuestion(_rng);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 부모 확인이 떠 있는 동안은 눈 지킴이 카메라를 끈다 (부모님 화면)
    return EyeWatch(
      kind: EyeScreen.parent,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 420),
              child: CreamCard(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, c) {
                    const gap = 6.0;
                    final key = ((c.maxHeight - gap * 3) / 4).clamp(44.0, 72.0);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(child: _question(key)),
                        const SizedBox(width: 16),
                        _Keypad(
                          size: key,
                          gap: gap,
                          onDigit: _press,
                          onErase: _erase,
                          onOk: _check,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(double key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RoundIconButton(
              icon: Icons.close_rounded,
              label: context.l10n.common_close,
              size: 60,
              onTap: () => widget.onResult(false),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FitBox(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.gate_title,
                  style: const TextStyle(
                    fontSize: TextSizes.number,
                    color: Palette.text,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        FitBox(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                '${_q.$1} + ${_q.$2}',
                key: ParentalGate.questionKey,
                style: const TextStyle(fontSize: 52, color: Palette.text),
              ),
              const Text(
                ' = ',
                style: TextStyle(fontSize: 52, color: Palette.textSoft),
              ),
              Container(
                width: 104,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _wrong ? Palette.pink : Palette.creamDeep,
                    width: 3,
                  ),
                ),
                child: Text(
                  _input.isEmpty ? '?' : _input,
                  style: TextStyle(
                    fontSize: 48,
                    color: _input.isEmpty ? Palette.creamDeep : Palette.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FitBox(
          alignment: Alignment.centerLeft,
          child: Text(
            _wrong ? context.l10n.gate_wrong : context.l10n.gate_hint,
            style: TextStyle(
              fontSize: TextSizes.body,
              color: _wrong ? const Color(0xFFD9536F) : Palette.textSoft,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

/// 3×4 숫자 패드 (1~9, 지우기, 0, 확인)
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.size,
    required this.gap,
    required this.onDigit,
    required this.onErase,
    required this.onOk,
  });

  final double size;
  final double gap;
  final ValueChanged<int> onDigit;
  final VoidCallback onErase;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    Widget digit(int d) => _Key(
      size: size,
      label: context.l10n.gate_digit(d),
      onTap: () => onDigit(d),
      child: Text(
        '$d',
        style: TextStyle(fontSize: size * .5, color: Palette.text),
      ),
    );
    final rows = [
      [digit(1), digit(2), digit(3)],
      [digit(4), digit(5), digit(6)],
      [digit(7), digit(8), digit(9)],
      [
        _Key(
          size: size,
          label: context.l10n.gate_delete,
          color: Palette.creamDeep,
          onTap: onErase,
          child: Icon(
            Icons.backspace_rounded,
            size: size * .42,
            color: Palette.textSoft,
          ),
        ),
        digit(0),
        _Key(
          size: size,
          label: context.l10n.gate_ok,
          color: Palette.mint,
          onTap: onOk,
          child: Icon(
            Icons.check_rounded,
            size: size * .55,
            color: Colors.white,
          ),
        ),
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) SizedBox(width: gap),
                rows[i][j],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.size,
    required this.label,
    required this.onTap,
    required this.child,
    this.color = Colors.white,
  });

  final double size;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      width: size * 1.15,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: Palette.creamDeep, width: 2),
        boxShadow: const [
          BoxShadow(color: Palette.creamDeep, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    ),
  );
}
