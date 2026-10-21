import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../core/palette.dart';
import '../services/backup_code.dart';
import '../services/eye_guard.dart';
import '../services/play_clock.dart';
import '../widgets/common.dart';
import 'nickname_screen.dart';

/// 설정 (부모님용): 눈 보호, 놀이 시간, 눈 쉬기 간격, 소리, 부모 확인, 백업,
/// 닉네임, 부모용 정보와 기록 지우기.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
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
                      label: '집으로',
                      size: 60,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: Gaps.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '설정',
                            style: TextStyle(
                              fontSize: TextSizes.heading,
                              color: Palette.text,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            '부모님용',
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
                const _Section('눈 보호'),
                const _EyeGuardCard(),
                const _Section('놀이 시간'),
                const _PlayLimitCard(),
                const _Section('눈 쉬기 간격'),
                const _EyeBreakCard(),
                const _Section('소리'),
                _Panel(
                  children: [
                    _ToggleRow(
                      icon: state.voiceOn
                          ? Icons.record_voice_over_rounded
                          : Icons.voice_over_off_rounded,
                      label: '목소리 안내',
                      value: state.voiceOn,
                      onChanged: (v) {
                        state.setVoice(v);
                        if (v) state.audio.say('목소리 안내를 켰어요.');
                      },
                    ),
                    _RowTile(
                      icon: Icons.graphic_eq_rounded,
                      title: '목소리',
                      subtitle: '녹음한 목소리 또는 기기 음성',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (style, label) in const [
                            ('pack', '녹음'),
                            ('teacher', '기기'),
                          ]) ...[
                            const SizedBox(width: Gaps.sm),
                            _Chip(
                              label: label,
                              selected: state.voiceStyle == style,
                              onTap: () {
                                state.setVoiceStyle(style);
                                state.audio.say('안녕! 나랑 같이 놀자!');
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
                      label: '효과음',
                      value: state.sfxOn,
                      onChanged: (v) => state.setSfx(v),
                    ),
                    _ToggleRow(
                      icon: state.musicOn
                          ? Icons.queue_music_rounded
                          : Icons.music_off_rounded,
                      label: '배경 음악',
                      value: state.musicOn,
                      onChanged: (v) => state.setMusic(v),
                    ),
                  ],
                ),
                if (!state.audio.voiceAvailable)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(Gaps.sm, Gaps.sm, Gaps.sm, 0),
                    child: _Note(
                      '이 기기에서는 한국어 음성을 찾지 못했어요. 기기 설정에서 한국어 TTS를 설치하면 들을 수 있어요.',
                    ),
                  ),
                const _Section('부모 확인'),
                _Panel(
                  children: [
                    _ToggleRow(
                      icon: state.parentGateOn
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      label: '설정 전에 덧셈 문제',
                      value: state.parentGateOn,
                      onChanged: (v) => state.setParentGate(v),
                    ),
                  ],
                ),
                const _Section('기록'),
                _Panel(
                  children: [
                    _RowTile(
                      icon: Icons.badge_rounded,
                      title: state.nickname,
                      subtitle: '닉네임',
                      trailing: _SmallButton(
                        icon: Icons.edit_rounded,
                        label: '바꾸기',
                        semanticLabel: '닉네임 바꾸기',
                        onTap: () =>
                            Navigator.of(context)
                                .push(softRoute(const NicknameScreen())),
                      ),
                    ),
                    const _BackupCard(),
                  ],
                ),
                const _Section('부모님께'),
                const _Panel(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
                  children: [
                    _Bullets([
                      '회원가입, 서버, 광고, 추적, 현금 결제가 없습니다.',
                      '닉네임과 진행 기록은 이 기기 안에만 저장됩니다.',
                      '코인은 놀이로만 모으고, 꾸미기 아이템에만 씁니다.',
                      '한 판은 5문제(약 1~2분)입니다.',
                      '눈 지킴이를 켜면 앞카메라 영상을 이 기기 안에서만 살펴보고, 저장하거나 보내지 않습니다.',
                    ]),
                  ],
                ),
                const SizedBox(height: Gaps.xl),
                const _HoldToReset(),
                const SizedBox(height: Gaps.md),
                Center(
                  child: TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: '알록달록 꼬마 놀이터',
                      applicationVersion: '0.1.0',
                    ),
                    child: const Text(
                      '오픈소스 라이선스',
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
    semanticLabel: '$label ${value ? '켜짐' : '꺼짐'}',
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
          const Center(
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
                  '기록 모두 지우기 (3초 꾹 누르기)',
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
          status = '이 기기에서는 쓸 수 없어요';
        } else if (eye.error != null) {
          status = eye.error!;
        } else if (!on) {
          status = '앞카메라로 화면과의 거리(30cm 이상)와 바른 자세를 살펴봐요';
        } else if (r == null || d == null) {
          status = '얼굴을 찾는 중이에요…';
        } else {
          final angle =
              r.yaw.abs() <= EyeRules.maxYaw &&
                  r.pitch.abs() <= EyeRules.maxPitch &&
                  r.roll.abs() <= EyeRules.maxRoll
              ? '자세 좋아요'
              : '자세가 비뚤어졌어요';
          status = '지금 거리 약 ${d.round()}cm, $angle';
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
                title: '눈 지킴이',
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
                    const Text(
                      '이보다 가까우면 쉬어 가요',
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
                            label: '30cm 기준 맞추기',
                            onTap: () async {
                              final ok = await state.calibrateEye();
                              if (!context.mounted) return;
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? '지금 거리를 30cm 기준으로 저장했어요'
                                        : '얼굴이 보이지 않아요. 카메라를 보고 다시 눌러 주세요',
                                  ),
                                ),
                              );
                            },
                          ),
                          if (eye.calibration != null)
                            _SmallButton(
                              icon: Icons.close_rounded,
                              label: '기준 지우기',
                              onTap: () => state.resetEyeCalibration(),
                            ),
                        ],
                      ),
                      const SizedBox(height: Gaps.sm),
                      const _Note(
                        '정확하게 하려면: 아이 눈에서 30cm(자 하나) 떨어진 곳에 화면을 두고, 아이가 화면을 볼 때 "30cm 기준 맞추기"를 눌러 주세요.',
                      ),
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
class _Choices extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onPick,
  });

  final List<int> values;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onPick;

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

String _minutes(Duration d) => '${(d.inSeconds / 60).ceil()}분';

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
          title: '하루 놀이 시간',
          subtitle:
              '오늘 논 시간 ${_minutes(play.used)}'
              '${left == null ? '' : ', 남은 시간 ${_minutes(left)}'}'
              '${play.bonusMinutes > 0 ? ' (더 준 시간 ${play.bonusMinutes}분)' : ''}',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Choices(
                values: SafetyRules.limitChoices,
                selected: state.playLimitMin,
                label: (m) => m == 0 ? '제한 없음' : '$m분',
                onPick: (m) => state.setPlayLimit(m),
              ),
              const SizedBox(height: Gaps.sm),
              const _Note(
                '다 되면 "오늘은 여기까지!"가 화면을 덮어요. 부모 확인 후 15분 더 놀 수 있고, 다음 날 다시 풀려요.',
              ),
            ],
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
          title: '눈 쉬기',
          subtitle:
              '이어서 놀면 20초 동안 "창밖 먼 곳을 봐요"를 보여 줘요. 앱을 5분 넘게 안 보면 쉰 것으로 쳐요.',
          trailing: _Choices(
            values: SafetyRules.breakChoices,
            selected: state.eyeBreakMin,
            label: (m) => '$m분마다',
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
          const Row(
            children: [
              _TileIcon(Icons.cloud_off_rounded),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  '백업',
                  style: TextStyle(
                    fontSize: TextSizes.button,
                    color: Palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          const _Note(
            "기록을 'ALOK1-'로 시작하는 글자로 만들어 복사해 두었다가, 다른 기기에 붙여 넣으면 그대로 옮겨져요. 서버로 보내지 않아요.",
          ),
          const SizedBox(height: Gaps.md),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              _SmallButton(
                icon: Icons.copy_rounded,
                label: '백업 글자 만들기',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _BackupExportDialog(),
                ),
              ),
              _SmallButton(
                icon: Icons.restore_rounded,
                label: '백업 글자로 복구',
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
    title: '백업 글자',
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
            ? '복사했어요. 메모나 메시지에 붙여 넣어 보관해 주세요.'
            : '아래 버튼으로 복사해서 안전한 곳에 보관해 주세요.',
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
            semanticLabel: '닫기',
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '닫기',
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
            semanticLabel: '복사하기',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _code));
              if (mounted) setState(() => _copied = true);
            },
            child: const Text(
              '복사하기',
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
    messenger?.showSnackBar(const SnackBar(content: Text('백업 글자로 기록을 되살렸어요')));
  }

  @override
  Widget build(BuildContext context) => _SheetDialog(
    title: '백업 글자로 복구',
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
        _error ?? '복구하면 지금 기기의 기록이 백업 기록으로 바뀌어요.',
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
            semanticLabel: '닫기',
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '닫기',
              style: TextStyle(
                fontSize: TextSizes.body,
                color: Palette.textSoft,
              ),
            ),
          ),
          PillButton(
            height: 56,
            semanticLabel: '붙여 넣기',
            onTap: _paste,
            child: const Text(
              '붙여 넣기',
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
          ),
          PillButton(
            height: 56,
            color: Palette.yellow,
            edge: Palette.coinDeep,
            semanticLabel: '복구하기',
            onTap: _restore,
            child: const Text(
              '복구하기',
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
          ),
        ],
      ),
    ],
  );
}
