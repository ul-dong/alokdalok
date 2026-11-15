import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../l10n/l10n.dart';
import '../services/eye_guard.dart';
import '../widgets/common.dart';
import '../widgets/eye_guard_overlay.dart';

/// 부모님 카메라 안내 (2026-11-15, 사용자 결정).
///
/// 앱을 처음 열면 친구 고르기보다 먼저 한 번 보여 준다. 설치하고 처음 여는 사람은 대개 부모님이고,
/// 아이가 친구를 고르고 이름을 지은 뒤에 띄우면 아이 혼자 누르게 되기 쉽다. 그래서 글자로만 쓰고
/// (음성·캐릭터 없음) 아이 화면보다 앞에 둔다. 설정에서 눈 지킴이를 다시 켤 때도 같은 안내를 띄운다.
///
/// - [허용하고 시작]: 이때 처음으로 기기(웹은 브라우저)의 카메라 권한을 묻는다.
///   허용되면 바로 끝, 거부되면 "눈 지킴이를 꺼 두었어요" 안내 뒤 [확인]으로 끝.
/// - [나중에]: "설정에서 다시 켤 수 있어요" 안내 뒤 [확인]으로 끝 (설정에서 열었으면 바로 끝).
///
/// 끝나면 [onDone]에 'granted' / 'denied' / 'later'를 넘긴다 (`GameState.answerCameraNotice`).
/// 떠 있는 동안은 부모님 화면이라 눈 지킴이 카메라를 열지 않는다.
class CameraNoticeScreen extends StatefulWidget {
  const CameraNoticeScreen({
    super.key,
    required this.onDone,
    this.fromSettings = false,
  });

  final ValueChanged<String> onDone;

  /// 설정에서 눈 지킴이를 켜려고 열었는지 (버튼 글자와 [나중에] 뒤 안내가 다르다)
  final bool fromSettings;

  @override
  State<CameraNoticeScreen> createState() => _CameraNoticeScreenState();
}

enum _Stage { ask, asking, later, denied }

class _CameraNoticeScreenState extends State<CameraNoticeScreen> {
  _Stage _stage = _Stage.ask;
  bool _done = false;

  void _finish(String answer) {
    if (_done) return;
    _done = true;
    widget.onDone(answer);
  }

  Future<void> _allow() async {
    if (_stage != _Stage.ask) return;
    setState(() => _stage = _Stage.asking);
    final ok = await AppScope.read(context).requestCamera();
    if (!mounted) return;
    if (ok) {
      _finish('granted');
    } else {
      setState(() => _stage = _Stage.denied);
    }
  }

  void _later() {
    if (_stage != _Stage.ask) return;
    if (widget.fromSettings) {
      _finish('later');
    } else {
      setState(() => _stage = _Stage.later);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final compact = MediaQuery.sizeOf(context).height < 380;
    final buttonHeight = compact ? 62.0 : 70.0;

    Widget text(String s, double size, {Color color = Palette.text}) => Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: size, color: color, height: 1.35),
    );

    final List<Widget> body;
    final List<Widget> buttons;
    switch (_stage) {
      case _Stage.ask:
      case _Stage.asking:
        final asking = _stage == _Stage.asking;
        body = [
          text(l.cameraNotice_body, compact ? TextSizes.body : 20),
          SizedBox(height: compact ? Gaps.sm : Gaps.md),
          text(
            l.cameraNotice_detail,
            compact ? TextSizes.caption : TextSizes.small,
            color: Palette.textSoft,
          ),
        ];
        buttons = [
          _button(
            label: asking
                ? l.cameraNotice_asking
                : widget.fromSettings
                ? l.cameraNotice_allowSettings
                : l.cameraNotice_allow,
            height: buttonHeight,
            color: Palette.yellow,
            edge: Palette.coinDeep,
            onTap: asking ? null : _allow,
          ),
          _button(
            label: l.cameraNotice_later,
            height: buttonHeight,
            onTap: asking ? null : _later,
          ),
        ];
      case _Stage.later:
        body = [text(l.cameraNotice_laterDone, compact ? TextSizes.body : 20)];
        buttons = [
          _button(
            label: l.cameraNotice_ok,
            height: buttonHeight,
            width: 180,
            color: Palette.yellow,
            edge: Palette.coinDeep,
            onTap: () => _finish('later'),
          ),
        ];
      case _Stage.denied:
        body = [text(l.cameraNotice_deniedDone, compact ? TextSizes.body : 20)];
        buttons = [
          _button(
            label: l.cameraNotice_ok,
            height: buttonHeight,
            width: 180,
            color: Palette.yellow,
            edge: Palette.coinDeep,
            onTap: () => _finish('denied'),
          ),
        ];
    }

    // 부모님 화면: 떠 있는 동안 눈 지킴이 카메라를 열지 않는다
    return EyeWatch(
      kind: EyeScreen.parent,
      child: Scaffold(
        backgroundColor: Palette.skyBottom,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Center(
            // 낮은 화면에서도 넘치지 않게 (세로로만, 보통은 한 화면에 다 들어간다)
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Gaps.lg,
                vertical: compact ? Gaps.sm : Gaps.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: CreamCard(
                  padding: EdgeInsets.fromLTRB(
                    Gaps.xl,
                    compact ? Gaps.md : Gaps.lg + 4,
                    Gaps.xl,
                    compact ? Gaps.md + 2 : Gaps.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _stage == _Stage.denied || _stage == _Stage.later
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: compact ? 28 : 34,
                            color: Palette.seaDeep,
                          ),
                          const SizedBox(width: Gaps.sm),
                          Flexible(
                            child: Text(
                              l.cameraNotice_title,
                              style: TextStyle(
                                fontSize: compact ? 22 : TextSizes.heading,
                                color: Palette.text,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? Gaps.sm : Gaps.md),
                      ...body,
                      SizedBox(height: compact ? Gaps.md : Gaps.lg + 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Gaps.lg,
                        runSpacing: Gaps.md,
                        children: buttons,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button({
    required String label,
    required double height,
    required VoidCallback? onTap,
    Color color = Colors.white,
    Color edge = Palette.creamDeep,
    double? width,
  }) => PillButton(
    // 단계가 바뀌면 새 버튼으로 (앞 단계 버튼 크기에서 늘었다 줄지 않게)
    key: ValueKey('$_stage $label'),
    semanticLabel: label,
    height: height,
    width: width,
    color: color,
    edge: edge,
    enabled: onTap != null,
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Text(
      label,
      style: const TextStyle(fontSize: TextSizes.button, color: Palette.text),
    ),
  );
}
