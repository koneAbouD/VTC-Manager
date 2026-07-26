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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final configured =
        await ref.read(authControllerProvider.notifier).isPinConfigured();
    if (mounted) setState(() => _configured = configured);
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
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
