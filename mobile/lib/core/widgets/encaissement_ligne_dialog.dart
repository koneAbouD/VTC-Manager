import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_error_banner.dart';

// ── Palette (cohérente avec MaintenanceFormPage) ──────────────────────────────

const _kPrimary   = Color(0xFF3B5BDB);
const _kGreen     = Color(0xFF2E7D32);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint      = Color(0xFF9AA0AE);
const _kLabel     = Color(0xFF6B7280);
const _kBorder    = Color(0xFFE3E6EE);
const _kDark      = Color(0xFF1A1A2E);
const _kError     = Color(0xFFE03131);

// ── Bouton "Encaisser" réutilisable sur les cartes ────────────────────────────

class EncaisserChip extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const EncaisserChip({
    super.key,
    required this.onTap,
    this.color = _kGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              'Encaisser',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toast ─────────────────────────────────────────────────────────────────────

void _showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
      ]),
      backgroundColor:
          error ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration:
          error ? const Duration(seconds: 4) : const Duration(seconds: 2),
    ));
}

// ── Entrée ────────────────────────────────────────────────────────────────────

/// Ouvre un popup d'encaissement pour une ligne (recette, cotisation, pénalité).
///
/// [onEncaisser] reçoit le montant et le commentaire saisi, retourne null si OK
/// ou un message d'erreur.
///
/// Retourne `true` si l'encaissement a réussi (pour déclencher un reload).
Future<bool?> showEncaissementLigneDialog(
  BuildContext context, {
  required String titre,
  String? sousTitre,
  double? montantRestant,
  Color couleur = _kGreen,
  IconData icone = Icons.payments_outlined,
  required Future<String?> Function(double montant, String? commentaire)
      onEncaisser,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF8F9FB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EncaissementLigneSheet(
      titre: titre,
      sousTitre: sousTitre,
      montantRestant: montantRestant,
      couleur: couleur,
      icone: icone,
      onEncaisser: onEncaisser,
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _EncaissementLigneSheet extends StatefulWidget {
  final String   titre;
  final String?  sousTitre;
  final double?  montantRestant;
  final Color    couleur;
  final IconData icone;
  final Future<String?> Function(double, String?) onEncaisser;

  const _EncaissementLigneSheet({
    required this.titre,
    required this.sousTitre,
    required this.montantRestant,
    required this.couleur,
    required this.icone,
    required this.onEncaisser,
  });

  @override
  State<_EncaissementLigneSheet> createState() =>
      _EncaissementLigneSheetState();
}

class _EncaissementLigneSheetState extends State<_EncaissementLigneSheet> {
  final _montantCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  bool  _submitting  = false;
  String? _submitError;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final montant = double.parse(_montantCtrl.text.replaceAll(',', '.'));
    final commentaire = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();

    final error = await widget.onEncaisser(montant, commentaire);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      // L'erreur s'affiche dans la feuille (bandeau inline) : un SnackBar
      // resterait masqué sous le bottom sheet tant qu'il est ouvert.
      _submitError = error;
    });

    if (error == null) {
      Navigator.pop(context, true);
      _showToast(context, 'Encaissement effectué avec succès');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    // useSafeArea applique SafeArea(bottom: false) : on ajoute l'inset de la
    // barre de navigation Android pour que le bouton ne passe pas dessous.
    final bottomSafe     = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight + bottomSafe),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Indicateur ────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Titre ─────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Encaisser',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                    letterSpacing: -0.4),
              ),
            ),

            // ── Info ligne ────────────────────────────────────────────
            _InfoCard(
              titre:          widget.titre,
              sousTitre:      widget.sousTitre,
              montantRestant: widget.montantRestant,
              couleur:        widget.couleur,
              icone:          widget.icone,
              fmt:            fmt,
            ),
            const SizedBox(height: 12),

            // ── Section encaissement ──────────────────────────────────
            _FormCard(
              icon:   Icons.payments_outlined,
              accent: _kGreen,
              title:  'Encaissement',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Montant
                  _LabeledField(
                    label:      'Montant',
                    isRequired: true,
                    child: TextFormField(
                      controller:  _montantCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco('0').copyWith(
                        suffixText: 'XOF',
                        suffixStyle: const TextStyle(
                            color: _kLabel,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      validator: (v) {
                        final val = double.tryParse(
                            v?.replaceAll(',', '.') ?? '');
                        if (val == null || val <= 0) {
                          return 'Montant invalide';
                        }
                        if (widget.montantRestant != null &&
                            val > widget.montantRestant!) {
                          return 'Dépasse le montant restant'
                              ' (${fmt.format(widget.montantRestant!)})';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Commentaire
                  _LabeledField(
                    label: 'Commentaire',
                    child: TextFormField(
                      controller: _commentCtrl,
                      maxLines:   2,
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco('Remarques éventuelles…'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Erreur de soumission (ex. mode de paiement non autorisé) ──
            if (_submitError != null) ...[
              AppErrorBanner(
                message: _submitError!,
                onClose: () => setState(() => _submitError = null),
              ),
              const SizedBox(height: 10),
            ],

            // ── Bouton ────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _submitting ? 'Encaissement en cours…' : 'Encaisser',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Carte info ligne ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String   titre;
  final String?  sousTitre;
  final double?  montantRestant;
  final Color    couleur;
  final IconData icone;
  final NumberFormat fmt;

  const _InfoCard({
    required this.titre,
    required this.sousTitre,
    required this.montantRestant,
    required this.couleur,
    required this.icone,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 18, color: couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kDark)),
              if (sousTitre != null)
                Text(sousTitre!,
                    style: const TextStyle(fontSize: 11, color: _kHint)),
            ],
          ),
        ),
        if (montantRestant != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Restant : ${fmt.format(montantRestant!)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: couleur),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Widgets locaux (réplique MaintenanceFormPage) ─────────────────────────────

class _FormCard extends StatelessWidget {
  final IconData icon;
  final Color    accent;
  final String   title;
  final Widget   child;

  const _FormCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    letterSpacing: -0.2)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool   isRequired;
  final Widget child;

  const _LabeledField({
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kLabel)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 15),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
    );
