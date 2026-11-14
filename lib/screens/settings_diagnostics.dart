part of 'settings_screen.dart';

// 렉·터치·눈 지킴이 진단 칸: 개발·실기기 점검용 숨은 칸이라 한국어로만 보여 준다
// (다국어 대상 아님, test/l10n_hangul_test.dart 허용 목록).

/// 렉·터치 진단: 최근 1분의 화면 그리기 시간(느린 장 수, 가장 느린 장), 최근 누름이 무엇에 맞았는지,
/// 살아 있는 소리 플레이어 수, (웹) 얼굴 인식 한 번에 걸린 시간. 렉을 느낀 직후 열면 숫자로 보인다.
/// 1초마다 새로 읽는다. (release 빌드에서도 보인다)
class PerfDiagnosticsPanel extends StatefulWidget {
  const PerfDiagnosticsPanel({super.key, this.monitor});

  /// 없으면 앱 전체 기록([PerfMonitor.instance])
  final PerfMonitor? monitor;

  @override
  State<PerfDiagnosticsPanel> createState() => _PerfDiagnosticsPanelState();
}

class _PerfDiagnosticsPanelState extends State<PerfDiagnosticsPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _ms(double v) =>
      v < 0 ? '-' : '${v.toStringAsFixed(v < 10 ? 1 : 0)}ms';

  static String _touch(TouchRecord t) {
    final ago = DateTime.now().difference(t.at).inSeconds;
    final held = (t.held.inMilliseconds / 1000).toStringAsFixed(1);
    final long = t.held >= LongPress.sayName ? ', 길게' : '';
    final cancel = t.cancelled ? ', 취소됨' : '';
    return '${t.target} ($held초$long, ${t.moved.round()}px 움직임$cancel, $ago초 전)';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final m = widget.monitor ?? PerfMonitor.instance;
    final f = m.frames();
    final a = state.audio.playerCounts;
    final touches = m.touches.reversed.toList();
    final d = state.eye.detectStats;
    final rows = <(String, String)>[
      ('화면 그리기', '${f.count}장, 평균 ${_ms(f.averageMs)}'),
      ('느린 장', '16ms 넘음 ${f.over16}장, 33ms 넘음 ${f.over33}장'),
      ('가장 느린 장', f.count == 0 ? '-' : _ms(f.worstMs)),
      (
        '소리 플레이어',
        a.webDecoded != null
            ? '효과음 ${a.sfx}, 풀어 둔 소리 ${a.webDecoded}개, 받은 파일 ${a.webFiles}개'
            : '효과음 ${a.sfx}, 음악 ${a.music}, 말 조각 ${a.clips} (합 ${a.total})',
      ),
      ('마지막 누름', touches.isEmpty ? '아직 없음' : _touch(touches[0])),
      if (touches.length > 1) ('그 전 누름', _touch(touches[1])),
      if (d != null && d.count > 0)
        (
          '얼굴 인식 시간',
          '${d.where}, 마지막 ${_ms(d.lastMs)}, 최대 ${_ms(d.maxMs)}, '
              '화면 막음 ${_ms(d.mainMs)}, 준비 ${_ms(d.initMs)}',
        ),
    ];
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '렉, 터치 진단 (최근 1분)',
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
            for (final (k, v) in rows) _DiagRow(label: k, value: v),
            const SizedBox(height: Gaps.sm),
            const _Note(
              '렉을 느낀 바로 뒤에 이 칸을 열어 주세요. 한 장에 16ms가 넘으면 부드럽지 않고, 33ms가 넘으면 끊겨 보입니다. 마지막 누름에서 길게(0.4초 넘게) 누르면 놀이에 들어가지 않고 이름만 말합니다. 소리 플레이어 수가 계속 늘면 알려 주세요.',
            ),
          ],
        ),
      ],
    );
  }
}

/// 진단 칸 한 줄: 왼쪽 이름, 오른쪽 값
class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: TextSizes.caption,
              color: Palette.textSoft,
            ),
          ),
        ),
        const SizedBox(width: Gaps.sm),
        Flexible(
          flex: 2,
          child: Text(
            value,
            key: ValueKey('diag:$label'),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: TextSizes.caption,
              color: Palette.text,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 눈 지킴이 실측 진단: 최근 1분의 실제 초당 프레임 수, 검사 횟수, 카메라가 켜져 있던 시간 비율,
/// 창 열기 시간과 방식(카메라 유지 / 창마다 끄기), 기기 열·절전·배터리.
/// 카메라에 요청한 초당 프레임(안드로이드 10, iOS 5)이 기기에서 실제로 먹히는지,
/// 두 방식 중 어느 쪽이 창을 짧게 여는지 실기기에서 확인한다 ('방식 바꾸기'를 누르면 기록을 새로 잰다).
/// 1초마다 새로 읽는다. (release 빌드에서도 보인다)
class EyeDiagnosticsPanel extends StatefulWidget {
  const EyeDiagnosticsPanel({super.key, this.stats});

  /// 없으면 앱 전체 기록([EyeStats.instance])
  final EyeStats? stats;

  @override
  State<EyeDiagnosticsPanel> createState() => _EyeDiagnosticsPanelState();
}

class _EyeDiagnosticsPanelState extends State<EyeDiagnosticsPanel> {
  Timer? _timer;

  String _ago(DateTime at) {
    final s = DateTime.now().difference(at).inSeconds;
    return s < 60 ? '$s초 전' : '${s ~/ 60}분 전';
  }

  /// 마지막 창: "얼굴 32cm (3초 전)" / "얼굴 없음" / "실패 2번: 이유"
  String _windowText(EyeWindowResult? r, int failures) {
    if (r == null) return '아직 없음';
    final what = switch (r.outcome) {
      EyeWindowOutcome.face => '얼굴 ${r.cm?.round() ?? '-'}cm',
      EyeWindowOutcome.noFace => '얼굴 없음',
      EyeWindowOutcome.failed =>
        '실패${failures > 1 ? ' $failures번' : ''}: ${r.message ?? ''}',
    };
    return '$what (${_ago(r.at)})';
  }

  static String _windowShort(EyeWindowResult r) => switch (r.outcome) {
    EyeWindowOutcome.face => '${r.cm?.round() ?? '-'}cm',
    EyeWindowOutcome.noFace => '없음',
    EyeWindowOutcome.failed => '실패',
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eye = AppScope.of(context).eye;
    final sum = (widget.stats ?? EyeStats.instance).summary();
    final fps = sum.fps;
    final sec = sum.window.inMilliseconds / 1000;
    final on = sum.cameraOn.inMilliseconds / 1000;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final asked = ios ? EyeRules.iosFps : EyeRules.androidFps;
    String ms(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)}초';
    String msOf(Duration? d) => d == null ? '-' : '${d.inMilliseconds}ms';
    final heat = eye.heat;
    final hs = heat.status;
    final zone = switch (eye.zone) {
      EyeZone.safe => '넉넉',
      EyeZone.caution => '기준 가까이',
      EyeZone.alert => '경고 중',
    };
    final rows = <(String, String)>[
      (
        '실제 초당 프레임',
        fps == null
            ? '카메라가 켜진 적 없음'
            : '${fps.toStringAsFixed(1)}장 (요청 $asked장)',
      ),
      ('검사 횟수', '${sum.checks}번'),
      (
        '카메라 켜짐',
        '${(sum.onRatio * 100).round()}% (${on.toStringAsFixed(0)}초 / ${sec.toStringAsFixed(0)}초)',
      ),
      ('받은 프레임', '${sum.frames}장'),
      (
        '창 열기 시간',
        '평균 ${msOf(sum.windowAverage)}, 마지막 ${msOf(sum.lastWindow)} (${sum.windows}번)',
      ),
      ('방식', eye.cameraMode),
      (
        '지금',
        eye.heatOff
            ? '꺼짐 (기기가 뜨거움)'
            : eye.running
            ? '켜짐, 창 주기 ${ms(eye.checkInterval)} ($zone)'
            : '꺼짐 (${eye.offReason})',
      ),
      ('마지막 창 결과', _windowText(eye.lastWindow, eye.failures)),
      (
        '최근 창',
        eye.recentWindows.isEmpty
            ? '-'
            : eye.recentWindows.map(_windowShort).join(' / '),
      ),
      (
        '다음 창까지',
        eye.windowOpen
            ? '지금 보는 중'
            : eye.nextWindowIn != null
            ? ms(eye.nextWindowIn!)
            : '없음 (${eye.offReason ?? '창을 기다리는 중'})',
      ),
      (
        '부모님 계속하기',
        eye.snoozeLeft == null
            ? '아님'
            : '경고 쉬는 중 (${(eye.snoozeLeft!.inSeconds / 60).ceil()}분 남음)',
      ),
      ('기기 열', heat.bound ? hs.thermal.label : '${hs.thermal.label} (채널 없음)'),
      (
        '절전, 배터리',
        '절전 ${hs.powerSave == null ? '모름' : (hs.powerSave! ? '켜짐' : '꺼짐')}, '
            '배터리 ${hs.battery == null ? '모름' : '${hs.battery}%'}'
            '${heat.backoff > 1 ? ' (창 주기 ${heat.backoff}배)' : ''}',
      ),
    ];
    return _Panel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '눈 지킴이 진단 (최근 1분)',
              style: TextStyle(fontSize: TextSizes.body, color: Palette.text),
            ),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        k,
                        style: const TextStyle(
                          fontSize: TextSizes.caption,
                          color: Palette.textSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: Gaps.sm),
                    Flexible(
                      flex: 2,
                      child: Text(
                        v,
                        key: ValueKey('diag:$k'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: TextSizes.caption,
                          color: Palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Gaps.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: _SmallButton(
                icon: Icons.swap_horiz_rounded,
                label: '방식 바꾸기',
                onTap: () => setState(() {
                  eye.keepCamera = !eye.keepCamera;
                  (widget.stats ?? EyeStats.instance).reset();
                }),
              ),
            ),
            const SizedBox(height: Gaps.sm),
            const _Note(
              '실제 초당 프레임이 30 가까이면 카메라가 요청을 따르지 않는 것입니다 (발열 원인). 방식을 바꾸면 기록을 새로 잽니다: 같은 놀이를 1분씩 해 보고 카메라 켜짐·창 열기 시간을 비교해 주세요. 숫자는 저장하거나 보내지 않습니다.',
            ),
          ],
        ),
      ],
    );
  }
}
