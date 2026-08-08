import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';

/// Réglages globaux de l'application (paramètres clé-valeur).
///
/// Tout se règle sur place : la valeur affichée est un bouton qui déplie, dans
/// la ligne même, une roulette de valeurs — aucune fenêtre ne s'ouvre par-dessus
/// la page, et il n'y a rien à valider, la valeur choisie part d'elle-même.
/// Les réglages sont regroupés par domaine : les trois taux de provision
/// forment un barème qui ne se comprend que d'un bloc.
class ParametresGenerauxPage extends ConsumerStatefulWidget {
  const ParametresGenerauxPage({super.key});

  @override
  ConsumerState<ParametresGenerauxPage> createState() =>
      _ParametresGenerauxPageState();
}

class _ParametresGenerauxPageState
    extends ConsumerState<ParametresGenerauxPage> {
  /// Clé du réglage actuellement déplié : un seul à la fois, la page reste
  /// lisible et l'on ne se demande jamais quelle valeur on est en train de
  /// modifier.
  String? _cleOuverte;

  /// Enregistre une valeur. Retourne `null` en cas de succès, sinon le message
  /// d'erreur — que la ligne affiche sous elle, sans se refermer, pour ne pas
  /// faire perdre la sélection.
  Future<String?> _enregistrer(ParametreGeneral p, String valeur) async {
    try {
      await ref
          .read(parametrageApiProvider)
          .mettreAJourParametre(p.cle, valeur);
      ref.invalidate(parametresProvider);
      // Plusieurs paramètres pilotent directement les états : la durée
      // d'amortissement commande la dotation et la valeur nette des véhicules
      // qui n'ont pas de durée propre, les taux de provision commandent la
      // dépréciation des créances. On rafraîchit sans distinguer la clé : ces
      // réglages changent rarement, et une nouvelle clé financière serait
      // sinon oubliée ici.
      refreshFinances(ref);
      return null;
    } catch (e) {
      return messageFromError(e, fallback: "Échec de l'enregistrement.");
    }
  }

  void _basculer(String cle) =>
      setState(() => _cleOuverte = _cleOuverte == cle ? null : cle);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parametresProvider);
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Paramètres généraux'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _EtatVide(
          icone: Icons.cloud_off_rounded,
          message: 'Impossible de charger les paramètres.',
          onReessayer: () => ref.invalidate(parametresProvider),
        ),
        data: (params) => params.isEmpty
            ? const _EtatVide(
                icone: Icons.tune_rounded,
                message: 'Aucun paramètre disponible.',
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(parametresProvider);
                  await ref.read(parametresProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                  children: [
                    for (final groupe in _grouper(params)) ...[
                      _SectionGroupe(
                        groupe: groupe,
                        cleOuverte: _cleOuverte,
                        onBasculer: _basculer,
                        onEnregistrer: _enregistrer,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modèle de présentation
// ---------------------------------------------------------------------------

/// Nature d'un paramètre, déduite de sa clé : commande les valeurs proposées
/// par la roulette, l'unité affichée et, à défaut, le repli sur un champ libre.
enum _TypeParametre { duree, pourcentage, texte }

/// Famille de réglages affichée sous un même intertitre.
class _Groupe {
  final String titre;
  final Color accent;
  final List<ParametreGeneral> parametres;

  const _Groupe({
    required this.titre,
    required this.parametres,
    this.accent = AppColors.primary,
  });
}

/// Range les paramètres par domaine, dans un ordre fixe.
///
/// Le rattachement se déduit du préfixe de la clé, et toute clé inconnue tombe
/// dans « Autres réglages » : un paramètre ajouté côté backend apparaît donc
/// ici sans modification du mobile.
List<_Groupe> _grouper(List<ParametreGeneral> params) {
  final amortissement = <ParametreGeneral>[];
  final provisions = <ParametreGeneral>[];
  final autres = <ParametreGeneral>[];

  for (final p in params) {
    if (p.cle.startsWith('DUREE_AMORTISSEMENT')) {
      amortissement.add(p);
    } else if (p.cle.startsWith('PROVISION_')) {
      provisions.add(p);
    } else {
      autres.add(p);
    }
  }

  return [
    if (amortissement.isNotEmpty)
      _Groupe(titre: 'Amortissement', parametres: amortissement),
    if (provisions.isNotEmpty)
      _Groupe(
        titre: 'Provisions sur créances',
        accent: AppColors.warning,
        parametres: provisions,
      ),
    if (autres.isNotEmpty)
      _Groupe(titre: 'Autres réglages', parametres: autres),
  ];
}

_TypeParametre _typeDe(ParametreGeneral p) {
  if (p.cle == kCleDureeAmortissement || p.cle.endsWith('_MOIS')) {
    return _TypeParametre.duree;
  }
  if (p.cle.contains('TAUX') || p.cle.contains('POURCENTAGE')) {
    return _TypeParametre.pourcentage;
  }
  return _TypeParametre.texte;
}

/// Unité accolée à la valeur, vide pour un paramètre texte.
String _uniteDe(_TypeParametre type) => switch (type) {
      _TypeParametre.duree => 'mois',
      _TypeParametre.pourcentage => '%',
      _TypeParametre.texte => '',
    };

/// Valeur telle qu'on la lit : « 60 mois », « 25 % », ou la valeur brute.
String _valeurAffichee(String valeur, _TypeParametre type) {
  final v = valeur.trim();
  if (v.isEmpty) return '—';
  final unite = _uniteDe(type);
  return unite.isEmpty ? v : '$v $unite';
}

/// « 60 » → « 5 ans », « 55 » → « ≈ 4,6 ans ». Null si la saisie n'est pas une
/// durée exploitable : l'aide disparaît alors au lieu d'afficher une conversion
/// trompeuse.
String? _enAnnees(String valeurMois) {
  final mois = int.tryParse(valeurMois.trim());
  if (mois == null || mois <= 0) return null;
  final annees = mois / 12;
  final rond = annees == annees.roundToDouble();
  final str = rond
      ? annees.toInt().toString()
      : annees.toStringAsFixed(1).replaceAll('.', ',');
  return '${rond ? '' : '≈ '}$str an${annees >= 2 ? 's' : ''}';
}

/// Valeurs proposées par la roulette.
///
/// Le pas reste large — six mois, cinq points de pourcentage — pour qu'une
/// valeur usuelle s'atteigne en un geste. La valeur enregistrée est toujours
/// insérée si elle sort du pas : on ne perd jamais un réglage saisi ailleurs.
List<int> _optionsRoulette(_TypeParametre type, String valeurCourante) {
  final options = switch (type) {
    _TypeParametre.duree => [for (var m = 6; m <= 120; m += 6) m],
    _TypeParametre.pourcentage => [for (var t = 0; t <= 100; t += 5) t],
    _TypeParametre.texte => <int>[],
  };
  final courante = int.tryParse(valeurCourante.trim());
  if (courante != null && !options.contains(courante)) {
    options
      ..add(courante)
      ..sort();
  }
  return options;
}

// ---------------------------------------------------------------------------
// Liste
// ---------------------------------------------------------------------------

/// Intertitre discret + carte des réglages du groupe.
class _SectionGroupe extends StatelessWidget {
  final _Groupe groupe;
  final String? cleOuverte;
  final ValueChanged<String> onBasculer;
  final Future<String?> Function(ParametreGeneral, String) onEnregistrer;

  const _SectionGroupe({
    required this.groupe,
    required this.cleOuverte,
    required this.onBasculer,
    required this.onEnregistrer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            groupe.titre.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.label,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (var i = 0; i < groupe.parametres.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 14,
                      endIndent: 14,
                      color: AppColors.border,
                    ),
                  _LigneParametre(
                    parametre: groupe.parametres[i],
                    accent: groupe.accent,
                    ouverte: cleOuverte == groupe.parametres[i].cle,
                    onBasculer: () => onBasculer(groupe.parametres[i].cle),
                    onEnregistrer: (v) =>
                        onEnregistrer(groupe.parametres[i], v),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Durée de l'animation de dépli, alignée sur celle des accordéons de la page
/// Paramètres.
const _kTransition = Duration(milliseconds: 220);

/// Largeur de la colonne de droite : le bouton de valeur et la roulette qu'il
/// déplie la partagent, pour que la roulette se lise comme un prolongement du
/// bouton et non comme un bandeau à part. Fixe, elle empêche aussi la roulette
/// de s'étirer sur toute la largeur d'une tablette.
const double _kColonneValeur = 112;

/// Délai d'inactivité avant enregistrement automatique.
///
/// Assez long pour qu'un défilement continu ne déclenche qu'un seul appel,
/// assez court pour que le réglage soit acquis avant qu'on ne quitte la page.
const _kDelaiEnregistrement = Duration(milliseconds: 800);

/// Une ligne de réglage : libellé, description, et la valeur courante dans un
/// bouton qui déplie la roulette juste en dessous.
///
/// **Il n'y a rien à valider ni à attendre** : la valeur choisie part d'elle-
/// même une fois la roulette immobile, et l'envoi ne se signale pas. Le bouton
/// affiche simplement ce qui est réglé ; seul un refus du serveur interrompt
/// ce silence.
class _LigneParametre extends StatefulWidget {
  final ParametreGeneral parametre;
  final Color accent;
  final bool ouverte;
  final VoidCallback onBasculer;
  final Future<String?> Function(String) onEnregistrer;

  const _LigneParametre({
    required this.parametre,
    required this.accent,
    required this.ouverte,
    required this.onBasculer,
    required this.onEnregistrer,
  });

  @override
  State<_LigneParametre> createState() => _LigneParametreState();
}

class _LigneParametreState extends State<_LigneParametre> {
  /// Valeur en cours de réglage, tant qu'elle n'est pas revenue du serveur.
  /// Null quand la ligne affiche la valeur enregistrée.
  String? _selection;

  Timer? _attente;
  String? _erreur;

  String get _enregistree => widget.parametre.valeur.trim();

  @override
  void didUpdateWidget(_LigneParametre ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.ouverte && !widget.ouverte) {
      // Replier n'annule pas : ce qui a été réglé part tout de suite, sans
      // attendre la fin du délai d'inactivité.
      if (_attente?.isActive ?? false) {
        _attente!.cancel();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _enregistrerMaintenant());
      } else {
        _selection = null;
        _erreur = null;
      }
    }
  }

  @override
  void dispose() {
    // La ligne disparaît alors qu'un réglage attendait encore : on l'envoie
    // sans plus s'occuper du résultat, plutôt que de le perdre en silence.
    if (_attente?.isActive ?? false) {
      _attente!.cancel();
      final valeur = _selection?.trim();
      if (valeur != null && valeur.isNotEmpty && valeur != _enregistree) {
        widget.onEnregistrer(valeur);
      }
    }
    _attente?.cancel();
    super.dispose();
  }

  /// Retient la valeur pointée et arme l'enregistrement.
  void _choisir(String valeur) {
    setState(() {
      _selection = valeur;
      _erreur = null;
    });
    _attente?.cancel();
    final v = valeur.trim();
    // Revenu au point de départ : plus rien à enregistrer.
    if (v.isEmpty || v == _enregistree) return;
    _attente = Timer(_kDelaiEnregistrement, _enregistrerMaintenant);
  }

  Future<void> _enregistrerMaintenant() async {
    final valeur = _selection?.trim();
    if (valeur == null || valeur.isEmpty || valeur == _enregistree) return;
    if (!mounted) return;

    // L'envoi ne se signale pas : la valeur choisie est déjà affichée, et la
    // faire clignoter d'un témoin d'activité ferait douter d'un réglage qui,
    // dans les faits, est acquis. Seul l'échec parle.
    final erreur = await widget.onEnregistrer(valeur);
    if (!mounted) return;
    setState(() {
      _erreur = erreur;
      // Succès : la valeur relue du serveur reprend la main.
      if (erreur == null) _selection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parametre = widget.parametre;
    final accent = widget.accent;
    final ouverte = widget.ouverte;

    final type = _typeDe(parametre);
    final affichee = _selection ?? _enregistree;
    final options = _optionsRoulette(type, _enregistree);
    final annees = type == _TypeParametre.duree ? _enAnnees(affichee) : null;

    return AnimatedContainer(
      duration: _kTransition,
      curve: Curves.easeOutCubic,
      color: ouverte ? AppColors.scaffold : AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onBasculer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parametre.libelle,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark,
                              ),
                            ),
                            if (parametre.description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                parametre.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  height: 1.3,
                                  color: AppColors.hint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: _kColonneValeur,
                  child: Column(
                    children: [
                      _BoutonValeur(
                        valeur: _valeurAffichee(affichee, type),
                        accent: accent,
                        ouvert: ouverte,
                        onTap: widget.onBasculer,
                      ),
                      if (annees != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          annees,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.hint),
                        ),
                      ],
                      // La roulette prolonge le bouton : même largeur, juste
                      // en dessous.
                      if (options.isNotEmpty)
                        AnimatedSize(
                          duration: _kTransition,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: ouverte
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: _Roulette(
                                    options: options,
                                    valeurInitiale: affichee,
                                    type: type,
                                    accent: accent,
                                    onChange: _choisir,
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Paramètre sans barème : le champ libre a besoin de toute la
          // largeur, il se déplie donc sous la ligne.
          if (options.isEmpty)
            AnimatedSize(
              duration: _kTransition,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: ouverte
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _ChampLibre(
                        valeurInitiale: _enregistree,
                        accent: accent,
                        onChange: _choisir,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),

          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_erreur!} Valeur en vigueur : '
                  '${_valeurAffichee(_enregistree, type)}.',
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.35, color: AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// La valeur courante, présentée comme le bouton qu'elle est : on tape dessus
/// pour la changer, le chevron indique le dépli. Pendant un enregistrement, il
/// cède la place à un témoin d'activité.
class _BoutonValeur extends StatelessWidget {
  final String valeur;
  final Color accent;
  final bool ouvert;
  final VoidCallback onTap;

  const _BoutonValeur({
    required this.valeur,
    required this.accent,
    required this.ouvert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: _kTransition,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: ouvert ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ouvert ? accent : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  valeur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: ouvert ? 0.5 : 0,
                duration: _kTransition,
                curve: Curves.easeOutCubic,
                child: Icon(Icons.expand_more_rounded, size: 18, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Réglage sur place
// ---------------------------------------------------------------------------

/// Roulette de valeurs, à la largeur du bouton qu'elle prolonge.
///
/// Montée à l'ouverture, démontée à la fermeture : elle démarre donc toujours
/// sur la valeur affichée, sans resynchronisation à faire.
class _Roulette extends StatefulWidget {
  final List<int> options;
  final String valeurInitiale;
  final _TypeParametre type;
  final Color accent;
  final ValueChanged<String> onChange;

  const _Roulette({
    required this.options,
    required this.valeurInitiale,
    required this.type,
    required this.accent,
    required this.onChange,
  });

  @override
  State<_Roulette> createState() => _RouletteState();
}

class _RouletteState extends State<_Roulette> {
  late final FixedExtentScrollController _controleur =
      // La valeur affichée est déjà sous le curseur à l'ouverture.
      FixedExtentScrollController(initialItem: _indexInitial);

  int get _indexInitial {
    final i = widget.options
        .indexOf(int.tryParse(widget.valeurInitiale.trim()) ?? -1);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: CupertinoPicker.builder(
        scrollController: _controleur,
        itemExtent: 32,
        squeeze: 1.1,
        diameterRatio: 1.5,
        backgroundColor: Colors.transparent,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onSelectedItemChanged: (i) => widget.onChange('${widget.options[i]}'),
        childCount: widget.options.length,
        itemBuilder: (_, i) => Center(
          child: Text(
            _valeurAffichee('${widget.options[i]}', widget.type),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Repli pour un paramètre libre (clé inconnue du mobile) : la roulette n'a
/// alors aucune valeur à proposer, on saisit le texte.
class _ChampLibre extends StatefulWidget {
  final String valeurInitiale;
  final Color accent;
  final ValueChanged<String> onChange;

  const _ChampLibre({
    required this.valeurInitiale,
    required this.accent,
    required this.onChange,
  });

  @override
  State<_ChampLibre> createState() => _ChampLibreState();
}

class _ChampLibreState extends State<_ChampLibre> {
  late final _controleur = TextEditingController(text: widget.valeurInitiale);

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controleur,
      onChanged: widget.onChange,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.dark,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.accent, width: 1.5),
        ),
      ),
    );
  }
}

/// Écran d'attente commun aux deux impasses : chargement en échec et liste
/// vide. Le bouton n'apparaît que s'il y a quelque chose à réessayer.
class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String message;
  final VoidCallback? onReessayer;

  const _EtatVide({
    required this.icone,
    required this.message,
    this.onReessayer,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.label)),
            if (onReessayer != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onReessayer,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
