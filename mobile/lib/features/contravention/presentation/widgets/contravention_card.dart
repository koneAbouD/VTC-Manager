import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/contravention.dart';

/// Carte premium d'une contravention d'État — badges d'infraction, chip de
/// rattachement (Auto / À rattacher) et méta date · heure · vitesse · n°.
/// Tap → édition ; appui long → actions (payer / supprimer).
class ContraventionCard extends StatelessWidget {
  final Contravention contravention;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPay;

  const ContraventionCard({
    super.key,
    required this.contravention,
    this.onEdit,
    this.onDelete,
    this.onPay,
  });

  static const _rouge = Color(0xFFB71C1C);
  static const _rougeBg = Color(0xFFFCEBEB);
  static const _ambre = Color(0xFF854F0B);
  static const _ambreBg = Color(0xFFFAEEDA);
  static const _vert = Color(0xFF2E7D32);
  static const _vertBg = Color(0xFFEAF3DE);
  static const _ink = Color(0xFF1A1A2E);
  static const _label = Color(0xFF6B7280);
  static const _hint = Color(0xFF8A94A6);
  static const _border = Color(0xFFE4E9EE);

  String _typeLabel() {
    switch (contravention.codeInfraction) {
      case '046':
        return 'Excès +20 km/h';
      case '045':
        return 'Excès 10-20 km/h';
      default:
        return contravention.typeInfraction ?? 'Contravention';
    }
  }

  (String, Color, Color, IconData)? _rattachement() {
    switch (contravention.statutRattachement) {
      case 'AUTO':
        return ('Auto', _vert, _vertBg, Icons.person_search_outlined);
      case 'MANUEL':
        return ('Manuel', _vert, _vertBg, Icons.person_outline);
      case 'A_RATTACHER':
        return ('À rattacher', _ambre, _ambreBg, Icons.help_outline);
      default:
        return null;
    }
  }

  (String, Color) _statut() {
    if (contravention.isPaid) return ('Payé', _vert);
    if (contravention.isPartial) return ('Partiel', _ambre);
    return ('En attente', _hint);
  }

  void _openActions(BuildContext context) {
    if (onPay == null && onDelete == null) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!contravention.isPaid && onPay != null)
              ListTile(
                leading: const Icon(Icons.payments_outlined, color: _vert),
                title: const Text('Enregistrer un paiement'),
                onTap: () {
                  Navigator.pop(ctx);
                  onPay!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: _rouge),
                title: const Text('Supprimer'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final aRattacher = contravention.aRattacher;
    final (statutLabel, statutColor) = _statut();
    final rattach = _rattachement();

    return GestureDetector(
      onTap: onEdit,
      onLongPress: () => _openActions(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _pill(_typeLabel(), _rouge, _rougeBg),
                          if (rattach != null)
                            _pill(rattach.$1, rattach.$2, rattach.$3,
                                icon: rattach.$4),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt.format(contravention.montant),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 9),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(children: _meta()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titre(bool aRattacher) {
    final vehicule = contravention.vehiculeNom ?? 'Véhicule';
    final chauffeur =
        aRattacher ? 'À rattacher' : (contravention.chauffeurNom ?? '—');
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
        children: [
          TextSpan(text: '$vehicule · '),
          TextSpan(
            text: chauffeur,
            style: TextStyle(color: aRattacher ? _ambre : _ink),
          ),
        ],
      ),
    );
  }

  List<Widget> _meta() {
    final d = contravention.dateInfraction;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
    final heure = (contravention.heureInfraction != null &&
            contravention.heureInfraction!.length >= 5)
        ? contravention.heureInfraction!.substring(0, 5)
        : null;
    final items = <Widget>[
      _metaItem(Icons.calendar_today_outlined,
          heure != null ? '$date · $heure' : date),
    ];
    if (contravention.vitesseRelevee != null) {
      items.add(const SizedBox(width: 13));
      items.add(_metaItem(Icons.speed_outlined,
          '${contravention.vitesseRelevee} km/h'));
    }
    final num = contravention.numeroContravention;
    if (num != null && num.length >= 6) {
      items.add(const Spacer());
      items.add(Text('#${num.substring(num.length - 6)}',
          style: const TextStyle(fontSize: 11.5, color: _hint)));
    }
    return items;
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _label),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11.5, color: _label)),
    ]);
  }

  Widget _pill(String label, Color fg, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
