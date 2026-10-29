import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Où en est la session, du point de vue de l'écran.
enum EtatSession {
  /// Session ouverte : l'application s'affiche.
  ouverte,

  /// Session sous clé : l'écran de code est demandé.
  verrouillee,

  /// Session close : retour à la page de connexion.
  fermee,

  /// Démarrage, connexion en cours, choix du code… : rien à conserver.
  transitoire,
}

/// Ce que l'application doit savoir pour construire ses écrans.
class Conservation {
  /// Vrai quand la session est verrouillée mais que les écrans ouverts sont
  /// gardés sous l'écran de code : l'accueil reste construit, et
  /// [CouvertureVerrou] pose l'écran de code par-dessus.
  final bool couverte;

  /// Clé de l'accueil : elle change quand les écrans conservés sont abandonnés,
  /// pour que l'accueil reparte de zéro (premier onglet, aucun filtre).
  final Key cleAccueil;

  /// Navigateur propre à l'écran de code (ses boîtes de dialogue).
  final GlobalKey<NavigatorState> cleNavigateurVerrou;

  const Conservation({
    required this.couverte,
    required this.cleAccueil,
    required this.cleNavigateurVerrou,
  });
}

/// Rend l'utilisateur à la page qu'il avait quittée quand il déverrouille dans
/// les [delai] qui suivent le verrouillage.
///
/// Le verrouillage ne vide plus la pile de navigation : les écrans ouverts
/// restent construits sous l'écran de code (invisibles, inertes, sans focus),
/// avec leurs filtres, leur défilement et leur saisie en cours. Au-delà de
/// [delai], ils sont abandonnés et le déverrouillage ramène à l'accueil — le
/// téléphone a pu changer de mains, et la page n'a plus de raison d'être.
///
/// Se place **au-dessus** du `MaterialApp` : le retour arrière doit être
/// intercepté avant celui de l'application, qui dépilerait sinon la page
/// cachée. Le `MaterialApp` reçoit [Conservation] pour choisir son accueil et
/// pour poser [CouvertureVerrou] dans son `builder`.
class ConservationSousVerrou extends StatefulWidget {
  /// Délai de conservation par défaut.
  static const delaiConservation = Duration(minutes: 10);

  final EtatSession etat;

  /// Navigateur racine de l'application, vidé quand la page est abandonnée.
  final GlobalKey<NavigatorState> navigatorKey;

  final Duration delai;

  /// Horloge murale : un minuteur ne compte pas le temps où l'application est
  /// suspendue en arrière-plan. Remplaçable en test.
  final DateTime Function() horloge;

  final Widget Function(BuildContext context, Conservation conservation)
      builder;

  const ConservationSousVerrou({
    super.key,
    required this.etat,
    required this.navigatorKey,
    required this.builder,
    this.delai = delaiConservation,
    this.horloge = DateTime.now,
  });

  @override
  State<ConservationSousVerrou> createState() => _ConservationSousVerrouState();
}

class _ConservationSousVerrouState extends State<ConservationSousVerrou>
    with WidgetsBindingObserver {
  final _navigateurVerrou = GlobalKey<NavigatorState>();
  int _generation = 0;
  bool _couverte = false;

  /// Les écrans conservés ont déjà été abandonnés (délai écoulé, verrou
  /// toujours en place).
  bool _perimee = false;
  DateTime? _verrouilleeLe;
  Timer? _peremption;

  @override
  void initState() {
    super.initState();
    // Enregistré avant le MaterialApp, construit ensuite : notre retour arrière
    // passe en premier.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _peremption?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConservationSousVerrou old) {
    super.didUpdateWidget(old);
    if (old.etat == widget.etat) return;
    switch (widget.etat) {
      case EtatSession.verrouillee:
        if (old.etat == EtatSession.ouverte) {
          _couvrir();
        } else if (!_couverte) {
          _viderPile();
        }
      case EtatSession.ouverte:
        if (_couverte) _decouvrir();
      case EtatSession.fermee:
      case EtatSession.transitoire:
        // Déconnexion depuis l'écran de code, code épuisé : les écrans
        // conservés ne seront jamais rendus.
        if (_couverte || widget.etat == EtatSession.fermee) _viderPile();
        if (_couverte) _abandonner();
    }
  }

  void _couvrir() {
    _couverte = true;
    _perimee = false;
    _verrouilleeLe = widget.horloge();
    _peremption?.cancel();
    _peremption = Timer(widget.delai, _perimer);
  }

  /// Délai écoulé, verrou toujours en place : les écrans conservés sont
  /// abandonnés sans attendre le code — ils n'ont plus à rester en mémoire.
  void _perimer() {
    if (!mounted || !_couverte) return;
    widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _perimee = true;
      _generation++;
    });
  }

  void _decouvrir() {
    _peremption?.cancel();
    final verrouilleeLe = _verrouilleeLe;
    final expiree = !_perimee &&
        verrouilleeLe != null &&
        widget.horloge().difference(verrouilleeLe) >= widget.delai;
    if (!expiree) {
      _couverte = false;
      return;
    }
    // Délai dépassé sans que le minuteur ait sonné (application suspendue) :
    // l'écran de code reste en place le temps de vider la pile, pour ne jamais
    // laisser entrevoir la page abandonnée.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_couverte) return;
      widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() {
        _generation++;
        _couverte = false;
      });
    });
  }

  void _abandonner() {
    _peremption?.cancel();
    _couverte = false;
    _generation++;
  }

  /// Retire les écrans empilés pour révéler la page d'accès.
  void _viderPile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  /// Sous l'écran de code, le retour arrière ne doit pas dépiler la page
  /// cachée : il ferme une boîte de dialogue de l'écran de code, sinon quitte
  /// l'application comme depuis n'importe quelle page d'accueil.
  @override
  Future<bool> didPopRoute() async {
    if (!_couverte) return false;
    final navigateur = _navigateurVerrou.currentState;
    if (navigateur != null && navigateur.canPop()) {
      navigateur.pop();
    } else {
      await SystemNavigator.pop();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        Conservation(
          couverte: _couverte,
          cleAccueil: ValueKey(_generation),
          cleNavigateurVerrou: _navigateurVerrou,
        ),
      );
}

/// Pose l'écran de code par-dessus l'application sans la démonter.
///
/// À placer dans le `builder` du `MaterialApp`, autour du navigateur qu'il
/// reçoit. L'application cachée ne se peint pas, ne reçoit ni toucher, ni
/// focus clavier, ni lecteur d'écran, et ses animations sont suspendues.
class CouvertureVerrou extends StatelessWidget {
  final Conservation conservation;
  final Widget ecranVerrou;

  /// Navigateur de l'application.
  final Widget child;

  const CouvertureVerrou({
    super.key,
    required this.conservation,
    required this.ecranVerrou,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final couverte = conservation.couverte;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Toujours en tête, sous la même forme : le navigateur n'est jamais
        // reconstruit d'un verrouillage à l'autre.
        ExcludeFocus(
          excluding: couverte,
          child: TickerMode(
            enabled: !couverte,
            child: Offstage(offstage: couverte, child: child),
          ),
        ),
        if (couverte)
          // Messager et navigateur à part : un message ou une boîte de
          // dialogue émis par la page cachée reste sous le verrou.
          ScaffoldMessenger(
            child: HeroControllerScope.none(
              child: Navigator(
                key: conservation.cleNavigateurVerrou,
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => ecranVerrou),
              ),
            ),
          ),
      ],
    );
  }
}
