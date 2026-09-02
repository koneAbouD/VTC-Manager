import 'package:flutter/material.dart';

import '../models/apercu_reaffectation.dart';
import '../theme/app_colors.dart';
import 'app_error_banner.dart';

/// Ce que la réaffectation va entraîner, dit en clair et chiffré.
///
/// L'écran de confirmation ne demande pas « êtes-vous sûr ? » — question à
/// laquelle personne ne sait répondre — il énonce ce qui va se passer. Chaque
/// ligne est une conséquence réelle, pas un avertissement générique.
class ImpactReaffectation {
  final String texte;

  /// Vrai pour ce qui déborde de la créance elle-même — une pénalité qui
  /// bascule, par exemple. Ces lignes se lisent en ambre : elles méritent une
  /// seconde de plus.
  final bool secondaire;

  const ImpactReaffectation(this.texte, {this.secondaire = false});
}

/// Ouvre la feuille de réaffectation d'une créance (recette ou cotisation).
///
/// Deux temps dans **une seule** feuille, en glissement horizontal : choisir,
/// puis confirmer. Deux modales empilées feraient perdre le contexte et le
/// retour arrière deviendrait une reprise à zéro.
///
/// [onReaffecter] reçoit le chauffeur choisi et le motif, et retourne `null` si
/// le serveur a accepté, ou le message d'erreur à afficher **dans la feuille**.
/// Un refus peut naître entre l'ouverture et la validation — une clôture de
/// caisse entre-temps — et cette phrase-là doit rester lisible, pas glisser
/// dans un snackbar qui passe.
///
/// Retourne `true` si la réaffectation a abouti.
Future<bool?> showReaffectationChauffeurSheet(
  BuildContext context, {
  required String titre,
  required String sousTitre,
  required String chauffeurActuel,
  required Future<ApercuReaffectation> Function() chargerApercu,
  required List<ImpactReaffectation> Function(
          ImpactsReaffectation impacts, CandidatChauffeur choisi)
      decrireImpacts,
  required Future<String?> Function(CandidatChauffeur choisi, String motif) onReaffecter,
  Color accent = AppColors.primaryDark,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReaffectationSheet(
      titre: titre,
      sousTitre: sousTitre,
      chauffeurActuel: chauffeurActuel,
      chargerApercu: chargerApercu,
      decrireImpacts: decrireImpacts,
      onReaffecter: onReaffecter,
      accent: accent,
    ),
  );
}

// ── Feuille ──────────────────────────────────────────────────────────────────

class _ReaffectationSheet extends StatefulWidget {
  final String titre;
  final String sousTitre;
  final String chauffeurActuel;
  final Future<ApercuReaffectation> Function() chargerApercu;
  final List<ImpactReaffectation> Function(ImpactsReaffectation, CandidatChauffeur) decrireImpacts;
  final Future<String?> Function(CandidatChauffeur, String) onReaffecter;
  final Color accent;

  const _ReaffectationSheet({
    required this.titre,
    required this.sousTitre,
    required this.chauffeurActuel,
    required this.chargerApercu,
    required this.decrireImpacts,
    required this.onReaffecter,
    required this.accent,
  });

  @override
  State<_ReaffectationSheet> createState() => _ReaffectationSheetState();
}

class _ReaffectationSheetState extends State<_ReaffectationSheet> {
  final _rechercheCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  late Future<ApercuReaffectation> _apercu;
  String _q = '';
  CandidatChauffeur? _choisi;
  ImpactsReaffectation? _impactsCharges;
  bool _confirmation = false;
  bool _envoi = false;
  String? _erreur;
  bool _motifManquant = false;

  @override
  void initState() {
    super.initState();
    _apercu = widget.chargerApercu();
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  void _choisir(CandidatChauffeur c) {
    FocusScope.of(context).unfocus();
    setState(() {
      _choisi = c;
      _confirmation = true;
      _erreur = null;
    });
  }

  void _retour() {
    FocusScope.of(context).unfocus();
    setState(() {
      _confirmation = false;
      _erreur = null;
      _motifManquant = false;
    });
  }

  Future<void> _valider() async {
    final motif = _motifCtrl.text.trim();
    if (motif.isEmpty) {
      setState(() => _motifManquant = true);
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
      _motifManquant = false;
    });

    final erreur = await widget.onReaffecter(_choisi!, motif);
    if (!mounted) return;

    if (erreur != null) {
      setState(() {
        _envoi = false;
        _erreur = erreur;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final hauteurMax = MediaQuery.sizeOf(context).height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: hauteurMax),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // Le glissement dit le sens de la navigation : l'étape 2
                  // arrive par la droite, le retour repart vers la gauche.
                  final depuisLaDroite = child.key == const ValueKey('confirmation');
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(depuisLaDroite ? 0.12 : -0.12, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _confirmation
                    ? _confirmationView(bottomSafe)
                    : _choixView(bottomSafe),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Étape 1 : choisir ─────────────────────────────────────────────────────

  Widget _choixView(double bottomSafe) {
    return Column(
      key: const ValueKey('choix'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titre,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                      letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text(widget.sousTitre,
                  style: const TextStyle(fontSize: 12, color: AppColors.hint)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _rechercheCtrl,
            onChanged: (v) => setState(() => _q = v),
            style: const TextStyle(fontSize: 14, color: AppColors.dark),
            decoration: InputDecoration(
              hintText: 'Rechercher un chauffeur…',
              hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 20, color: AppColors.hint),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accent, width: 1.5),
              ),
            ),
          ),
        ),
        Flexible(
          child: FutureBuilder<ApercuReaffectation>(
            future: _apercu,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomSafe),
                  child: AppErrorBanner(
                    message: snap.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                  ),
                );
              }
              _impactsCharges = snap.data!.impacts;
              return _liste(snap.data!.candidats, bottomSafe);
            },
          ),
        ),
      ],
    );
  }

  Widget _liste(List<CandidatChauffeur> tous, double bottomSafe) {
    final q = _q.trim().toLowerCase();
    final filtres = q.isEmpty
        ? tous
        : tous.where((c) => c.nom.toLowerCase().contains(q)).toList();

    if (filtres.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(0, 44, 0, 44 + bottomSafe),
        child: const Center(
          child: Text('Aucun chauffeur',
              style: TextStyle(color: AppColors.hint, fontSize: 14)),
        ),
      );
    }

    // Le chauffeur en place ouvre la liste : c'est le repère, et refermer sans
    // rien changer reste le geste le plus fréquent. Le tri vient du serveur —
    // actuel, puis conducteurs attendus, puis les autres.
    final actuel = filtres.where((c) => c.actuel).toList();
    final programme = filtres.where((c) => !c.actuel && c.auProgramme).toList();
    final autres = filtres.where((c) => !c.actuel && !c.auProgramme).toList();

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + bottomSafe),
      children: [
        for (final c in actuel) _tuile(c, actuelle: true),
        if (programme.isNotEmpty) ...[
          const _SectionLabel('Au programme ce jour-là'),
          for (final c in programme) _tuile(c),
        ],
        if (autres.isNotEmpty) ...[
          const _SectionLabel('Autres chauffeurs'),
          for (final c in autres) _tuile(c),
        ],
      ],
    );
  }

  Widget _tuile(CandidatChauffeur c, {bool actuelle = false}) {
    // Le serveur ne fournit pas de motif pour le chauffeur en place : la tuile
    // le nomme elle-même.
    // Un candidat pris ailleurs reste visible, grisé, avec sa raison : le
    // masquer ferait chercher, le laisser choisissable serait un piège.
    final bloque = !c.eligible || actuelle;
    final initiales = _initiales(c.nom);
    final sousTitre = actuelle ? 'Chauffeur actuel' : c.motif;

    return Opacity(
      opacity: c.eligible ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: bloque ? null : () => _choisir(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: actuelle
                    ? widget.accent.withValues(alpha: 0.10)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: actuelle
                      ? widget.accent.withValues(alpha: 0.40)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: actuelle
                          ? widget.accent
                          : c.eligible
                              ? widget.accent.withValues(alpha: 0.14)
                              : AppColors.fieldFill,
                      shape: BoxShape.circle,
                    ),
                    child: Text(initiales,
                        style: TextStyle(
                            color: actuelle
                                ? Colors.white
                                : c.eligible
                                    ? widget.accent
                                    : AppColors.hint,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.dark,
                                fontWeight: actuelle
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        if (sousTitre != null && sousTitre.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(sousTitre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: actuelle
                                        ? widget.accent
                                        : c.eligible
                                            ? AppColors.hint
                                            : AppColors.warning)),
                          ),
                      ],
                    ),
                  ),
                  if (actuelle)
                    Icon(Icons.check_circle_rounded, color: widget.accent, size: 20)
                  else if (!c.eligible)
                    const Icon(Icons.lock_outline_rounded,
                        color: AppColors.warning, size: 16)
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.hint, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Étape 2 : confirmer ───────────────────────────────────────────────────

  Widget _confirmationView(double bottomSafe) {
    final choisi = _choisi!;
    // Les faits sont ceux que le serveur a comptés ; la phrase se compose ici,
    // là où le nom du chauffeur et le format des montants sont connus.
    final lignes = widget.decrireImpacts(_impactsCharges!, choisi);

    return ListView(
      key: const ValueKey('confirmation'),
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomSafe),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _envoi ? null : _retour,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Retour au choix'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.label,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Avant → après. Le nom qu'on quitte reste lisible mais barré : c'est
        // ce qui rend le geste relisable d'un coup d'œil.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Personne(
                initiales: _initiales(widget.chauffeurActuel),
                nom: widget.chauffeurActuel,
                sortant: true,
                accent: widget.accent,
              ),
              Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.only(left: 13, top: 3, bottom: 3),
                color: AppColors.border,
              ),
              _Personne(
                initiales: _initiales(choisi.nom),
                nom: choisi.nom,
                sortant: false,
                accent: widget.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const _SectionLabel('Ce qui va changer', dansCarte: false),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lignes.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == lignes.length - 1 ? 0 : 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 13,
                            color: lignes[i].secondaire
                                ? AppColors.warning
                                : widget.accent),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(lignes[i].texte,
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.42,
                                color: AppColors.dark)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            const _SectionLabel('Motif', dansCarte: false),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('obligatoire',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.error.withValues(alpha: 0.9))),
            ),
          ],
        ),
        TextField(
          controller: _motifCtrl,
          enabled: !_envoi,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_motifManquant) setState(() => _motifManquant = false);
          },
          style: const TextStyle(fontSize: 13.5, color: AppColors.dark),
          decoration: InputDecoration(
            hintText: 'Pourquoi cette créance change-t-elle de chauffeur ?',
            hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
            filled: true,
            fillColor: AppColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _motifManquant ? AppColors.error : AppColors.border,
                  width: _motifManquant ? 1.4 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _motifManquant ? AppColors.error : widget.accent,
                  width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        if (_motifManquant)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Sans motif, la réaffectation ne pourra pas s’expliquer plus tard.',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),

        // L'échec s'affiche ici, pas dans un snackbar qui passe : un refus peut
        // naître entre l'ouverture de la feuille et la validation, et la phrase
        // qui l'explique doit rester sous les yeux.
        if (_erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: AppErrorBanner(message: _erreur!),
          ),

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _envoi ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.label,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: _envoi ? null : _valider,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _envoi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Réaffecter',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Briques ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String texte;
  final bool dansCarte;

  const _SectionLabel(this.texte, {this.dansCarte = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(dansCarte ? 4 : 2, dansCarte ? 12 : 0, 0, 8),
      child: Text(
        texte.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.hint),
      ),
    );
  }
}

class _Personne extends StatelessWidget {
  final String initiales;
  final String nom;
  final bool sortant;
  final Color accent;

  const _Personne({
    required this.initiales,
    required this.nom,
    required this.sortant,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sortant ? AppColors.fieldFill : accent,
            shape: BoxShape.circle,
          ),
          child: Text(initiales,
              style: TextStyle(
                  color: sortant ? AppColors.hint : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: sortant ? 13 : 14,
              fontWeight: sortant ? FontWeight.w500 : FontWeight.w700,
              color: sortant ? AppColors.hint : AppColors.dark,
              decoration: sortant ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.hint,
            ),
          ),
        ),
      ],
    );
  }
}

/// « Aya Traoré » → « AT ». Une seule initiale si le nom tient en un mot.
String _initiales(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return '•';
  if (mots.length == 1) return mots.first[0].toUpperCase();
  return (mots.first[0] + mots.last[0]).toUpperCase();
}
