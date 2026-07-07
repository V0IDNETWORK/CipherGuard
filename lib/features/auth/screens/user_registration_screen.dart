import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/particle_system.dart';

class UserRegistrationScreen extends StatefulWidget {
  final AppState appState;

  const UserRegistrationScreen({super.key, required this.appState});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  String _selectedCountry = '';
  String _selectedLanguage = 'en';

  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _stepCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _floatAnim;
  late Animation<double> _stepFade;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _slideUp = Tween<double>(begin: 60, end: 0).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _stepFade = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _stepCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _stepCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) return;
    if (_step == 1 && _selectedCountry.isEmpty) return;
    if (_step < 2) {
      _stepCtrl.reverse().then((_) {
        setState(() => _step++);
        _stepCtrl.forward();
      });
    } else {
      _complete();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      _stepCtrl.reverse().then((_) {
        setState(() => _step--);
        _stepCtrl.forward();
      });
    }
  }

  Future<void> _complete() async {
    await widget.appState.saveUserProfile(
      _nameCtrl.text.trim(),
      _selectedCountry,
      _selectedLanguage,
    );
  }

  bool get _canNext {
    if (_step == 0) return _nameCtrl.text.trim().isNotEmpty;
    if (_step == 1) return _selectedCountry.isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [Color(0xFF1A0030), Color(0xFF050505)],
                ),
              ),
            ),
          ),
          ParticleSystem(child: const SizedBox.expand(), count: 14),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeIn, _slideUp]),
              builder: (_, __) => FadeTransition(
                opacity: _fadeIn,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: _buildLogo(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildStepIndicator(),
                      const SizedBox(height: 28),
                      Expanded(
                        child: FadeTransition(
                          opacity: _stepFade,
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                      _buildActions(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: kPrimary.withValues(alpha: 0.6),
                  blurRadius: 32,
                  spreadRadius: 4),
              BoxShadow(
                  color: kNeon.withValues(alpha: 0.2),
                  blurRadius: 64,
                  spreadRadius: 8),
            ],
          ),
          child: const Icon(Icons.shield_rounded, color: kText, size: 38),
        ),
        const SizedBox(height: 12),
        const NeonText('CIPHERGUARD',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            gradient: true),
        const SizedBox(height: 4),
        const Text('WELCOME — LET\'S GET YOU SET UP',
            style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 3)),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final labels = ['Profile', 'Country', 'Language'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: i == 0
                        ? Colors.transparent
                        : (done || active
                            ? kNeon.withValues(alpha: 0.5)
                            : kGlassBorder2),
                  ),
                ),
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: active || done
                            ? const LinearGradient(
                                colors: AppColors.gradientNeon)
                            : null,
                        color: active || done ? null : kSurface3,
                        border: Border.all(
                          color: active
                              ? kNeon
                              : done
                                  ? kNeon.withValues(alpha: 0.5)
                                  : kGlassBorder2,
                          width: active ? 2 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: kNeon.withValues(alpha: 0.5),
                                    blurRadius: 12)
                              ]
                            : [],
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                                color: kText, size: 16)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: active ? kText : kTextMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i],
                        style: TextStyle(
                            color: active ? kNeon : kTextMuted,
                            fontSize: 9,
                            letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildNameStep();
      case 1:
        return _buildCountryStep();
      case 2:
        return _buildLanguageStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NeonText('YOUR NAME',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            gradient: true),
        const SizedBox(height: 6),
        const Text('How should we address you?',
            style: TextStyle(color: kTextDim, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 32),
        GlassCard(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _nameCtrl,
            style:
                const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w500),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _nextStep(),
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: kNeon, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: kCyan, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your name is stored securely on-device and used to personalize your experience.',
                  style: TextStyle(color: kTextDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NeonText('YOUR COUNTRY',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            gradient: true),
        const SizedBox(height: 6),
        const Text('Select your country of residence',
            style: TextStyle(color: kTextDim, fontSize: 13)),
        const SizedBox(height: 24),
        ...kCountries.map((c) {
          final selected = _selectedCountry == c;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCountry = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: selected
                      ? LinearGradient(
                          colors: AppColors.gradientPrimary
                              .map((c) => c.withValues(alpha: 0.2))
                              .toList())
                      : const LinearGradient(
                          colors: [Color(0x0AFFFFFF), Color(0x06FFFFFF)]),
                  border: Border.all(
                      color: selected ? kNeon : kGlassBorder2,
                      width: selected ? 1.5 : 1),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: kNeon.withValues(alpha: 0.2),
                              blurRadius: 12)
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: kNeon, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(c,
                            style: TextStyle(
                                color: selected ? kText : kTextDim,
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400))),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: kNeon, size: 18),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NeonText('YOUR LANGUAGE',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            gradient: true),
        const SizedBox(height: 6),
        const Text('Choose your preferred language',
            style: TextStyle(color: kTextDim, fontSize: 13)),
        const SizedBox(height: 24),
        ...kSupportedLanguages.map((lang) {
          final selected = _selectedLanguage == lang['code'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedLanguage = lang['code']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: selected
                      ? LinearGradient(
                          colors: AppColors.gradientPrimary
                              .map((c) => c.withValues(alpha: 0.25))
                              .toList(),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : const LinearGradient(
                          colors: [Color(0x0CFFFFFF), Color(0x06FFFFFF)]),
                  border: Border.all(
                      color: selected ? kNeon : kGlassBorder2,
                      width: selected ? 2 : 1),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: kNeon.withValues(alpha: 0.3),
                              blurRadius: 20)
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Text(lang['flag']!,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lang['native']!,
                              style: TextStyle(
                                  color: selected ? kText : kTextDim,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text(lang['name']!,
                              style: const TextStyle(
                                  color: kTextMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            selected ? kNeon : Colors.transparent,
                        border: Border.all(
                            color: selected ? kNeon : kGlassBorder,
                            width: 2),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: kNeon.withValues(alpha: 0.4),
                                    blurRadius: 10)
                              ]
                            : [],
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: kBg, size: 14)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CyberButton(
                  label: 'BACK',
                  onPressed: _prevStep,
                  outlined: true,
                  height: 52,
                ),
              ),
            ),
          Expanded(
            flex: _step > 0 ? 2 : 1,
            child: CyberButton(
              label: _step == 2 ? 'GET STARTED' : 'NEXT',
              icon: _step == 2
                  ? Icons.rocket_launch_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _canNext ? _nextStep : null,
              gradient: AppColors.gradientNeon,
              height: 52,
            ),
          ),
        ],
      ),
    );
  }
}
