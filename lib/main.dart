import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/app_state.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/user_registration_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/auth_screen.dart';
import 'widgets/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ));

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      final appState = AppState();

      runApp(CipherGuardApp(appState: appState));
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
    },
  );
}

class CipherGuardApp extends StatelessWidget {
  final AppState appState;
  const CipherGuardApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CipherGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: _AppRoot(appState: appState),
    );
  }
}

class _AppRoot extends StatefulWidget {
  final AppState appState;
  const _AppRoot({required this.appState});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait([
      widget.appState.initialize(),
      Future.delayed(const Duration(milliseconds: 2600)),
    ]);
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return const SplashScreen();
    return _buildRoot();
  }

  Widget _buildRoot() {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (_, __) {
        final as = widget.appState;

        if (!as.profileComplete) {
          return UserRegistrationScreen(appState: as);
        }

        if (!as.hasMasterPassword && !as.useBiometrics) {
          return OnboardingScreen(appState: as);
        }

        if (!as.authenticated) {
          return AuthScreen(appState: as);
        }

        return MainShell(appState: as);
      },
    );
  }
}
