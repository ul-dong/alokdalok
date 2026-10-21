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
      backgroundColor: Palette.skyBottom,
      body: SafeArea(
        child: PhoneWidth(
          maxWidth: 720,
          // 항목이 많지 않아 한 번에 그린다 (스크롤로 내려도 다시 만들지 않음)
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const _Section('눈 보호'),
                const _EyeGuardCard(),
                const _Section('놀이 시간'),
                const _PlayLimitCard(),
                const _Section('눈 쉬기 간격'),
                const _EyeBreakCard(),
                const _Section('소리'),
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
                if (!state.audio.voiceAvailable)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Text(
                      '이 기기에서는 한국어 음성을 찾지 못했어요. 기기 설정에서 한국어 TTS를 설치하면 들을 수 있어요.',
                      style: TextStyle(fontSize: 15, color: Palette.textSoft),
                    ),
                  ),
                const _Section('부모 확인'),
                _ToggleRow(
                  icon: state.parentGateOn
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  label: '설정 전에 덧셈 문제',
                  value: state.parentGateOn,
                  onChanged: (v) => state.setParentGate(v),
                ),
                const _Section('백업'),
                const _BackupCard(),
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
              if (on) ...[
                const SizedBox(height: 10),
                const Text(
                  '이보다 가까우면 쉬어 가요',
                  style: TextStyle(fontSize: 17, color: Palette.text),
                ),
                const SizedBox(height: 6),
                _Choices(
                  values: SafetyRules.eyeDistanceChoices,
                  selected: state.eyeDistanceCm,
                  label: (cm) => '${cm}cm',
                  onPick: (cm) => state.setEyeDistance(cm),
                ),
              ],
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

/// 설정 묶음 제목
class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 22, color: Palette.textSoft),
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
    spacing: 8,
    runSpacing: 10,
    children: [
      for (final v in values)
        PillButton(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: v == selected ? Palette.yellow : Colors.white,
          edge: v == selected ? Palette.coinDeep : Palette.creamDeep,
          semanticLabel: label(v),
          onTap: () => onPick(v),
          child: Text(
            label(v),
            style: const TextStyle(fontSize: 19, color: Palette.text),
          ),
        ),
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
    return CreamCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_rounded, size: 34, color: Palette.pink),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '하루 놀이 시간',
                  style: TextStyle(fontSize: 26, color: Palette.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Choices(
            values: SafetyRules.limitChoices,
            selected: state.playLimitMin,
            label: (m) => m == 0 ? '제한 없음' : '$m분',
            onPick: (m) => state.setPlayLimit(m),
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 논 시간 ${_minutes(play.used)}'
            '${left == null ? '' : ' · 남은 시간 ${_minutes(left)}'}'
            '${play.bonusMinutes > 0 ? ' (더 준 시간 ${play.bonusMinutes}분)' : ''}',
            style: const TextStyle(fontSize: 16, color: Palette.textSoft),
          ),
          const Text(
            '다 되면 "오늘은 여기까지!"가 화면을 덮어요. 부모 확인 후 15분 더 놀 수 있고, 다음 날 다시 풀려요.',
            style: TextStyle(
              fontSize: 14,
              color: Palette.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 눈 쉬기 간격: 10분 / 20분
class _EyeBreakCard extends StatelessWidget {
  const _EyeBreakCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return CreamCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.landscape_rounded,
                size: 34,
                color: Palette.pink,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: FitBox(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '눈 쉬기',
                    style: TextStyle(fontSize: 26, color: Palette.text),
                  ),
                ),
              ),
              _Choices(
                values: SafetyRules.breakChoices,
                selected: state.eyeBreakMin,
                label: (m) => '$m분마다',
                onPick: (m) => state.setEyeBreak(m),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '이어서 놀면 20초 동안 "창밖 먼 곳을 봐요"를 보여 줘요. 앱을 5분 넘게 안 보면 쉰 것으로 쳐요.',
            style: TextStyle(
              fontSize: 14,
              color: Palette.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 백업: 'ALOK1-' 글자 만들기(복사) / 붙여 넣어 복구
class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    return CreamCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "기록을 'ALOK1-'로 시작하는 글자로 만들어 복사해 두었다가, 다른 기기에 붙여 넣으면 그대로 옮겨져요. 서버로 보내지 않아요.",
            style: TextStyle(
              fontSize: 15,
              color: Palette.textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PillButton(
                height: 56,
                semanticLabel: '백업 글자 만들기',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _BackupExportDialog(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 26, color: Palette.text),
                    SizedBox(width: 8),
                    Text(
                      '백업 글자 만들기',
                      style: TextStyle(fontSize: 19, color: Palette.text),
                    ),
                  ],
                ),
              ),
              PillButton(
                height: 56,
                semanticLabel: '백업 글자로 복구',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const BackupRestoreDialog(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restore_rounded, size: 26, color: Palette.text),
                    SizedBox(width: 8),
                    Text(
                      '백업 글자로 복구',
                      style: TextStyle(fontSize: 19, color: Palette.text),
                    ),
                  ],
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
              style: const TextStyle(fontSize: 26, color: Palette.text),
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.creamDeep, width: 2),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _code,
            style: const TextStyle(fontSize: 13, color: Palette.text),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _copied
            ? '복사했어요. 메모나 메시지에 붙여 넣어 보관해 주세요.'
            : '아래 버튼으로 복사해서 안전한 곳에 보관해 주세요.',
        style: const TextStyle(fontSize: 15, color: Palette.textSoft),
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
              style: TextStyle(fontSize: 19, color: Palette.textSoft),
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
              style: TextStyle(fontSize: 19, color: Palette.text),
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
        style: const TextStyle(fontSize: 14, color: Palette.text),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          hintText: 'ALOK1-…',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _error ?? '복구하면 지금 기기의 기록이 백업 기록으로 바뀌어요.',
        style: TextStyle(
          fontSize: 15,
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
              style: TextStyle(fontSize: 19, color: Palette.textSoft),
            ),
          ),
          PillButton(
            height: 56,
            semanticLabel: '붙여 넣기',
            onTap: _paste,
            child: const Text(
              '붙여 넣기',
              style: TextStyle(fontSize: 19, color: Palette.text),
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
              style: TextStyle(fontSize: 19, color: Palette.text),
            ),
          ),
        ],
      ),
    ],
  );
}
