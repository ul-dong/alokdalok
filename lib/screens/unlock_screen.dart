import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../l10n/l10n.dart';
import '../services/entitlement.dart';
import '../services/eye_guard.dart';
import '../widgets/common.dart';
import '../widgets/eye_guard_overlay.dart';
import '../widgets/parental_gate.dart';

/// 부모 확인을 거쳐 부모용 "전체 놀이 열기" 화면을 연다. 결제가 꺼져 있으면 아무것도 하지 않는다.
///
/// 부모 확인은 설정에서 꺼 두었어도 항상 묻는다 ([confirmParent]의 `force`).
/// 아이 화면(단계 고르기의 잠긴 단계, 상점의 잠긴 물건)과 설정 화면이 이 함수만 부른다.
Future<void> openUnlock(BuildContext context) async {
  final state = AppScope.read(context);
  if (!state.entitlement.enabled) return;
  if (!await confirmParent(context, force: true)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(softRoute(const UnlockScreen()));
}

/// 부모용 1회 전체 해금 화면. 글자로만 쓰고(음성·캐릭터 없음), 가격은 스토어가 준 현지 글자를 그대로 쓴다.
/// 떠 있는 동안은 부모님 화면이라 눈 지킴이 카메라를 열지 않는다.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  /// 사기 버튼 키 (테스트용)
  static const buyKey = ValueKey('unlock-buy');

  /// 구매 복원 버튼 키 (테스트용)
  static const restoreKey = ValueKey('unlock-restore');

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  late final Entitlement _ent = AppScope.read(context).entitlement;

  @override
  void initState() {
    super.initState();
    // 아직 값을 못 받았으면 다시 연결해 본다 (오프라인이면 조용히 "연결할 수 없어요")
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ent.refresh();
    });
  }

  String? _status(AppLocalizations l, UnlockFlow f) => switch (f) {
    UnlockFlow.idle || UnlockFlow.ready => null,
    UnlockFlow.connecting => l.unlock_connecting,
    UnlockFlow.unavailable => l.unlock_unavailable,
    UnlockFlow.purchasing => l.unlock_purchasing,
    UnlockFlow.pending => l.unlock_pending,
    UnlockFlow.restoring => l.unlock_restoring,
    UnlockFlow.nothingToRestore => l.unlock_nothing,
    UnlockFlow.canceled => l.unlock_canceled,
    UnlockFlow.failed => l.unlock_failed,
    UnlockFlow.unlocked => l.unlock_done,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.height < 380;
    final twoColumns =
        screen.height < 560 && screen.width >= screen.height * 1.4;
    _wide = twoColumns;
    final buttonHeight = compact ? 62.0 : 70.0;

    Widget text(String s, double size, {Color color = Palette.text}) => Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: size, color: color, height: 1.35),
    );

    return EyeWatch(
      kind: EyeScreen.parent,
      child: Scaffold(
        backgroundColor: Palette.skyBottom,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _ent,
            builder: (context, _) {
              final f = _ent.flow;
              final price = _ent.price;
              final busy =
                  f == UnlockFlow.connecting ||
                  f == UnlockFlow.purchasing ||
                  f == UnlockFlow.restoring;
              final status = _status(l, f);
              final done = _ent.unlocked;

              final buttons = <Widget>[
                if (done)
                  _button(
                    label: l.cameraNotice_ok,
                    height: buttonHeight,
                    color: Palette.yellow,
                    edge: Palette.coinDeep,
                    onTap: () => Navigator.of(context).pop(),
                  )
                else ...[
                  if (price != null)
                    _button(
                      key: UnlockScreen.buyKey,
                      label: l.unlock_buy(price),
                      height: buttonHeight,
                      color: Palette.yellow,
                      edge: Palette.coinDeep,
                      onTap: busy || f == UnlockFlow.pending ? null : _ent.buy,
                    )
                  else if (f == UnlockFlow.unavailable)
                    _button(
                      label: l.unlock_retry,
                      height: buttonHeight,
                      onTap: _ent.refresh,
                    ),
                  _button(
                    key: UnlockScreen.restoreKey,
                    label: l.unlock_restore,
                    height: buttonHeight,
                    onTap: busy ? null : _ent.restore,
                  ),
                ],
              ];

              final info = <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      done ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: compact ? 28 : 34,
                      color: Palette.seaDeep,
                    ),
                    const SizedBox(width: Gaps.sm),
                    Flexible(
                      child: Text(
                        l.unlock_title,
                        style: TextStyle(
                          fontSize: compact ? 22 : TextSizes.heading,
                          color: Palette.text,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? Gaps.xs : Gaps.sm),
                text(
                  l.unlock_forParents,
                  compact ? TextSizes.caption : TextSizes.small,
                  color: Palette.textSoft,
                ),
                SizedBox(height: compact ? Gaps.sm : Gaps.md),
                text(l.unlock_body, compact ? TextSizes.body : 20),
                SizedBox(height: compact ? Gaps.xs : Gaps.sm),
                text(
                  l.unlock_terms,
                  compact ? TextSizes.caption : TextSizes.small,
                  color: Palette.textSoft,
                ),
              ];
              final statusText = status == null
                  ? null
                  : text(
                      status,
                      compact ? TextSizes.body : 19,
                      color: done ? Palette.seaDeep : Palette.text,
                    );

              // 낮은 가로 화면(휴대폰): 왼쪽 설명, 오른쪽 상태와 버튼 (버튼이 화면 밖으로 밀리지 않게)
              final Widget card;
              if (twoColumns) {
                card = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: info,
                      ),
                    ),
                    const SizedBox(width: Gaps.lg),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (statusText != null) ...[
                            statusText,
                            const SizedBox(height: Gaps.md),
                          ],
                          for (final (i, b) in buttons.indexed) ...[
                            if (i > 0) const SizedBox(height: Gaps.md),
                            b,
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                card = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...info,
                    if (statusText != null) ...[
                      SizedBox(height: compact ? Gaps.sm : Gaps.md),
                      statusText,
                    ],
                    SizedBox(height: compact ? Gaps.md : Gaps.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: Gaps.lg,
                      runSpacing: Gaps.md,
                      children: buttons,
                    ),
                  ],
                );
              }

              return Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        Gaps.lg + 64,
                        compact ? Gaps.sm : Gaps.lg,
                        Gaps.lg,
                        compact ? Gaps.sm : Gaps.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: twoColumns ? 900 : 680,
                        ),
                        child: CreamCard(
                          padding: EdgeInsets.fromLTRB(
                            compact ? Gaps.lg : Gaps.xl,
                            compact ? Gaps.md : Gaps.lg + 4,
                            compact ? Gaps.lg : Gaps.xl,
                            compact ? Gaps.md + 2 : Gaps.xl,
                          ),
                          child: card,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: Gaps.md,
                    top: Gaps.sm,
                    child: RoundIconButton(
                      icon: Icons.close_rounded,
                      label: l.common_close,
                      size: 60,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _button({
    Key? key,
    required String label,
    required double height,
    required VoidCallback? onTap,
    Color color = Colors.white,
    Color edge = Palette.creamDeep,
  }) => PillButton(
    key: key,
    semanticLabel: label,
    height: height,
    width: _wide ? double.infinity : null,
    color: color,
    edge: edge,
    enabled: onTap != null,
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: FitBox(
      child: Text(
        label,
        style: const TextStyle(fontSize: TextSizes.button, color: Palette.text),
      ),
    ),
  );

  bool _wide = false;
}
