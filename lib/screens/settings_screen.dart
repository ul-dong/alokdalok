import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../core/palette.dart';
import '../l10n/l10n.dart';
import '../l10n/phrases.dart';
import '../services/backup_code.dart';
import '../services/eye_guard.dart';
import '../services/perf_monitor.dart';
import '../services/play_clock.dart';
import '../services/save_data.dart';
import '../widgets/common.dart';
import '../widgets/eye_guard_overlay.dart';
import 'nickname_screen.dart';

// 부모님께 칸을 길게 누르면 열리는 개발 진단 칸 (한국어 전용, 번역하지 않는다)
part 'settings_diagnostics.dart';

/// 설정 (부모님용): 눈 보호, 놀이 시간, 눈 쉬기 간격, 소리, 부모 확인, 백업,
/// 닉네임, 부모용 정보와 기록 지우기.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // 부모님 화면: 떠 있는 동안 눈 지킴이 카메라를 끈다 (30cm 기준 맞추기만 잠깐 켠다)
    return EyeWatch(
      kind: EyeScreen.parent,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: PhoneWidth(
            maxWidth: 720,
            // 항목이 많지 않아 한 번에 그린다 (스크롤로 내려도 다시 만들지 않음)
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gaps.lg,
                Gaps.sm,
                Gaps.lg,
                Gaps.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.home_rounded,
                        label: context.l10n.common_home,
                        size: 60,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: Gaps.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.settings_title,
                              style: TextStyle(
                                fontSize: TextSizes.heading,
                                color: Palette.text,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              context.l10n.settings_forParents,
                              style: TextStyle(
                                fontSize: TextSizes.caption,
                                color: Palette.textSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Section(context.l10n.settings_eyeSection),
                  const _EyeGuardCard(),
                  _Section(context.l10n.settings_playTimeSection),
                  const _PlayLimitCard(),
                  _Section(context.l10n.settings_breakSection),
                  const _EyeBreakCard(),
                  _Section(context.l10n.settings_soundSection),
                  _Panel(
                    children: [
                      _ToggleRow(
                        icon: state.voiceOn
                            ? Icons.record_voice_over_rounded
                            : Icons.voice_over_off_rounded,
                        label: context.l10n.settings_voiceGuide,
                        value: state.voiceOn,
                        onChanged: (v) {
                          state.setVoice(v);
                          if (v) {
                            state.audio.say(context.l10n.settings_voiceOnSay);
                          }
                        },
                      ),
                      _RowTile(
                        icon: Icons.graphic_eq_rounded,
                        title: context.l10n.settings_voice,
                        subtitle: context.l10n.settings_voiceHint,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (style, label) in [
                              ('pack', context.l10n.settings_voiceRecorded),
                              ('teacher', context.l10n.settings_voiceDevice),
                            ]) ...[
                              const SizedBox(width: Gaps.sm),
                              _Chip(
                                label: label,
                                selected: state.voiceStyle == style,
                                onTap: () {
                                  state.setVoiceStyle(style);
                                  state.audio.say(
                                    context.l10n.settings_voiceSampleSay,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      _ToggleRow(
                        icon: state.sfxOn
                            ? Icons.music_note_rounded
                            : Icons.music_off_rounded,
                        label: context.l10n.settings_sfx,
                        value: state.sfxOn,
                        onChanged: (v) => state.setSfx(v),
                      ),
                      _ToggleRow(
                        icon: state.musicOn
                            ? Icons.queue_music_rounded
                            : Icons.music_off_rounded,
                        label: context.l10n.settings_music,
                        value: state.musicOn,
                        onChanged: (v) => state.setMusic(v),
                      ),
                    ],
                  ),
                  if (!state.audio.voiceAvailable)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        Gaps.sm,
                        Gaps.sm,
                        Gaps.sm,
                        0,
                      ),
                      child: _Note(context.l10n.settings_noTts),
                    ),
                  _Section(context.l10n.settings_language),
                  const _LanguageCard(),
                  _Section(context.l10n.settings_gateSection),
                  _Panel(
                    children: [
                      _ToggleRow(
                        icon: state.parentGateOn
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        label: context.l10n.settings_gateToggle,
                        value: state.parentGateOn,
                        onChanged: (v) => state.setParentGate(v),
                      ),
                    ],
                  ),
                  _Section(context.l10n.settings_recordSection),
                  _Panel(
                    children: [
                      _RowTile(
                        icon: Icons.badge_rounded,
                        title: Phrases.current.nickname(state.nickname),
                        subtitle: context.l10n.settings_nickname,
                        trailing: _SmallButton(
                          icon: Icons.edit_rounded,
                          label: context.l10n.settings_change,
                          semanticLabel: context.l10n.settings_changeNickname,
                          onTap: () =>
                              Navigator.of(context)
                                  .push(softRoute(const NicknameScreen())),
                        ),
                      ),
                      const _BackupCard(),
                    ],
                  ),
                  _Section(context.l10n.settings_parentNotesSection),
                  const _ParentNotes(),
                  const SizedBox(height: Gaps.xl),
                  const _HoldToReset(),
                  const SizedBox(height: Gaps.md),
                  Center(
                    child: TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: context.l10n.app_title,
                        applicationVersion: '0.1.0',
                      ),
                      child: Text(
                        context.l10n.settings_licenses,
                        style: TextStyle(
                          fontSize: TextSizes.small,
                          color: Palette.textSoft,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 부모님 화면 배경: 아이 화면보다 차분한 크림빛
const _bg = Color(0xFFF7F3EC);

/// 차분한 흰 카드 (부모님 화면용: 두꺼운 입체 대신 얇은 테두리와 옅은 그림자).
/// 여러 줄이면 사이에 가는 줄을 긋는다.
class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: const Color(0xFFEDE3D3), width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x142E1A0E),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              indent: 70,
              color: Color(0xFFF0E8DB),
            ),
          children[i],
        ],
      ],
    ),
  );
}

/// 동그란 연분홍 바탕에 담은 아이콘
class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, {this.on = true});
  final IconData icon;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: on ? Palette.pinkSoft : const Color(0xFFF2EDE5),
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      size: 24,
      color: on ? const Color(0xFFE0607E) : Palette.textSoft,
    ),
  );
}

/// 한 줄 설정: 아이콘 + 제목(+설명) + 오른쪽 조절기
class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.on = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool on;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 68),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      child: Row(
        children: [
          _TileIcon(icon, on: on),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: TextSizes.button,
                    color: Palette.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: TextSizes.caption,
                      color: Palette.textSoft,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Gaps.sm), trailing!],
        ],
      ),
    ),
  );
}

/// 켜기/끄기 스위치 모양 (줄 전체를 눌러도 바뀐다)
class _Switch extends StatelessWidget {
  const _Switch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 64,
    height: 38,
    padding: const EdgeInsets.all(4),
    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: value ? const Color(0xFF6CC79E) : const Color(0xFFE2D9CC),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => onChanged(!value),
    semanticLabel: context.l10n.settings_toggleState(
      label,
      value ? context.l10n.common_on : context.l10n.common_off,
    ),
    child: _RowTile(
      icon: icon,
      title: label,
      on: value,
      trailing: _Switch(value: value),
    ),
  );
}

/// 작은 글 (부모님용 설명)
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: TextSizes.caption,
      color: Palette.textSoft,
      height: 1.45,
    ),
  );
}

/// 점 목록 (글꼴에 없는 가운뎃점 대신 그린 점)
class _Bullets extends StatelessWidget {
  const _Bullets(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final t in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8, right: 10),
                decoration: const BoxDecoration(
                  color: Palette.pink,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  t,
                  style: const TextStyle(
                    fontSize: TextSizes.small,
                    color: Palette.text,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// 하나를 고르는 알약 (고른 것은 노랗게)
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? Palette.yellow : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: selected ? Palette.coinDeep : const Color(0xFFE6DCCB),
          width: selected ? 2 : 1.5,
        ),
        boxShadow: selected
            ? Depth.flat(Palette.coinDeep, depth: 3)
            : Depth.flat(const Color(0xFFEDE3D3), depth: 3),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: const TextStyle(fontSize: TextSizes.body, color: Palette.text),
        ),
      ),
    ),
  );
}

/// 흰 알약 작은 버튼 (아이콘 + 글자)
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });
  final IconData icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: semanticLabel ?? label,
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6DCCB), width: 1.5),
        boxShadow: Depth.flat(const Color(0xFFEDE3D3), depth: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Palette.text),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: TextSizes.body,
              color: Palette.text,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 아이가 실수로 기록을 지우지 않도록 3초 동안 눌러야 지워진다.
class _HoldToReset extends StatefulWidget {
  const _HoldToReset();

  @override
  State<_HoldToReset> createState() => _HoldToResetState();
}

class _HoldToResetState extends State<_HoldToReset> {
  Timer? _timer;
  double _progress = 0;

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _progress += 50 / 3000);
      if (_progress >= 1) {
        t.cancel();
        _progress = 0;
        AppScope.read(context).resetAll();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _progress = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _start(),
    onTapUp: (_) => _stop(),
    onTapCancel: _stop,
    child: Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: const Color(0xFFF0C9C9), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: _progress,
            child: Container(color: const Color(0xFFFFD9D9)),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 22,
                  color: Color(0xFFC9566F),
                ),
                SizedBox(width: 6),
                Text(
                  context.l10n.settings_resetAll,
                  style: TextStyle(
                    fontSize: TextSizes.body,
                    color: Color(0xFFC9566F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 눈 지킴이 설정: 켜기/끄기, 지금 상태, 30cm 기준 맞추기
class _EyeGuardCard extends StatelessWidget {
  const _EyeGuardCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final eye = state.eye;
    return ListenableBuilder(
      listenable: eye,
      builder: (context, _) {
        final on = state.eyeGuardOn;
        final d = eye.distanceCm;
        final r = eye.last;
        String status;
        if (!eye.supported) {
          status = context.l10n.settings_eyeUnsupported;
        } else if (on && eye.heatOff) {
          status = context.l10n.settings_eyeHeatOff;
        } else if (eye.error != null) {
          status = eye.error!;
        } else if (!on) {
          status = context.l10n.settings_eyeAbout;
        } else if (!eye.running) {
          status = context.l10n.settings_eyeIdle;
        } else if (r == null || d == null) {
          status = context.l10n.settings_eyeSearching;
        } else {
          final angle =
              r.yaw.abs() <= EyeRules.maxYaw &&
                  r.pitch.abs() <= EyeRules.maxPitch &&
                  r.roll.abs() <= EyeRules.maxRoll
              ? context.l10n.settings_eyePostureGood
              : context.l10n.settings_eyePostureBad;
          status = context.l10n.settings_eyeNow(d.round(), angle);
        }
        return _Panel(
          children: [
            // 다른 설정과 같은 모양의 켜기/끄기
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: eye.supported ? () => state.setEyeGuard(!on) : null,
              child: _RowTile(
                icon: on
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                title: context.l10n.settings_eyeGuard,
                subtitle: status,
                on: on,
                trailing: _Switch(value: on),
              ),
            ),
            if (on)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settings_eyeDistance,
                      style: TextStyle(
                        fontSize: TextSizes.small,
                        color: Palette.text,
                      ),
                    ),
                    const SizedBox(height: Gaps.sm),
                    _Choices(
                      values: SafetyRules.eyeDistanceChoices,
                      selected: state.eyeDistanceCm,
                      label: (cm) => '${cm}cm',
                      onPick: (cm) => state.setEyeDistance(cm),
                    ),
                    if (eye.supported) ...[
                      const SizedBox(height: Gaps.md),
                      Wrap(
                        spacing: Gaps.sm,
                        runSpacing: Gaps.sm,
                        children: [
                          _SmallButton(
                            icon: Icons.straighten_rounded,
                            label: context.l10n.settings_eyeCalibrate,
                            onTap: () async {
                              final ok = await state.calibrateEye();
                              if (!context.mounted) return;
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? context.l10n.settings_eyeCalibrated
                                        : context.l10n.settings_eyeNoFace,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (eye.calibration != null)
                            _SmallButton(
                              icon: Icons.close_rounded,
                              label: context.l10n.settings_eyeCalibrationClear,
                              onTap: () => state.resetEyeCalibration(),
                            ),
                        ],
                      ),
                      const SizedBox(height: Gaps.sm),
                      _Note(context.l10n.settings_eyeCalibrateHow),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 설정 묶음 제목
class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: TextSizes.body, color: Palette.textSoft),
    ),
  );
}

/// 하나만 고르는 알약 버튼 묶음 (좁으면 다음 줄로)
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onPick,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Gaps.sm,
    runSpacing: Gaps.sm + 2,
    children: [
      for (final v in values)
        _Chip(label: label(v), selected: v == selected, onTap: () => onPick(v)),
    ],
  );
}

String _minutes(Duration d) =>
    L10n.current.settings_minutes((d.inSeconds / 60).ceil());

/// 하루 놀이 시간: 제한 없음·10·15·20·30·45·60분
class _PlayLimitCard extends StatelessWidget {
  const _PlayLimitCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final play = state.play;
    final left = play.remaining;
    return _Panel(
      children: [
        _RowTile(
          icon: Icons.timer_rounded,
          title: context.l10n.settings_dailyLimit,
          subtitle:
              context.l10n.settings_playUsed(_minutes(play.used)) +
              (left == null
                  ? ''
                  : context.l10n.settings_playLeft(_minutes(left))) +
              (play.bonusMinutes > 0
                  ? context.l10n.settings_playBonus(play.bonusMinutes)
                  : ''),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Choices(
                values: SafetyRules.limitChoices,
                selected: state.playLimitMin,
                label: (m) => m == 0
                    ? context.l10n.settings_noLimit
                    : context.l10n.settings_minutes(m),
                onPick: (m) => state.setPlayLimit(m),
              ),
              const SizedBox(height: Gaps.sm),
              _Note(context.l10n.settings_limitNote),
            ],
          ),
        ),
      ],
    );
  }
}

/// 언어: 자동(기기 언어) / 한국어 / English
class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    return _Panel(
      children: [
        _RowTile(
          icon: Icons.translate_rounded,
          title: l.settings_language,
          subtitle: l.settings_languageHint,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 14, 14),
          child: _Choices<String>(
            values: SaveData.languages,
            selected: state.language,
            label: (v) => v == AppLanguage.auto
                ? l.settings_languageAuto
                : AppLanguage.nativeName(v),
            onPick: (v) => state.setLanguage(v),
          ),
        ),
      ],
    );
  }
}

/// 눈 쉬기 간격: 10분 / 20분
class _EyeBreakCard extends StatelessWidget {
  const _EyeBreakCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return _Panel(
      children: [
        _RowTile(
          icon: Icons.landscape_rounded,
          title: context.l10n.settings_break,
          subtitle: context.l10n.settings_breakNote,
          trailing: _Choices(
            values: SafetyRules.breakChoices,
            selected: state.eyeBreakMin,
            label: (m) => context.l10n.settings_breakEvery(m),
            onPick: (m) => state.setEyeBreak(m),
          ),
        ),
      ],
    );
  }
}

/// 백업: 'ALOK1-' 글자 만들기(복사) / 붙여 넣어 복구
class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TileIcon(Icons.cloud_off_rounded),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.l10n.settings_backup,
                  style: TextStyle(
                    fontSize: TextSizes.button,
                    color: Palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          _Note(context.l10n.settings_backupNote),
          const SizedBox(height: Gaps.md),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              _SmallButton(
                icon: Icons.copy_rounded,
                label: context.l10n.settings_backupMake,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _BackupExportDialog(),
                ),
              ),
              _SmallButton(
                icon: Icons.restore_rounded,
                label: context.l10n.settings_backupRestore,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const BackupRestoreDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 낮은 화면에서도 잘리지 않는 대화 상자 틀
class _SheetDialog extends StatelessWidget {
  const _SheetDialog({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Palette.cream,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.xl),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: TextSizes.title,
                color: Palette.text,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _BackupExportDialog extends StatefulWidget {
  const _BackupExportDialog();

  @override
  State<_BackupExportDialog> createState() => _BackupExportDialogState();
}

class _BackupExportDialogState extends State<_BackupExportDialog> {
  late final String _code = AppScope.read(context).exportBackup();
  bool _copied = false;

  @override
  Widget build(BuildContext context) => _SheetDialog(
    title: context.l10n.settings_backupText,
    children: [
      Container(
        constraints: const BoxConstraints(maxHeight: 110),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: Palette.creamDeep, width: 2),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _code,
            style: const TextStyle(
              fontSize: TextSizes.caption,
              color: Palette.text,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _copied
            ? context.l10n.settings_backupCopied
            : context.l10n.settings_backupCopyHint,
        style: const TextStyle(
          fontSize: TextSizes.caption,
          color: Palette.textSoft,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 10,
        children: [
          PillButton(
            height: 56,
            semanticLabel: context.l10n.common_close,
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.common_close,
              style: TextStyle(
                fontSize: TextSizes.body,
                color: Palette.textSoft,
              ),
            ),
          ),
          PillButton(
            height: 56,
            color: Palette.yellow,
            edge: Palette.coinDeep,
            semanticLabel: context.l10n.settings_copy,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _code));
              if (mounted) setState(() => _copied = true);
            },
            child: Text(
              context.l10n.settings_copy,
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
          ),
        ],
      ),
    ],
  );
}

/// 백업 글자를 붙여 넣어 복구. 잘못된 글자는 이유를 알려 주고 기록은 그대로 둔다.
class BackupRestoreDialog extends StatefulWidget {
  const BackupRestoreDialog({super.key});

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || !mounted) return;
    setState(() {
      _text.text = t;
      _error = null;
    });
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await AppScope.read(context).restoreBackup(_text.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = BackupCode.message(err);
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(context.l10n.settings_backupRestored)),
    );
  }

  @override
  Widget build(BuildContext context) => _SheetDialog(
    title: context.l10n.settings_backupRestore,
    children: [
      TextField(
        controller: _text,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(
          fontSize: TextSizes.caption,
          color: Palette.text,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          hintText: 'ALOK1-…',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _error ?? context.l10n.settings_backupRestoreNote,
        style: TextStyle(
          fontSize: TextSizes.caption,
          color: _error != null ? const Color(0xFFD9536F) : Palette.textSoft,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 10,
        children: [
          PillButton(
            height: 56,
            semanticLabel: context.l10n.common_close,
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.common_close,
              style: TextStyle(
                fontSize: TextSizes.body,
                color: Palette.textSoft,
              ),
            ),
          ),
          PillButton(
            height: 56,
            semanticLabel: context.l10n.settings_paste,
            onTap: _paste,
            child: Text(
              context.l10n.settings_paste,
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
          ),
          PillButton(
            height: 56,
            color: Palette.yellow,
            edge: Palette.coinDeep,
            semanticLabel: context.l10n.settings_restore,
            onTap: _restore,
            child: Text(
              context.l10n.settings_restore,
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
          ),
        ],
      ),
    ],
  );
}

/// '부모님께' 안내. 길게 누르면 아래에 눈 지킴이 진단 칸이 열린다 (숨은 칸, 다시 길게 누르면 닫힘).
class _ParentNotes extends StatefulWidget {
  const _ParentNotes();

  @override
  State<_ParentNotes> createState() => _ParentNotesState();
}

class _ParentNotesState extends State<_ParentNotes> {
  bool _diag = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GestureDetector(
        onLongPress: () => setState(() => _diag = !_diag),
        child: _Panel(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
          children: [
            _Bullets([
              context.l10n.settings_note1,
              context.l10n.settings_note2,
              context.l10n.settings_note3,
              context.l10n.settings_note4,
              context.l10n.settings_note5,
            ]),
          ],
        ),
      ),
      if (_diag) ...[
        const SizedBox(height: Gaps.md),
        const PerfDiagnosticsPanel(),
        const SizedBox(height: Gaps.md),
        const EyeDiagnosticsPanel(),
      ],
    ],
  );
}
