import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../character/character_view.dart';
import '../character/nickname.dart';
import '../core/palette.dart';
import '../games/common/scene_game.dart';
import '../services/audio_service.dart';
import '../widgets/common.dart';

/// 닉네임 정하기. 첫 실행(onboarding)에서는 건너뛰기가 있고, 이후에는 변경 화면으로 쓴다.
class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  late final TextEditingController _ctrl;
  String? _error;
  final int _cheer = 0;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    final keep = !widget.onboarding && state.nickname != Nickname.fallback;
    _ctrl = TextEditingController(text: keep ? state.nickname : '');
    if (widget.onboarding) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) state.audio.say('내 이름을 지어 줄래?');
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _finish() {
    // 첫 실행이면 동물 고르기 화면까지 닫고 메인 화면으로
    if (widget.onboarding) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    var value = _ctrl.text.trim();
    // 비워 두면 귀여운 이름을 아무거나 하나 지어 준다
    if (value.isEmpty) {
      value = Nickname.random();
      _ctrl.text = value;
    }
    final error = Nickname.validate(value);
    setState(() => _error = error);
    if (error != null) return;
    await state.setNickname(value);
    state.audio.play(Sfx.correct);
    state.audio.say('$value, 반가워!');
    if (mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return LandscapePage(
      background: const SceneBackground(groundLevel: .8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      label: '뒤로',
                      size: 60,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.bottomCenter,
                      child: CharacterView(
                        equipped: state.equipped,
                        cheer: _cheer,
                        size: (c.maxHeight / 1.2).clamp(60.0, 230.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: CreamCard(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      '이름을 지어 주세요',
                      style: TextStyle(fontSize: 26, color: Palette.text),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              color: Palette.text,
                              fontFamily: 'Jua',
                            ),
                            maxLength: Nickname.maxLength,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                Nickname.maxLength,
                              ),
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                            onChanged: (_) => setState(() => _error = null),
                            onSubmitted: (_) => _save(),
                            decoration: InputDecoration(
                              hintText: '이름 쓰기',
                              errorText: _error,
                              errorStyle: const TextStyle(
                                fontSize: TextSizes.small,
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(Radii.lg),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PillButton(
                          height: 62,
                          color: Palette.pink,
                          edge: const Color(0xFFD9799A),
                          sound: null,
                          onTap: _save,
                          semanticLabel: '좋아요',
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '좋아요',
                                style: TextStyle(
                                  fontSize: TextSizes.title,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '비워 두고 좋아요를 누르면 이름을 아무거나 지어 줘요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: TextSizes.small,
                        color: Palette.textSoft,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ParentNotice(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentNotice extends StatelessWidget {
  const _ParentNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Palette.yellowSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: Palette.textSoft, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '부모님께: 실명이나 연락처 대신 별명을 써 주세요. 닉네임은 이 기기 안에만 저장되고 어디로도 보내지 않아요. (한글, 영문, 숫자 8글자까지)',
            style: TextStyle(
              fontSize: TextSizes.caption,
              color: Palette.textSoft,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
