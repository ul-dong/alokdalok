import 'dart:async';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/eye_guard.dart';
import '../widgets/common.dart';
import 'nickname_screen.dart';

/// 설정: 음성·효과음 켜기/끄기, 닉네임, 부모용 정보와 기록 지우기.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: Palette.skyBottom,
      body: SafeArea(
        child: PhoneWidth(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.home_rounded,
                    label: '집으로',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 30, color: Palette.text),
                  ),
                ],
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 12),
              CreamCard(
                padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      size: 34,
                      color: Palette.pink,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: FitBox(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '목소리',
                          style: TextStyle(fontSize: 24, color: Palette.text),
                        ),
                      ),
                    ),
                    for (final (style, label) in const [
                      ('pack', '녹음'),
                      ('teacher', '기기'),
                    ]) ...[
                      const SizedBox(width: 8),
                      PillButton(
                        height: 52,
                        color: state.voiceStyle == style
                            ? Palette.yellow
                            : Colors.white,
                        edge: state.voiceStyle == style
                            ? Palette.coinDeep
                            : Palette.creamDeep,
                        semanticLabel: label,
                        onTap: () {
                          state.setVoiceStyle(style);
                          state.audio.say('안녕! 나랑 같이 놀자!');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 19,
                              color: Palette.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                icon: state.sfxOn
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
                label: '효과음',
                value: state.sfxOn,
                onChanged: (v) => state.setSfx(v),
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                icon: state.musicOn
                    ? Icons.queue_music_rounded
                    : Icons.music_off_rounded,
                label: '배경 음악',
                value: state.musicOn,
                onChanged: (v) => state.setMusic(v),
              ),
              const SizedBox(height: 12),
              const _EyeGuardCard(),
              if (!state.audio.voiceAvailable)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Text(
                    '이 기기에서는 한국어 음성을 찾지 못했어요. 기기 설정에서 한국어 TTS를 설치하면 들을 수 있어요.',
                    style: TextStyle(fontSize: 15, color: Palette.textSoft),
                  ),
                ),
              const SizedBox(height: 12),
              CreamCard(
                padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.badge_rounded,
                      size: 34,
                      color: Palette.pink,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.nickname,
                        style: const TextStyle(
                          fontSize: 26,
                          color: Palette.text,
                        ),
                      ),
                    ),
                    PillButton(
                      height: 64,
                      onTap: () =>
                          Navigator.of(context)
                              .push(softRoute(const NicknameScreen())),
                      semanticLabel: '닉네임 바꾸기',
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 30,
                        color: Palette.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '부모님께',
                style: TextStyle(fontSize: 22, color: Palette.textSoft),
              ),
              const SizedBox(height: 8),
              const CreamCard(
                padding: EdgeInsets.all(16),
                child: Text(
                  '· 회원가입, 서버, 광고, 추적, 현금 결제가 없습니다.\n'
                  '· 닉네임과 진행 기록은 이 기기 안에만 저장됩니다.\n'
                  '· 코인은 놀이로만 모으고, 꾸미기 아이템에만 씁니다.\n'
                  '· 한 판은 5문제(약 1~2분)입니다.\n'
                  '· 눈 지킴이를 켜면 앞카메라 영상을 이 기기 안에서만 살펴보고, 저장하거나 보내지 않습니다.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Palette.text,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _HoldToReset(),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: '알록달록 꼬마 놀이터',
                    applicationVersion: '0.1.0',
                  ),
                  child: const Text(
                    '오픈소스 라이선스',
                    style: TextStyle(fontSize: 16, color: Palette.textSoft),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    child: CreamCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 40, color: value ? Palette.pink : Palette.textSoft),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 26, color: Palette.text),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 86,
            height: 48,
            padding: const EdgeInsets.all(5),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? Palette.mint : Palette.creamDeep,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
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
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Palette.creamDeep, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: _progress,
            child: Container(color: const Color(0xFFFFD1D1)),
          ),
          const Center(
            child: Text(
              '기록 모두 지우기 (3초 꾹 누르기)',
              style: TextStyle(fontSize: 17, color: Palette.textSoft),
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
          status = '지금 거리 약 ${d.round()}cm · $angle';
        }
        return CreamCard(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    on
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 34,
                    color: Palette.pink,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '눈 지킴이',
                      style: TextStyle(fontSize: 26, color: Palette.text),
                    ),
                  ),
                  // 다른 설정과 같은 모양의 켜기/끄기
                  GestureDetector(
                    onTap: eye.supported ? () => state.setEyeGuard(!on) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 86,
                      height: 48,
                      padding: const EdgeInsets.all(5),
                      alignment: on
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: on ? Palette.mint : Palette.creamDeep,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 16, color: Palette.textSoft),
              ),
              if (on && eye.supported) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PillButton(
                      height: 48,
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
                      semanticLabel: '30cm 기준 맞추기',
                      child: const Text(
                        '30cm 기준 맞추기',
                        style: TextStyle(fontSize: 18, color: Palette.text),
                      ),
                    ),
                    if (eye.calibration != null)
                      PillButton(
                        height: 48,
                        onTap: () => state.resetEyeCalibration(),
                        semanticLabel: '기준 지우기',
                        child: const Text(
                          '기준 지우기',
                          style: TextStyle(
                            fontSize: 18,
                            color: Palette.textSoft,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '정확하게 하려면: 아이 눈에서 30cm(자 하나) 떨어진 곳에 화면을 두고, 아이가 화면을 볼 때 "30cm 기준 맞추기"를 눌러 주세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Palette.textSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
