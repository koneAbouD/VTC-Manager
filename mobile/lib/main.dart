import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tmk_push/tmk_push.dart';

import 'core/network/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/pin_lock_page.dart';
import 'features/auth/presentation/pages/pin_resume_page.dart';
import 'features/auth/presentation/pages/pin_setup_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/providers/auth_state.dart';
import 'features/auth/presentation/widgets/biometric_proposal.dart';
import 'features/notification/presentation/push_router.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  // Avant le premier écran : une notification ayant lancé l'application n'est
  // rendue qu'une seule fois, au tout premier démarrage qui suit. Elle sera
  // retenue jusqu'au déverrouillage.
  await PushService.instance.initialiser();
  runApp(const ProviderScope(child: VtcManagerApp()));
}

/// Clé globale pour afficher des messages (ex. expiration de session) sans
/// dépendre d'un contexte de page particulier.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Clé du navigateur racine : permet, lors d'une déconnexion (volontaire ou
/// subie), de vider la pile de navigation pour revenir instantanément à la
/// page de connexion, quelle que soit la profondeur où se trouve l'utilisateur.
final _navigatorKey = GlobalKey<NavigatorState>();

class VtcManagerApp extends ConsumerWidget {
  const VtcManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    // Déconnexion (volontaire ou subie) ou verrouillage par code : revenir à la
    // racine en vidant la pile de navigation. On n'affiche PAS d'alerte
    // d'expiration de session : la redirection vers la page d'accès suffit.
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is AuthUnauthenticated || next is AuthLocked) {
        // Après le frame courant (le home est déjà devenu LoginPage) : on retire
        // tous les écrans empilés pour révéler la page de connexion aussitôt.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
    });

    // Capte les interactions utilisateur (sans les intercepter) pour réarmer
    // le compteur d'inactivité du SessionManager.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionManager.instance.recordActivity(),
      // Autour de MaterialApp, jamais dedans : le routeur pousse sur le
      // navigateur racine, qui doit déjà exister quand un lien arrive.
      child: PushRouter(
        navigatorKey: _navigatorKey,
        child: MaterialApp(
        title: 'VTC Manager',
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      theme: AppTheme.light,
        home: switch (authState) {
          AuthInitial() => const _SplashScreen(),
          // L'invite du déverrouillage biométrique s'accroche à l'accueil :
          // l'écran de code, lui, disparaît dès que le code est accepté.
          AuthAuthenticated() =>
            const BiometricProposal(child: HomeScreen()),
          AuthLocked() => const PinLockPage(),
          AuthPinSetup(:final displayName) =>
            PinSetupPage(displayName: displayName),
          AuthPinResume(:final displayName) =>
            PinResumePage(displayName: displayName),
          _ => const LoginPage(),
        },
        ),
      ),
    );
  }
}

/// Affiché pendant le bootstrap (vérification de session)
class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lancer le bootstrap une seule fois
    ref.listen(authNotifierProvider, (_, __) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).bootstrap();
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_tmk.png',
              height: 120,
              fit: BoxFit.contain,
              // Repli si le logo n'est pas (encore) disponible.
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_taxi_rounded,
                size: 80,
                color: Color(0xFF43A047),
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
