import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/contravention.dart';

/// Carte premium d'une contravention d'État — badges d'infraction, chip de
/// rattachement (Auto / À rattacher) et méta date · heure · vitesse · n°.
/// Un appui long sur une ligne active le mode sélection (paiement en lot) en
/// sélectionnant cette ligne ; en mode sélection, un tap sélectionne /
/// désélectionne (la carte passe en vert). Hors mode, un tap ouvre le détail.
/// Le chevron à droite ouvre le détail dans tous les cas. Les contraventions
/// déjà soldées ne sont pas sélectionnables : leur tap ouvre le détail.
class ContraventionCard extends StatelessWidget {
  final Contravention contravention;
  final VoidCallback? onEdit;

  /// La carte est sélectionnée.
  final bool selected;

  /// La carte peut être sélectionnée (une contravention soldée ne l'est pas).
  final bool selectable;

  /// Le mode sélection est actif : dans ce mode, un tap sur la ligne la
  /// sélectionne / désélectionne. Hors mode, un tap ouvre le détail.
  final bool selectionMode;

  /// Bascule de sélection de la ligne (mode sélection actif).
  final ValueChanged<bool>? onSelectChanged;

  /// Appui long sur la ligne : active le mode sélection en sélectionnant cette
  /// ligne. Null si la ligne n'est pas identifiable / pas sélectionnable.
  final VoidCallback? onEnterSelection;

  const ContraventionCard({
    super.key,
    required this.contravention,
    this.onEdit,
    this.selected = false,
    this.selectable = true,
    this.selectionMode = false,
    this.onSelectChanged,
    this.onEnterSelection,
  });

  // Fonds de la pastille d'infraction, par gravité — pastel volontairement
  // désaturé : la couleur situe, elle n'alerte pas.
  static const _graveBg = Color(0xFFFBE9E9);
  static const _moyenneBg = Color(0xFFFAF0DE);
  static const _legereBg = Color(0xFFEDF3E6);
  static const _ambre = Color(0xFF854F0B);
  static const _vert = Color(0xFF2E7D32);
  static const _ink = Color(0xFF1A1A2E);
  static const _label = Color(0xFF6B7280);
  static const _hint = Color(0xFF8A94A6);
  static const _border = Color(0xFFE4E9EE);
  static const _primary = Color(0xFF43A047);
  static const _selBg = Color(0xFFF3FAF4);

  /// Gravité de l'infraction, lue dans le montant : le barème de l'État suit
  /// la gravité, et c'est la seule donnée toujours renseignée.
  Color _graviteBg() {
    final montant = contravention.montant;
    if (montant >= 25000) return _graveBg;
    if (montant >= 10000) return _moyenneBg;
    return _legereBg;
  }

  (String, Color) _statut() {
    if (contravention.isReverse) return ('Reversé', _vert);
    if (contravention.isPaid) return ('Payé', _vert);
    if (contravention.isPartial) return ('Partiel', _ambre);
    if (contravention.isCancelled) return ('Annulé', _hint);
    return ('En attente', _hint);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final aRattacher = contravention.aRattacher;
    final (statutLabel, statutColor) = _statut();

    final dimmed = !selectable;

    // Paiement partiel : on met en avant ce qui a déjà été réglé plutôt que le
    // montant de la contravention, qui reste rappelé sous le chiffre.
    final montantAffiche = contravention.isPartial
        ? (contravention.montantPaye ?? contravention.montant)
        : contravention.montant;

    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titre(aRattacher),
                  const SizedBox(height: 7),
                  // Type d'infraction et date sur la même ligne ; le Wrap les
                  // renvoie l'un sous l'autre quand la place manque.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _pill(contravention.typeInfraction ?? 'Contravention',
                          _graviteBg()),
                      _metaItem(Icons.calendar_today_outlined, _dateLabel()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt.format(montantAffiche),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                // Paiement partiel : le montant affiché est ce qui a déjà été
                // réglé, on rappelle donc le total dû juste en dessous.
                if (montantAffiche != contravention.montant)
                  Text('sur ${fmt.format(contravention.montant)} XOF',
                      style: const TextStyle(fontSize: 10, color: _hint)),
                const SizedBox(height: 2),
                Text(statutLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statutColor)),
              ],
            ),
          ],
        ),
      ],
    );

    // Pas de case à cocher :
    //  • hors mode sélection → un tap ouvre le détail ; un appui long active le
    //    mode sélection en sélectionnant cette ligne.
    //  • en mode sélection → un tap sélectionne / désélectionne la ligne (la
    //    carte passe en vert). Le chevron ouvre toujours le détail.
    // Une ligne soldée n'est jamais sélectionnable : son tap ouvre le détail.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (selectionMode && selectable)
          ? () => onSelectChanged?.call(!selected)
          : onEdit,
      onLongPress: (!selectionMode && selectable) ? onEnterSelection : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.fromLTRB(14, 13, 8, 12),
        decoration: BoxDecoration(
          color: selected ? _selBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? _primary : _border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Opacity(opacity: dimmed ? 0.55 : 1, child: contenu),
            ),
            // Chevron : accès au détail, indépendant de la sélection de la ligne.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child:
                    Icon(Icons.chevron_right_rounded, size: 22, color: _hint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titre(bool aRattacher) {
    final vehicule = contravention.vehiculeNom ?? 'Véhicule';
    // Le nom du chauffeur n'est affiché que si le lien est établi (rattachement
    // AUTO ou MANUEL). Sinon, on n'affiche que le véhicule.
    final chauffeur = aRattacher ? null : contravention.chauffeurNom;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
        children: [
          TextSpan(text: vehicule),
          if (chauffeur != null && chauffeur.isNotEmpty)
            TextSpan(text: ' - $chauffeur'),
        ],
      ),
    );
  }

  String _dateLabel() {
    final d = contravention.dateInfraction;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
    final heure = (contravention.heureInfraction != null &&
            contravention.heureInfraction!.length >= 5)
        ? contravention.heureInfraction!.substring(0, 5)
        : null;
    return heure != null ? '$date · $heure' : date;
  }

  /// Pastille du type d'infraction : libellé en gris, seul le fond porte la
  /// gravité.
  Widget _pill(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: _label)),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _label),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11.5, color: _label)),
    ]);
  }
}
