import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/recu_paiement.dart';
import '../utils/whatsapp.dart';

/// Un destinataire, et le reçu déjà préparé pour lui.
class DestinataireRecu {
  final String nom;

  /// Numéro de sa fiche. Nul : WhatsApp s'ouvrira sur son choix de contact, à
  /// charge pour le guichetier de désigner le chauffeur.
  final String? telephone;

  /// Ce que le reçu couvre, en une ligne — « 3 journées · 45 000 XOF ».
  final String resume;

  final RecuPaiement recu;

  /// Écritures que le reçu PDF atteste : toutes celles du chauffeur dans le lot.
  final List<int> operationIds;

  const DestinataireRecu({
    required this.nom,
    this.telephone,
    required this.resume,
    required this.recu,
    this.operationIds = const [],
  });

  /// Le message seul, sans pièce jointe.
  String get message => composerRecu(recu);
}

/// Envoie le reçu d'un destinataire : `null` s'il est parti, sinon le motif à
/// afficher sous sa ligne.
typedef EnvoyerRecu = Future<String?> Function(DestinataireRecu destinataire);

/// Feuille d'envoi des reçus d'un encaissement de masse.
///
/// WhatsApp n'ouvre qu'une conversation à la fois : un lot qui touche plusieurs
/// chauffeurs se solde donc par autant d'allers-retours, et la feuille est ce
/// qui les rend tenables — elle retient qui a déjà été servi.
///
/// La coche dit « WhatsApp a été ouvert », jamais « le message est parti » :
/// rien ne revient de WhatsApp le confirmer. Quand le reçu PDF ne peut pas être
/// préparé, la ligne le dit et propose le message seul.
Future<void> showEnvoiRecusSheet(
  BuildContext context, {
  required List<DestinataireRecu> destinataires,
  required EnvoyerRecu envoyer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _EnvoiRecusSheet(destinataires: destinataires, envoyer: envoyer),
  );
}

class _EnvoiRecusSheet extends StatefulWidget {
  final List<DestinataireRecu> destinataires;
  final EnvoyerRecu envoyer;

  const _EnvoiRecusSheet({required this.destinataires, required this.envoyer});

  @override
  State<_EnvoiRecusSheet> createState() => _EnvoiRecusSheetState();
}

class _EnvoiRecusSheetState extends State<_EnvoiRecusSheet> {
  final Set<int> _ouverts = {};
  final Set<int> _enCours = {};
  final Map<int, String> _echecs = {};

  Future<void> _envoyer(int index) async {
    if (_enCours.contains(index)) return;
    setState(() {
      _enCours.add(index);
      _echecs.remove(index);
    });
    final motif = await widget.envoyer(widget.destinataires[index]);
    if (!mounted) return;
    setState(() {
      _enCours.remove(index);
      if (motif == null) {
        _ouverts.add(index);
      } else {
        _echecs[index] = motif;
      }
    });
  }

  /// Le PDF n'a pas pu partir : le message seul reste un reçu.
  Future<void> _messageSeul(int index) async {
    final destinataire = widget.destinataires[index];
    try {
      await ouvrirWhatsApp(
          telephone: destinataire.telephone, message: destinataire.message);
      if (!mounted) return;
      setState(() {
        _echecs.remove(index);
        _ouverts.add(index);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _echecs[index] = "WhatsApp n'a pas pu être ouvert sur cet appareil.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final reste = widget.destinataires.length - _ouverts.length;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E6EE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Envoyer les reçus',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              reste == 0
                  ? 'Tous les reçus ont été ouverts dans WhatsApp.'
                  : 'Chaque reçu part en PDF, joint au message, dans la '
                      'conversation du chauffeur. C\'est vous qui appuyez sur '
                      'envoyer.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: widget.destinataires.length,
              itemBuilder: (_, i) => _DestinataireTile(
                destinataire: widget.destinataires[i],
                ouvert: _ouverts.contains(i),
                enCours: _enCours.contains(i),
                echec: _echecs[i],
                onEnvoyer: () => _envoyer(i),
                onMessageSeul: () => _messageSeul(i),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(reste == 0 ? 'Terminé' : 'Plus tard',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinataireTile extends StatelessWidget {
  final DestinataireRecu destinataire;
  final bool ouvert;
  final bool enCours;
  final String? echec;
  final VoidCallback onEnvoyer;
  final VoidCallback onMessageSeul;

  const _DestinataireTile({
    required this.destinataire,
    required this.ouvert,
    required this.enCours,
    required this.echec,
    required this.onEnvoyer,
    required this.onMessageSeul,
  });

  @override
  Widget build(BuildContext context) {
    // Le numéro manquant n'interdit pas le geste : il prévient seulement que
    // le contact restera à désigner dans WhatsApp.
    final sansNumero = destinataire.telephone == null ||
        destinataire.telephone!.trim().isEmpty;

    final (sousTitre, couleur) = switch ((echec, enCours)) {
      (final String motif, _) => (motif, AppColors.error),
      (null, true) => ('Préparation du reçu PDF…', AppColors.hint),
      _ when sansNumero => (
          '${destinataire.resume} · numéro absent de sa fiche',
          AppColors.warning
        ),
      _ => (destinataire.resume, AppColors.hint),
    };

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ouvert
              ? AppColors.success.withValues(alpha: 0.12)
              : echec != null
                  ? AppColors.error.withValues(alpha: 0.10)
                  : AppColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: Icon(
            ouvert
                ? Icons.check_rounded
                : echec != null
                    ? Icons.error_outline_rounded
                    : Icons.picture_as_pdf_outlined,
            size: 20,
            color: ouvert
                ? AppColors.success
                : echec != null
                    ? AppColors.error
                    : AppColors.primaryDark),
      ),
      title: Text(destinataire.nom,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark)),
      subtitle: Text(sousTitre, style: TextStyle(fontSize: 12, color: couleur)),
      trailing: enCours
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : echec != null
              ? TextButton(
                  onPressed: onMessageSeul,
                  child: const Text('Message seul',
                      style: TextStyle(fontSize: 12.5)))
              : ouvert
                  ? TextButton(
                      onPressed: onEnvoyer,
                      child: const Text('Renvoyer',
                          style:
                              TextStyle(fontSize: 12.5, color: AppColors.label)))
                  : const Icon(Icons.chevron_right_rounded,
                      color: AppColors.hint),
      onTap: enCours ? null : onEnvoyer,
    );
  }
}
