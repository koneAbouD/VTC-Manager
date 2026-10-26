import 'dart:async';

import 'package:flutter/widgets.dart';

/// Lit d'avance les écrans clés, pour qu'ils soient servis hors connexion
/// même si l'utilisateur ne les a pas ouverts.
///
/// Enveloppe l'accueil : [precharger] part peu après l'ouverture de la session
/// (le temps que le premier écran ait chargé ce qu'il affiche — le réseau
/// mobile lui revient d'abord), puis à chaque retour au premier plan, au plus
/// une fois par [intervalle].
class PrechargementPeriodique extends StatefulWidget {
  final Future<void> Function() precharger;
  final Widget child;
  final Duration delai;
  final Duration intervalle;

  const PrechargementPeriodique({
    super.key,
    required this.precharger,
    required this.child,
    this.delai = const Duration(seconds: 3),
    this.intervalle = const Duration(minutes: 15),
  });

  @override
  State<PrechargementPeriodique> createState() =>
      _PrechargementPeriodiqueState();
}

class _PrechargementPeriodiqueState extends State<PrechargementPeriodique>
    with WidgetsBindingObserver {
  Timer? _depart;
  DateTime? _dernier;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _depart = Timer(widget.delai, _lancer);
  }

  @override
  void dispose() {
    _depart?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final dernier = _dernier;
    if (dernier == null ||
        DateTime.now().difference(dernier) >= widget.intervalle) {
      _lancer();
    }
  }

  Future<void> _lancer() async {
    if (_enCours || !mounted) return;
    _enCours = true;
    _dernier = DateTime.now();
    try {
      await widget.precharger();
    } catch (e) {
      debugPrint('tmk_cache : préchargement interrompu ($e)');
    } finally {
      _enCours = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
