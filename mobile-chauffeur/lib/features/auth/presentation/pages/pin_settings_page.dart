import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../providers/auth_controller.dart';
import 'pin_setup_page.dart';

/// Réglages du code d'accès : activation et changement.
///
/// Le code ne se désactive pas : il est l'unique moyen de rouvrir l'application
/// entre deux connexions complètes.
class PinSettingsPage extends ConsumerStatefulWidget {
  const PinSettingsPage({super.key});

  @override
  ConsumerState<PinSettingsPage> createState() => _PinSettingsPageState();
}

class _PinSettingsPageState extends ConsumerState<PinSettingsPage> {
  bool? _configured;

  /// Modalité biométrique de l'appareil, `null` s'il n'en propose aucune : la
  /// ligne n'apparaît alors pas du tout.
  BiometricAvailability? _biometrie;
  bool _biometrieActive = false;
  bool _biometrieOccupee = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final notifier = ref.read(authControllerProvider.notifier);
    final configured = await notifier.isPinConfigured();
    final dispo = await notifier.biometricAvailability();
    final active = await notifier.isBiometricsEnabled();
    if (!mounted) return;

    setState(() {
      _configured = configured;
      // Un appareil sans capteur ne mérite pas une ligne grisée : on n'en
      // parle pas. Le matériel présent mais non enrôlé, si — c'est un geste à
      // faire dans les réglages du téléphone.
      _biometrie = dispo.disponible || dispo.raison != null ? dispo : null;
      _biometrieActive = active;
    });
  }

  Future<void> _basculerBiometrie(bool active) async {
    setState(() => _biometrieOccupee = true);
    final notifier = ref.read(authControllerProvider.notifier);

    String? erreur;
    if (active) {
      erreur = await notifier.enableBiometrics();
    } else {
      await notifier.disableBiometrics();
    }

    if (!mounted) return;
    setState(() {
      _biometrieOccupee = false;
      _biometrieActive = active && erreur == null;
    });

    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreur), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _openSetup({bool requireCurrentCode = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PinSetupPage(
          requireCurrentCode: requireCurrentCode,
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final configured = _configured;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(titre: 'Code d\'accès'),
            Expanded(
              child: configured == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Le code TMK à ${PinService.codeLength} chiffres '
                            'vous évite de redemander un code par SMS à chaque '
                            'ouverture. Il reste sur cet appareil et protège '
                            'votre session : sans lui, rien n\'est lisible.',
                            style:
                                TextStyle(color: AppColors.dark, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!configured)
                          ListTile(
                            leading: const Icon(Icons.lock_outline_rounded,
                                color: AppColors.primary),
                            title: const Text('Activer le code d\'accès'),
                            onTap: () => _openSetup(),
                          )
                        else
                          ListTile(
                            leading: const Icon(Icons.password_rounded,
                                color: AppColors.primary),
                            title: const Text('Changer le code'),
                            onTap: () => _openSetup(requireCurrentCode: true),
                          ),
                        // Le déverrouillage biométrique complète le code, il
                        // ne le remplace pas : sans code configuré, il n'y a
                        // rien à ouvrir.
                        if (configured && _biometrie != null) ...[
                          const Divider(height: 32),
                          _LigneBiometrie(
                            availability: _biometrie!,
                            active: _biometrieActive,
                            occupee: _biometrieOccupee,
                            onChanged: _basculerBiometrie,
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur du déverrouillage biométrique, nommé d'après ce que
/// l'appareil sait faire (Face ID, empreinte digitale…).
class _LigneBiometrie extends StatelessWidget {
  final BiometricAvailability availability;
  final bool active;
  final bool occupee;
  final ValueChanged<bool> onChanged;

  const _LigneBiometrie({
    required this.availability,
    required this.active,
    required this.occupee,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final utilisable = availability.disponible && !occupee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: active,
          onChanged: utilisable ? onChanged : null,
          activeTrackColor: AppColors.primary,
          secondary: Icon(
            availability.icone,
            color: utilisable ? AppColors.primary : AppColors.label,
          ),
          title: Text(_capitaliser(availability.libelle)),
          subtitle: Text(
            availability.disponible
                ? 'Ouvrir l\'application sans saisir le code'
                : availability.raison!,
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
        ),
        if (occupee)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  static String _capitaliser(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}
