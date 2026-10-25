import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tmk_push/tmk_push.dart';

import 'core/network/session_manager.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
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
  // L'apparence choisie est lue avant le premier frame : l'application s'ouvre
  // directement dans la bonne couleur, sans flash de l'apparence par défaut.
  final apparence = await ThemeSettings.charger(const SecureStorage());
  runApp(ProviderScope(
    overrides: [themeSettingsInitialProvider.overrideWithValue(apparence)],
    child: const VtcManagerApp(),
  ));
}

/// Clé globale pour afficher des messages (ex. expiration de session) sans
/// dépendre d'un contexte de page particulier.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Clé du navigateur racine : permet, lors d'une déconnexion (volontaire ou
/// subie), de vider la pile de navigation pour revenir instantanément à la
/// page de connexion, quelle que soit la profondeur où se trouve l'utilisateur.
final _navigatorKey = GlobalKey<NavigatorState>();

class VtcManagerApp extends ConsumerStatefulWidget {
  const VtcManagerApp({super.key});

  @override
  ConsumerState<VtcManagerApp> createState() => _VtcManagerAppState();
}

class _VtcManagerAppState extends ConsumerState<VtcManagerApp>
    with WidgetsBindingObserver {
  /// Faux tant que la première construction n'a pas eu lieu : la palette de
  /// départ n'appelle aucune reconstruction, elle est déjà celle qu'on voit.
  bool _construit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// En mode « Système », l'apparence suit celle de l'appareil, y compris
  /// quand elle bascule application ouverte (coucher du soleil, réglage rapide).
  @override
  void didChangePlatformBrightness() {
    if (ref.read(themeControllerProvider).mode == ThemeMode.system) {
      setState(() {});
    }
  }

  Brightness _luminosite(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final apparence = ref.watch(themeControllerProvider);

    // La palette est installée ici, avant que le moindre descendant ne se
    // construise : les widgets lisent AppColors au fil de leur `build`. Ceux
    // déjà affichés, eux, ne se reconstruiraient pas d'eux-mêmes (rien ne les
    // prévient que les couleurs ont changé) : on rejoue donc toute la
    // construction une fois le frame passé.
    final changee =
        AppColors.appliquer(apparence.accent, _luminosite(apparence.mode));
    if (changee && _construit) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => WidgetsBinding.instance.reassembleApplication());
    }
    _construit = true;

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
      theme: AppTheme.clair(apparence.accent),
      darkTheme: AppTheme.sombre(apparence.accent),
      themeMode: apparence.mode,
      // Les couleurs viennent d'AppColors, pas du thème : l'animation de
      // transition mêlerait l'ancien et le nouveau jeu pendant 200 ms.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        final sombre = AppColors.estSombre;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (sombre
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_taxi_rounded,
                size: 80,
                color: AppColors.primary,
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
