import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/constants.dart';
import '../../core/services/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/particle_system.dart';

class InfoPage extends StatefulWidget {
  final AppState appState;
  const InfoPage({super.key, required this.appState});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _heroFade;
  late Animation<double> _heroSlide;
  late Animation<double> _floatAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _heroFade = CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _heroSlide = Tween<double>(begin: 80, end: 0).animate(CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic)));
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _floatCtrl.dispose();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeroSection()),
          SliverToBoxAdapter(child: _buildAboutCard()),
          SliverToBoxAdapter(child: _buildSkillsSection()),
          SliverToBoxAdapter(child: _buildContactSection()),
          SliverToBoxAdapter(child: _buildProjectsSection()),
          SliverToBoxAdapter(child: _buildTechStack()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return SizedBox(
      height: 420,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.4,
                  colors: [
                    Color(0xFF1A0840),
                    Color(0xFF0A0518),
                    Color(0xFF050505)
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
              child: CustomPaint(painter: GridPainter(0.6))),
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (_, __) => Positioned(
              top: 40,
              left: -60,
              child: Transform.rotate(
                angle: _rotateAnim.value * 2 * pi,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kNeon.withValues(alpha: 0.06),
                        width: 1),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (_, __) => Positioned(
              top: 80,
              right: -80,
              child: Transform.rotate(
                angle: -_rotateAnim.value * 2 * pi * 0.7,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kPrimary.withValues(alpha: 0.08),
                        width: 1),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_heroFade, _heroSlide]),
              builder: (_, __) => FadeTransition(
                opacity: _heroFade,
                child: Transform.translate(
                  offset: Offset(0, _heroSlide.value),
                  child: SafeArea(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildAvatarSection(),
                          const SizedBox(height: 20),
                          _buildHeroText(),
                          const SizedBox(height: 16),
                          _buildHeroTags(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_floatAnim, _pulseAnim, _rotateAnim]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value * 0.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _rotateAnim.value * 2 * pi,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: kNeon
                          .withValues(alpha: 0.2 * _pulseAnim.value),
                      width: 1),
                ),
              ),
            ),
            Transform.rotate(
              angle: -_rotateAnim.value * 2 * pi * 0.6,
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: kPrimary
                          .withValues(alpha: 0.35 * _pulseAnim.value),
                      width: 1.5),
                ),
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A0860), Color(0xFF8A2BE2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color: kNeon
                        .withValues(alpha: 0.7 * _pulseAnim.value),
                    width: 2.5),
                boxShadow: [
                  BoxShadow(
                      color: kPrimary
                          .withValues(alpha: 0.6 * _pulseAnim.value),
                      blurRadius: 40,
                      spreadRadius: 6),
                  BoxShadow(
                      color: kNeon
                          .withValues(alpha: 0.25 * _pulseAnim.value),
                      blurRadius: 70,
                      spreadRadius: 12),
                ],
              ),
              child: const Icon(Icons.code_rounded,
                  color: kNeon, size: 48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [kNeon, kCyan, kNeon],
            stops: [0, 0.5, 1],
          ).createShader(b),
          child: const Text(
            'ILIA NOTHING',
            style: TextStyle(
                color: kText,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 6),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
                colors: AppColors.gradientPrimary
                    .map((c) => c.withValues(alpha: 0.25))
                    .toList()),
            border:
                Border.all(color: kNeon.withValues(alpha: 0.3)),
          ),
          child: const Text(
              'Full-Stack Developer & Security Researcher',
              style: TextStyle(
                  color: kNeon,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildHeroTags() {
    const tags = [
      'Flutter',
      'Dart',
      'Security',
      'Open Source',
      'CipherGuard'
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tags
          .map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: kGlass2,
                  border: Border.all(color: kGlassBorder2),
                ),
                child: Text(t,
                    style: const TextStyle(
                        color: kTextDim,
                        fontSize: 10,
                        letterSpacing: 0.5)),
              ))
          .toList(),
    );
  }

  Widget _buildAboutCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GlassCard(
        gradientColors: const [
          Color(0x14CC66FF),
          Color(0x08050505)
        ],
        borderColor: kGlassBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                        colors: AppColors.gradientNeon),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: kText, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('ABOUT',
                    style: TextStyle(
                        color: kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ilia Nothing is a passionate software developer and security researcher specializing in mobile application development, cryptography, and privacy-focused tools. Creator of CipherGuard — a zero-knowledge AES-256 encrypted vault for Android and iOS.',
              style:
                  TextStyle(color: kTextDim, fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 12),
            const Text(
              'Focused on building tools that respect user privacy and security, leveraging cutting-edge cryptographic standards to deliver enterprise-grade protection in consumer applications.',
              style:
                  TextStyle(color: kTextDim, fontSize: 13, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    final skills = [
      ('Flutter / Dart', 0.95, AppColors.gradientCyan),
      ('Cryptography & Security', 0.90, AppColors.gradientNeon),
      ('Mobile Development', 0.92, AppColors.gradientPrimary),
      ('Backend Development', 0.80, AppColors.gradientSecondary),
      ('UI/UX Design', 0.85, AppColors.gradientSuccess),
      ('Open Source', 0.88, AppColors.gradientGold),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('SKILLS', Icons.psychology_rounded),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: skills
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _skillBar(s.$1, s.$2, s.$3),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillBar(
      String label, double value, List<Color> grad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: kTextDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%',
                style: TextStyle(
                    color: grad.first,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 6, color: kSurface3),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                    boxShadow: [
                      BoxShadow(
                          color: grad.first.withValues(alpha: 0.5),
                          blurRadius: 6)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('CONTACT', Icons.contact_page_rounded),
          const SizedBox(height: 12),
          _contactCard(
              Icons.code_rounded,
              'GitHub',
              'V0IDNETWORK',
              'https://github.com/V0IDNETWORK',
              AppColors.gradientDark),
          const SizedBox(height: 10),
          _contactCard(
              Icons.language_rounded,
              'Website',
              'voidnetwork.ir',
              'https://voidnetwork.ir',
              AppColors.gradientCyan),
          const SizedBox(height: 10),
          _contactCard(
              Icons.send_rounded,
              'Telegram',
              '@ilianothing',
              'https://t.me/ilianothing',
              AppColors.gradientPrimary),
          const SizedBox(height: 10),
          _contactCard(
              Icons.email_rounded,
              'Email',
              'contact@voidnetwork',
              'mailto:ilianothingg@gmail.com',
              AppColors.gradientSuccess),
        ],
      ),
    );
  }

  Widget _contactCard(IconData icon, String platform, String handle,
      String url, List<Color> grad) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _openLink(url),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                  colors: grad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: grad.first.withValues(alpha: 0.4),
                    blurRadius: 16)
              ],
            ),
            child: Icon(icon, color: kText, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(platform,
                    style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700)),
                Text(handle,
                    style: const TextStyle(
                        color: kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded,
              color: kNeon.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    final isWebLink =
        uri.scheme == 'http' || uri.scheme == 'https';
    try {
      final launched = await launchUrl(
        uri,
        mode: isWebLink
            ? LaunchMode.externalApplication
            : LaunchMode.externalNonBrowserApplication,
      );
      if (!launched && mounted) _showLinkError(url);
    } catch (_) {
      if (mounted) _showLinkError(url);
    }
  }

  void _showLinkError(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open $url'),
        backgroundColor: kError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('PROJECTS', Icons.rocket_launch_rounded),
          const SizedBox(height: 12),
          GlassCard(
            gradientColors: [
              const Color(0x108A2BE2),
              kSurface2.withValues(alpha: 0.4)
            ],
            borderColor: kPrimary.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                            colors: AppColors.gradientNeon),
                        boxShadow: [
                          BoxShadow(
                              color: kNeon.withValues(alpha: 0.4),
                              blurRadius: 16)
                        ],
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: kText, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CipherGuard',
                              style: TextStyle(
                                  color: kText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          Text('AES-256-GCM Password Manager',
                              style: TextStyle(
                                  color: kNeon, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: kSuccess.withValues(alpha: 0.12),
                        border: Border.all(
                            color:
                                kSuccess.withValues(alpha: 0.3)),
                      ),
                      child: const Text('ACTIVE',
                          style: TextStyle(
                              color: kSuccess,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'A premium zero-knowledge encrypted password manager featuring AES-256-GCM vault, biometric authentication, and a comprehensive security center.',
                  style: TextStyle(
                      color: kTextDim, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Flutter',
                    'Dart',
                    'AES-256',
                    'Biometrics',
                    'Zero-Knowledge'
                  ]
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(6),
                              color: kNeon.withValues(alpha: 0.08),
                              border: Border.all(
                                  color: kNeon
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Text(t,
                                style: const TextStyle(
                                    color: kNeon, fontSize: 10)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechStack() {
    final techs = [
      (Icons.phone_android_rounded, 'Flutter', kCyan),
      (Icons.lock_rounded, 'AES-256', kNeon),
      (Icons.fingerprint, 'Biometrics', kPrimary),
      (Icons.storage_rounded, 'Secure Storage', kSecondary),
      (Icons.code_rounded, 'Dart', kAccent),
      (Icons.security_rounded, 'PBKDF2', kSuccess),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'TECH STACK', Icons.developer_mode_rounded),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: techs
                .map((t) => GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(t.$1, color: t.$3, size: 22),
                          const SizedBox(height: 6),
                          Text(t.$2,
                              style: TextStyle(
                                  color: t.$3,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient:
                const LinearGradient(colors: AppColors.gradientNeon),
          ),
          child: Icon(icon, color: kText, size: 14),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: kTextMuted,
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: kGlassBorder2)),
      ],
    );
  }
}
