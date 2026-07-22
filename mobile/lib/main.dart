import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/network/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/providers/auth_state.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
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

    // Déconnexion (volontaire ou subie) : revenir à la racine en vidant la pile
    // de navigation. On n'affiche PAS d'alerte d'expiration de session : la
    // redirection vers la page de connexion suffit.
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is AuthUnauthenticated) {
        // Après le frame courant (le home est déjà devenu LoginPage) : on retire
        // tous les écrans empilés pour révéler la page de connexion aussitôt.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
    });

    final isAuthenticated = authState is AuthAuthenticated;

    // Capte les interactions utilisateur (sans les intercepter) pour réarmer
    // le compteur d'inactivité du SessionManager.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionManager.instance.recordActivity(),
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
        home: authState is AuthInitial
            ? const _SplashScreen()
            : (isAuthenticated ? const HomeScreen() : const LoginPage()),
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
