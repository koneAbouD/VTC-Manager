import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/pin_lock_page.dart';
import 'features/auth/presentation/pages/pin_resume_page.dart';
import 'features/auth/presentation/pages/pin_setup_page.dart';
import 'features/auth/presentation/providers/auth_controller.dart';
import 'features/auth/presentation/providers/auth_state.dart';
import 'features/compte/presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  runApp(const ProviderScope(child: ChauffeurApp()));
}

/// Clé du navigateur racine : au verrouillage comme à la déconnexion, elle
/// permet de vider la pile de navigation pour que l'écran de code apparaisse
/// aussitôt, quelle que soit la page ouverte par-dessus.
final _navigatorKey = GlobalKey<NavigatorState>();

class ChauffeurApp extends StatelessWidget {
  const ChauffeurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VTC Chauffeur',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

/// Aiguille entre écran de connexion, verrouillage par code et tableau de bord
/// selon l'état d'auth. L'expiration de session est traitée par
/// [AuthController], qui remet sous clé plutôt que de déconnecter.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Session close ou remise sous clé : on retire les écrans empilés pour
    // révéler la page d'accès, sans quoi ils resteraient visibles par-dessus.
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is AuthUnauthenticated || next is AuthLocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
    });

    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthUnknown() => const _Splash(),
      AuthUnauthenticated() => const LoginPage(),
      AuthAuthenticated() => const HomePage(),
      AuthLocked() => const PinLockPage(),
      AuthPinSetup(:final displayName) =>
        PinSetupPage(displayName: displayName),
      AuthPinResume(:final displayName) =>
        PinResumePage(displayName: displayName),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
