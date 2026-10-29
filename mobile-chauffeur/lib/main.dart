import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tmk_cache/tmk_cache.dart';
import 'package:tmk_pin/tmk_pin.dart';
import 'package:tmk_push/tmk_push.dart';

import 'core/network/prechargement.dart';
import 'core/providers/core_providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/pin_lock_page.dart';
import 'features/auth/presentation/pages/pin_resume_page.dart';
import 'features/auth/presentation/pages/pin_setup_page.dart';
import 'features/auth/presentation/providers/auth_controller.dart';
import 'features/auth/presentation/providers/auth_state.dart';
import 'features/auth/presentation/widgets/biometric_proposal.dart';
import 'features/compte/presentation/pages/home_page.dart';
import 'features/notification/presentation/push_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  // Avant le premier écran : une notification ayant lancé l'application n'est
  // rendue qu'une seule fois, au tout premier démarrage qui suit. Elle sera
  // retenue jusqu'au déverrouillage.
  await PushService.instance.initialiser();
  runApp(const ProviderScope(child: ChauffeurApp()));
}

/// Clé du navigateur racine : à la déconnexion, ou quand la page quittée n'est
/// plus conservée sous l'écran de code, elle permet de vider la pile de
/// navigation pour révéler la page d'accès.
final _navigatorKey = GlobalKey<NavigatorState>();

class ChauffeurApp extends ConsumerWidget {
  const ChauffeurApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Autour de MaterialApp, jamais dedans : le routeur pousse sur le
    // navigateur racine, qui doit déjà exister quand un lien arrive.
    return PushRouter(
      navigatorKey: _navigatorKey,
      // Verrouillée puis rouverte dans les dix minutes, l'application revient
      // sur la page quittée ; au-delà, ou à la déconnexion, la pile de
      // navigation est vidée pour révéler la page d'accès.
      child: ConservationSousVerrou(
        etat: _etatSession(ref.watch(authControllerProvider)),
        navigatorKey: _navigatorKey,
        builder: (context, conservation) => MaterialApp(
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
          // Hors connexion, les écrans montrent leurs dernières données : le
          // bandeau dit de quand elles datent.
          builder: (context, child) => BandeauHorsLigne(
            fond: AppColors.warningTint,
            texte: AppColors.warning,
            child: CouvertureVerrou(
              conservation: conservation,
              ecranVerrou: const PinLockPage(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: _AuthGate(conservation: conservation),
        ),
      ),
    );
  }

  static EtatSession _etatSession(AuthState state) => switch (state) {
    AuthAuthenticated() => EtatSession.ouverte,
    AuthLocked() => EtatSession.verrouillee,
    AuthUnauthenticated() => EtatSession.fermee,
    _ => EtatSession.transitoire,
  };
}

/// Aiguille entre écran de connexion, verrouillage par code et tableau de bord
/// selon l'état d'auth. L'expiration de session est traitée par
/// [AuthController], qui remet sous clé plutôt que de déconnecter.
class _AuthGate extends ConsumerStatefulWidget {
  final Conservation conservation;

  const _AuthGate({required this.conservation});

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
    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthUnknown() => const _Splash(),
      AuthUnauthenticated() => const LoginPage(),
      // L'invite du déverrouillage biométrique s'accroche à l'accueil :
      // l'écran de code, lui, disparaît dès que le code est accepté.
      // Les écrans clés sont lus d'avance, pour être servis hors connexion
      // même sans avoir été ouverts.
      AuthAuthenticated() => _accueil(),
      // Les écrans ouverts restent construits sous l'écran de code.
      AuthLocked() when widget.conservation.couverte => _accueil(),
      AuthLocked() => const PinLockPage(),
      AuthPinSetup(:final displayName) => PinSetupPage(
        displayName: displayName,
      ),
      AuthPinResume(:final displayName) => PinResumePage(
        displayName: displayName,
      ),
    };
  }

  Widget _accueil() => PrechargementPeriodique(
    key: widget.conservation.cleAccueil,
    // Sous l'écran de code, plus de jeton : un retour au premier plan n'a
    // rien à précharger.
    precharger: () async {
      if (ref.read(authControllerProvider) is! AuthAuthenticated) return;
      await prechargerEcransCles(ref.read(apiClientProvider));
    },
    child: const BiometricProposal(child: HomePage()),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
