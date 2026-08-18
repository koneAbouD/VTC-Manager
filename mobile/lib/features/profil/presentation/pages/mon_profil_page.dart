import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/profil_api.dart';
import '../providers/profil_providers.dart';

/// Consultation et modification de la fiche du compte connecté.
///
/// Les informations viennent du référentiel d'identité (Keycloak) et non d'une
/// table de l'application : l'écran lit `/v1/utilisateurs/moi`, une route
/// cadrée sur le jeton — personne n'y voit la fiche d'un autre.
///
/// L'identifiant de connexion est présenté mais verrouillé : il sert de clé au
/// code d'accès du téléphone, le changer couperait la reprise de session.
class MonProfilPage extends ConsumerStatefulWidget {
  const MonProfilPage({super.key});

  @override
  ConsumerState<MonProfilPage> createState() => _MonProfilPageState();
}

class _MonProfilPageState extends ConsumerState<MonProfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  /// Fiche déjà versée dans les champs : sans ce repère, chaque reconstruction
  /// écraserait la saisie en cours.
  String? _chargeePour;

  bool _busy = false;
  String? _erreur;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  void _remplir(ProfilUtilisateur profil) {
    if (_chargeePour == profil.id) return;
    _chargeePour = profil.id;
    _prenomCtrl.text = profil.prenom;
    _nomCtrl.text = profil.nom;
    _emailCtrl.text = profil.email;
    _telCtrl.text = profil.telephone;
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      await ref.read(profilApiProvider).modifier(
            prenom: _prenomCtrl.text.trim(),
            nom: _nomCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            telephone: _telCtrl.text.trim(),
          );
      if (!mounted) return;
      // Le bandeau des réglages lit la même fiche : il se rafraîchit seul.
      ref.invalidate(monProfilProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations enregistrées.'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(monProfilProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Mes informations',
        action: profil.hasValue
            ? AppHeaderAction(
                label: 'Enregistrer',
                loading: _busy,
                onTap: _busy ? null : _enregistrer,
              )
            : null,
      ),
      body: profil.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Indisponible(
          message: '$e',
          onReessayer: () => ref.invalidate(monProfilProvider),
        ),
        data: (fiche) {
          _remplir(fiche);
          return _formulaire(fiche);
        },
      ),
    );
  }

  Widget _formulaire(ProfilUtilisateur fiche) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          _Entete(fiche: fiche),
          const SizedBox(height: 20),
          const _TitreSection('Identité'),
          TextFormField(
            controller: _prenomCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _deco('Prénom'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Prénom obligatoire' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nomCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _deco('Nom'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Nom obligatoire' : null,
          ),
          const SizedBox(height: 20),
          const _TitreSection('Contact'),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _deco('Adresse e-mail',
                aide: 'Sert aussi à la réinitialisation du mot de passe'),
            validator: (v) {
              final valeur = (v ?? '').trim();
              if (valeur.isEmpty) return 'Adresse e-mail obligatoire';
              // Contrôle volontairement large : le serveur tranche, l'écran
              // n'écarte que ce qui n'a manifestement pas la forme d'un e-mail.
              final formeValide =
                  RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(valeur);
              return formeValide ? null : 'Adresse e-mail invalide';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telCtrl,
            keyboardType: TextInputType.phone,
            decoration: _deco('Téléphone', aide: 'Facultatif'),
            validator: (v) {
              final valeur = (v ?? '').trim();
              if (valeur.isEmpty) return null;
              final formeValide =
                  RegExp(r'^\+?[0-9\s\-]{6,20}$').hasMatch(valeur);
              return formeValide ? null : 'Numéro de téléphone invalide';
            },
          ),
          const SizedBox(height: 20),
          const _TitreSection('Compte'),
          _LigneVerrouillee(
            icone: Icons.badge_outlined,
            libelle: 'Identifiant de connexion',
            valeur: fiche.identifiant,
            aide: 'Non modifiable : c\'est la clé de votre session',
          ),
          if (fiche.rolesMetier.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LigneVerrouillee(
              icone: Icons.verified_user_outlined,
              libelle: fiche.rolesMetier.length > 1 ? 'Rôles' : 'Rôle',
              valeur: fiche.rolesMetier.map(_libelleRole).join(' · '),
              aide: 'Attribué par l\'administrateur',
            ),
          ],
          if (_erreur != null) ...[
            const SizedBox(height: 16),
            Text(
              _erreur!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _deco(String label, {String? aide}) => InputDecoration(
        labelText: label,
        helperText: aide,
        helperMaxLines: 2,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}

/// « GESTIONNAIRE » → « Gestionnaire » : les rôles Keycloak crient, pas l'écran.
String _libelleRole(String role) {
  final propre = role.replaceAll('_', ' ').toLowerCase();
  return propre.isEmpty
      ? propre
      : propre[0].toUpperCase() + propre.substring(1);
}

/// Récapitulatif en tête de page : initiale, nom présenté et identifiant —
/// le même langage visuel que le bandeau des réglages.
class _Entete extends StatelessWidget {
  final ProfilUtilisateur fiche;

  const _Entete({required this.fiche});

  @override
  Widget build(BuildContext context) {
    final identite = composerIdentite(
      prenom: fiche.prenom,
      nom: fiche.nom,
      identifiant: fiche.identifiant,
      email: fiche.email,
    );
    final libelle =
        identite.nomComplet.isEmpty ? 'Mon compte' : identite.nomComplet;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              libelle.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                if (identite.identifiant.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    identite.identifiant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Information affichée mais non modifiable : même gabarit qu'un champ, sans
/// le clavier — la page reste lisible d'un seul balayage.
class _LigneVerrouillee extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String valeur;
  final String aide;

  const _LigneVerrouillee({
    required this.icone,
    required this.libelle,
    required this.valeur,
    required this.aide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: AppColors.hint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.hint),
                ),
                const SizedBox(height: 2),
                Text(
                  valeur.isEmpty ? '—' : valeur,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  aide,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: AppColors.label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String texte;

  const _TitreSection(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texte.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.label,
        ),
      ),
    );
  }
}

/// Fiche illisible (réseau, session) : on le dit et on propose de réessayer,
/// plutôt que de laisser un formulaire vide qui ferait croire à une fiche vide.
class _Indisponible extends StatelessWidget {
  final String message;
  final VoidCallback onReessayer;

  const _Indisponible({required this.message, required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined,
                size: 40, color: AppColors.hint),
            const SizedBox(height: 12),
            const Text(
              'Informations indisponibles',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.label,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
