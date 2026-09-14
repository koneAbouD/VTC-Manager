import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/whatsapp.dart';

/// Un destinataire et le reçu déjà rédigé pour lui.
class DestinataireRecu {
  final String nom;

  /// Numéro de sa fiche. Nul : WhatsApp s'ouvrira sur son sélecteur de
  /// contacts, à charge pour le guichetier de désigner le chauffeur.
  final String? telephone;

  /// Ce que le reçu couvre, en une ligne — « 3 journées · 45 000 XOF ».
  final String resume;

  final String message;

  const DestinataireRecu({
    required this.nom,
    this.telephone,
    required this.resume,
    required this.message,
  });
}

/// Feuille d'envoi des reçus d'un encaissement de masse.
///
/// WhatsApp n'ouvre qu'une conversation à la fois : un lot qui touche
/// plusieurs chauffeurs se solde donc par autant d'allers-retours, et la
/// feuille est ce qui les rend tenables — elle retient qui a déjà été servi
/// pour que le guichetier reprenne où il s'est arrêté.
///
/// La coche dit « WhatsApp a été ouvert », jamais « le message est parti » :
/// rien ne revient de WhatsApp le confirmer.
Future<void> showEnvoiRecusSheet(
  BuildContext context, {
  required List<DestinataireRecu> destinataires,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EnvoiRecusSheet(destinataires: destinataires),
  );
}

class _EnvoiRecusSheet extends StatefulWidget {
  final List<DestinataireRecu> destinataires;

  const _EnvoiRecusSheet({required this.destinataires});

  @override
  State<_EnvoiRecusSheet> createState() => _EnvoiRecusSheetState();
}

class _EnvoiRecusSheetState extends State<_EnvoiRecusSheet> {
  final Set<int> _ouverts = {};

  Future<void> _envoyer(int index) async {
    final destinataire = widget.destinataires[index];
    try {
      await ouvrirWhatsApp(
          telephone: destinataire.telephone, message: destinataire.message);
      if (!mounted) return;
      setState(() => _ouverts.add(index));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("WhatsApp n'a pas pu être ouvert sur cet appareil."),
          backgroundColor: AppColors.error));
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
          Text(
            reste == 0
                ? 'Tous les reçus ont été ouverts dans WhatsApp.'
                : 'WhatsApp s\'ouvre sur chaque chauffeur, le message déjà '
                    'rédigé. C\'est vous qui appuyez sur envoyer.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
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
                onTap: () => _envoyer(i),
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
  final VoidCallback onTap;

  const _DestinataireTile({
    required this.destinataire,
    required this.ouvert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Le numéro manquant n'interdit pas le geste : il prévient seulement que
    // le contact restera à désigner dans WhatsApp.
    final sansNumero = destinataire.telephone == null ||
        destinataire.telephone!.trim().isEmpty;

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ouvert
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: Icon(ouvert ? Icons.check_rounded : Icons.send_outlined,
            size: 20,
            color: ouvert ? AppColors.success : AppColors.primaryDark),
      ),
      title: Text(destinataire.nom,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark)),
      subtitle: Text(
        sansNumero
            ? '${destinataire.resume} · numéro absent de sa fiche'
            : destinataire.resume,
        style: TextStyle(
            fontSize: 12,
            color: sansNumero ? AppColors.warning : AppColors.hint),
      ),
      trailing: ouvert
          ? TextButton(
              onPressed: onTap,
              child: const Text('Renvoyer',
                  style: TextStyle(fontSize: 12.5, color: AppColors.label)))
          : const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
      onTap: onTap,
    );
  }
}
