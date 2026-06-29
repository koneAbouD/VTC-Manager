import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/domain/enums/chauffeur_status.dart';
import '../../../condition_travail/presentation/pages/condition_travail_selector_page.dart';
import '../../../condition_travail/presentation/providers/condition_travail_by_vehicule_provider.dart';
import '../../../condition_travail/presentation/providers/programme_travail_provider.dart';
import '../../../chauffeur/presentation/pages/chauffeur_selector_page.dart';
import '../../../indisponibilite/presentation/providers/indisponibilite_provider.dart';

// ── Toast helpers ──────────────────────────────────────────────────────────────
enum _ToastType { success, error, warning, info }

void _appToast(BuildContext context, String message,
    {_ToastType type = _ToastType.success, Duration? duration}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (AppColors.success, Icons.check_circle_outline_rounded),
    _ToastType.error   => (AppColors.error, Icons.error_outline_rounded),
    _ToastType.warning => (AppColors.warning, Icons.warning_amber_rounded),
    _ToastType.info    => (AppColors.info, Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ?? (type == _ToastType.error || type == _ToastType.warning
          ? const Duration(seconds: 4) : const Duration(seconds: 2)),
    ));
}

// ── Providers locaux ──────────────────────────────────────────────────────────

final _cfgVehSecureStorage =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _cfgVehApiClient = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_cfgVehSecureStorage)));

// ── Page ──────────────────────────────────────────────────────────────────────

class ConfigurationVehiculePage extends ConsumerStatefulWidget {
  final int vehiculeId;
  final String vehiculeLabel;

  const ConfigurationVehiculePage({
    required this.vehiculeId,
    this.vehiculeLabel = '',
    super.key,
  });

  @override
  ConsumerState<ConfigurationVehiculePage> createState() =>
      _ConfigurationVehiculePageState();
}

class _ConfigurationVehiculePageState
    extends ConsumerState<ConfigurationVehiculePage> {
  ConditionTravailLocal? _conditionTravail;
  Chauffeur? _chauffeur1;
  DateTime? _dateService1;
  Chauffeur? _chauffeur2;
  DateTime? _dateService2;
  bool _loading = false;
  bool _prefilled = false;

  bool get _deuxChauffeurs =>
      _conditionTravail != null && _conditionTravail!.nbChauffeurs >= 2;

  void _invertChauffeurs() {
    setState(() {
      final tempChauffeur = _chauffeur1;
      final tempDate = _dateService1;
      _chauffeur1 = _chauffeur2;
      _dateService1 = _dateService2;
      _chauffeur2 = tempChauffeur;
      _dateService2 = tempDate;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPrefill());
  }

  // Pré-remplit les champs depuis la configuration existante du véhicule.
  void _tryPrefill() {
    if (!mounted) return;

    ref
        .read(conditionTravailByVehiculeIdProvider(widget.vehiculeId))
        .whenData((condition) {
      if (condition != null && mounted && _conditionTravail == null) {
        setState(() => _conditionTravail = condition);
      }
    });

    ref
        .read(programmeTravailByVehiculeIdProvider(widget.vehiculeId))
        .whenData((programme) {
      if (mounted && programme.chauffeurs.isNotEmpty && !_prefilled) {
        final sorted = [...programme.chauffeurs]
          ..sort((a, b) => a.ordreAlternance.compareTo(b.ordreAlternance));
        setState(() {
          _prefilled = true;
          _chauffeur1 = sorted.isNotEmpty ? sorted[0].chauffeur : null;
          _dateService1 = sorted.isNotEmpty ? sorted[0].dateService : null;
          _chauffeur2 = sorted.length > 1 ? sorted[1].chauffeur : null;
          _dateService2 = sorted.length > 1 ? sorted[1].dateService : null;
        });
      }
    });
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickConditionTravail() async {
    final result = await Navigator.push<ConditionTravailLocal>(
      context,
      MaterialPageRoute(builder: (_) => const ConditionTravailSelectorPage()),
    );
    if (result != null) {
      setState(() {
        _conditionTravail = result;
        // Réinitialise les chauffeurs si la condition change (nbChauffeurs peut différer)
        _chauffeur1 = null;
        _dateService1 = null;
        _chauffeur2 = null;
        _dateService2 = null;
      });
    }
  }

  Future<void> _pickDate(
      DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(DateTime.now().year + 5),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<Chauffeur?> _pickChauffeur() => Navigator.push<Chauffeur>(
        context,
        MaterialPageRoute(
          builder: (_) => ChauffeurSelectorPage(
            // Non affectables à la configuration : suspendus et chauffeurs en congé.
            nonSelectionnables: const {
              ChauffeurStatus.suspendu,
              ChauffeurStatus.enConge,
            },
            // Un chauffeur déjà actif sur un autre véhicule n'est pas sélectionnable
            // (l'immatriculation de ce véhicule est affichée).
            bloquerDejaAffectes: true,
            vehiculeAutoriseId: widget.vehiculeId,
          ),
        ),
      );

  String? _validate() {
    if (_conditionTravail == null) {
      return 'Veuillez sélectionner une condition de travail.';
    }
    if (_deuxChauffeurs) {
      final missing = <String>[];
      if (_chauffeur1 == null) missing.add('Chauffeur 1');
      if (_chauffeur2 == null) missing.add('Chauffeur 2');
      if (missing.isNotEmpty) {
        if (missing.length == 1) {
          return 'Veuillez sélectionner le ${missing.first} pour cette condition de travail (2 chauffeurs requis).';
        }
        return 'Veuillez sélectionner ${missing.join(' et ')} pour cette condition de travail (2 chauffeurs requis).';
      }
      if (_chauffeur1!.id == _chauffeur2!.id) {
        return 'Le Chauffeur 1 et le Chauffeur 2 doivent être différents.';
      }
      if (_dateService1 == null && _dateService2 == null) {
        return 'Veuillez renseigner la date de prise de service pour les deux chauffeurs.';
      }
      if (_dateService1 == null) {
        return 'Veuillez renseigner la date de prise de service du Chauffeur 1.';
      }
      if (_dateService2 == null) {
        return 'Veuillez renseigner la date de prise de service du Chauffeur 2.';
      }
    } else {
      if (_chauffeur1 == null) {
        return 'Veuillez sélectionner le chauffeur affecté à ce véhicule.';
      }
      if (_dateService1 == null) {
        return 'Veuillez renseigner la date de prise de service du chauffeur.';
      }
    }
    return null;
  }

  void _showError(String message) =>
      _appToast(context, message, type: _ToastType.error);

  List<Map<String, dynamic>> _buildChauffeursList() {
    final chauffeurs = <Map<String, dynamic>>[];
    if (_chauffeur1 != null && _chauffeur1!.id != null) {
      chauffeurs.add({
        'chauffeurId': _chauffeur1!.id,
        if (_dateService1 != null) 'dateService': _isoDate(_dateService1!),
      });
    }
    if (_deuxChauffeurs && _chauffeur2 != null && _chauffeur2!.id != null) {
      chauffeurs.add({
        'chauffeurId': _chauffeur2!.id,
        if (_dateService2 != null) 'dateService': _isoDate(_dateService2!),
      });
    }
    return chauffeurs;
  }

  _ConflictInfo? _parseChauffeurConflict(Object e) {
    if (e is! ApiException || e.statusCode != 409) return null;
    if (e.body?['error'] != 'CHAUFFEUR_ALREADY_ASSIGNED') return null;
    final details = (e.body?['details'] as List?)?.cast<String>() ?? [];
    String? nom;
    String? immat;
    for (final d in details) {
      if (d.startsWith('chauffeurNom:')) nom = d.substring('chauffeurNom:'.length);
      if (d.startsWith('vehiculeActuelImmatriculation:')) {
        immat = d.substring('vehiculeActuelImmatriculation:'.length);
      }
    }
    if (nom == null || immat == null) return null;
    return _ConflictInfo(nom, immat);
  }

  Future<void> _showConflictDialog(_ConflictInfo conflict) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off_outlined,
                  color: Colors.red.shade700, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Chauffeur déjà affecté',
                  style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.6),
            children: [
              const TextSpan(text: 'Le chauffeur '),
              TextSpan(
                text: conflict.chauffeurNom,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' est déjà affecté au véhicule '),
              TextSpan(
                text: conflict.vehiculeImmatriculation,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    '.\n\nVeuillez d\'abord le retirer de ce véhicule avant de l\'assigner ici.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  /// Demande confirmation si des chauffeurs retirés du programme par cette
  /// reconfiguration ont des indisponibilités en cours/planifiées (elles seront
  /// clôturées ou annulées côté serveur). Renvoie false si l'utilisateur annule.
  Future<bool> _confirmerImpactIndisponibilites() async {
    try {
      final ancien = ref
          .read(programmeTravailByVehiculeIdProvider(widget.vehiculeId))
          .valueOrNull;
      if (ancien == null) return true;

      final nouveauxIds = <int>{
        if (_chauffeur1?.id != null) _chauffeur1!.id!,
        if (_deuxChauffeurs && _chauffeur2?.id != null) _chauffeur2!.id!,
      };
      final retires = ancien.chauffeurs
          .map((c) => c.chauffeurId)
          .where((id) => !nouveauxIds.contains(id))
          .toSet();
      if (retires.isEmpty) return true;

      final indispos = await ref.read(toutesIndisponibilitesProvider.future);
      final concernees = indispos
          .where((i) =>
              retires.contains(i.chauffeurId) &&
              (i.statut == 'EN_COURS' || i.statut == 'PLANIFIEE'))
          .toList();
      if (concernees.isEmpty) return true;

      if (!mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Indisponibilités impactées'),
          content: Text(
            '${concernees.length} indisponibilité(s) de chauffeur(s) retiré(s) de '
            'ce véhicule seront clôturées (en cours) ou annulées (planifiées). '
            'Continuer ?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      return ok ?? false;
    } catch (_) {
      // En cas d'échec d'analyse, on laisse passer (le backend gère le nettoyage).
      return true;
    }
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    // Avertir si la reconfiguration retire des chauffeurs ayant des
    // indisponibilités en cours/planifiées (qui seront clôturées/annulées).
    if (!await _confirmerImpactIndisponibilites()) return;

    setState(() => _loading = true);
    try {
      final client = ref.read(_cfgVehApiClient);

      await client.put('/vehicules/${widget.vehiculeId}', {
        'conditionTravailId': _conditionTravail!.id,
      });
      ref.invalidate(conditionTravailByVehiculeIdProvider(widget.vehiculeId));

      await client.post(
        '/vehicules/${widget.vehiculeId}/programme',
        {'chauffeurs': _buildChauffeursList()},
      );
      ref.invalidate(programmeTravailByVehiculeIdProvider(widget.vehiculeId));

      if (!mounted) return;
      _appToast(context, 'Véhicule configuré avec succès.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final conflict = _parseChauffeurConflict(e);
      if (conflict != null) {
        await _showConflictDialog(conflict);
      } else if (e.body?['error'] == 'CHAUFFEUR_SUSPENDU' ||
          e.body?['error'] == 'CHAUFFEUR_PERMIS_EXPIRE') {
        // Message backend déjà explicite (suspension datée / permis expiré).
        _showError(e.message);
      } else {
        _showError(_humanizeBackendError(e.toString()));
      }
      return;
    } catch (e) {
      if (mounted) _showError(_humanizeBackendError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanizeBackendError(String raw) {
    final lower = raw.toLowerCase();

    if (lower.contains('exactement 2 chauffeurs')) {
      final missing = <String>[];
      if (_chauffeur1 == null) missing.add('Chauffeur 1');
      if (_chauffeur2 == null) missing.add('Chauffeur 2');
      if (missing.isEmpty) {
        return 'Cette condition de travail exige 2 chauffeurs. Vérifiez votre sélection.';
      }
      if (missing.length == 1) {
        return 'Le ${missing.first} est manquant : cette condition de travail nécessite 2 chauffeurs.';
      }
      return 'Les deux chauffeurs (Chauffeur 1 et Chauffeur 2) sont requis pour cette condition de travail.';
    }
    if (lower.contains('dépasse le maximum')) {
      return 'Trop de chauffeurs sélectionnés pour cette condition de travail.';
    }
    if (lower.contains('chauffeurs actifs')) {
      return 'Un des chauffeurs sélectionnés n\'est pas actif. Veuillez en choisir un autre.';
    }
    if (lower.contains('chauffeur_already_assigned') ||
        lower.contains('déjà affecté')) {
      return 'Ce chauffeur est déjà affecté à un autre véhicule. Retirez-le d\'abord de son véhicule actuel.';
    }
    if (lower.contains('une seule fois') || lower.contains('distinct')) {
      return 'Le Chauffeur 1 et le Chauffeur 2 doivent être différents.';
    }
    if (lower.contains('jour de travail') ||
        lower.contains('jours d\'alternance')) {
      return 'Aucun jour de travail n\'est défini pour cette condition de travail. Mettez à jour la condition de travail (jours d\'alternance) avant de configurer les chauffeurs.';
    }
    if (lower.contains('heure de fin') || lower.contains('heure de début')) {
      return 'Les horaires de la condition de travail sont incohérents. Corrigez la condition de travail avant de continuer.';
    }
    if (lower.contains('date de prise de service') ||
        lower.contains('dateservice')) {
      return 'La date de prise de service est obligatoire pour chaque chauffeur sélectionné.';
    }
    if (lower.contains('condition de travail')) {
      return 'Le véhicule doit être lié à une condition de travail avant la configuration.';
    }
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
    if (match != null) return match.group(1)!;
    return 'Une erreur est survenue lors de la configuration. Veuillez réessayer.';
  }

  @override
  Widget build(BuildContext context) {
    // Écoute les chargements asynchrones pour pré-remplir si les données
    // n'étaient pas encore disponibles au moment de initState.
    ref.listen<AsyncValue<ConditionTravailLocal?>>(
      conditionTravailByVehiculeIdProvider(widget.vehiculeId),
      (_, next) => next.whenData((condition) {
        if (condition != null && mounted && _conditionTravail == null) {
          setState(() => _conditionTravail = condition);
        }
      }),
    );
    ref.listen<AsyncValue<dynamic>>(
      programmeTravailByVehiculeIdProvider(widget.vehiculeId),
      (_, next) => next.whenData((programme) {
        if (mounted && programme.chauffeurs.isNotEmpty && !_prefilled) {
          final sorted = [...programme.chauffeurs]
            ..sort((a, b) => a.ordreAlternance.compareTo(b.ordreAlternance));
          setState(() {
            _prefilled = true;
            _chauffeur1 = sorted.isNotEmpty ? sorted[0].chauffeur : null;
            _dateService1 = sorted.isNotEmpty ? sorted[0].dateService : null;
            _chauffeur2 = sorted.length > 1 ? sorted[1].chauffeur : null;
            _dateService2 = sorted.length > 1 ? sorted[1].dateService : null;
          });
        }
      }),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Configuration du véhicule'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // ── En-tête ────────────────────────────────────────────
                  if (widget.vehiculeLabel.isNotEmpty) ...[
                    Text(
                      widget.vehiculeLabel,
                      style:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Condition de travail (carte unifiée : placeholder ou résumé) ──
                  const _SectionLabel(
                    label: 'Condition de travail',
                    icon: Icons.work_outline,
                  ),
                  const SizedBox(height: 10),
                  _ConditionTravailCard(
                    condition: _conditionTravail,
                    onTap: _pickConditionTravail,
                    onClear: _conditionTravail != null
                        ? () => setState(() {
                              _conditionTravail = null;
                              _chauffeur1 = null;
                              _dateService1 = null;
                              _chauffeur2 = null;
                              _dateService2 = null;
                            })
                        : null,
                  ),

                  // ── Chauffeurs (visibles si condition sélectionnée) ───────────
                  if (_conditionTravail != null) ...[
                    const SizedBox(height: 28),

                    // ── Chauffeur 1 ────────────────────────────────────
                    _SectionLabel(
                      label: _deuxChauffeurs ? 'Chauffeur 1' : 'Chauffeur',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 10),
                    _ChauffeurTile(
                      chauffeur: _chauffeur1,
                      onTap: () async {
                        final c = await _pickChauffeur();
                        if (c != null) setState(() => _chauffeur1 = c);
                      },
                      onClear: _chauffeur1 != null
                          ? () => setState(() {
                                _chauffeur1 = null;
                                _dateService1 = null;
                              })
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _DateTile(
                      value: _dateService1,
                      label: 'Date de prise de service *',
                      formatter: _formatDate,
                      onTap: () => _pickDate(
                        _dateService1,
                        (d) => setState(() => _dateService1 = d),
                      ),
                      onClear: _dateService1 != null
                          ? () => setState(() => _dateService1 = null)
                          : null,
                    ),

                    // ── Chauffeur 2 (si nbChauffeurs >= 2) ────────────
                    if (_deuxChauffeurs) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel(
                        label: 'Chauffeur 2',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 10),
                      _ChauffeurTile(
                        chauffeur: _chauffeur2,
                        onTap: () async {
                          final c = await _pickChauffeur();
                          if (c != null) setState(() => _chauffeur2 = c);
                        },
                        onClear: _chauffeur2 != null
                            ? () => setState(() {
                                  _chauffeur2 = null;
                                  _dateService2 = null;
                                })
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _DateTile(
                        value: _dateService2,
                        label: 'Date de prise de service *',
                        formatter: _formatDate,
                        onTap: () => _pickDate(
                          _dateService2,
                          (d) => setState(() => _dateService2 = d),
                        ),
                        onClear: _dateService2 != null
                            ? () => setState(() => _dateService2 = null)
                            : null,
                      ),

                      // ── Bouton Inverser (visible si les 2 chauffeurs sont sélectionnés) ──
                      if (_chauffeur1 != null && _chauffeur2 != null) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _invertChauffeurs,
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text(
                                'Inverser le programme des chauffeurs'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),

            // ── Boutons bas ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Passer',
                          style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed:
                          (_loading || _conditionTravail == null)
                              ? null
                              : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirmer',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                    ),
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

// ── Données de conflit d'affectation ─────────────────────────────────────────

class _ConflictInfo {
  final String chauffeurNom;
  final String vehiculeImmatriculation;
  const _ConflictInfo(this.chauffeurNom, this.vehiculeImmatriculation);
}

// ── Carte unifiée condition de travail (placeholder + résumé) ─────────────────

class _ConditionTravailCard extends StatelessWidget {
  final ConditionTravailLocal? condition;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _ConditionTravailCard({
    this.condition,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (condition == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.work_outline,
                      size: 18, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Sélectionner une condition de travail',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    final isFixe = condition!.typeRecette == 'MONTANT_FIXE';
    final accent = isFixe ? AppColors.primary : const Color(0xFFE07B00);
    final bg = isFixe ? AppColors.primaryTint : const Color(0xFFFFF3E0);
    final programmeBadge =
        condition!.typeProgramme == 'JOURNALIER' ? 'Journalier' : 'Hebdomadaire';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.work_outline, size: 18, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          condition!.nom,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        Text(
                          'Appuyer pour modifier',
                          style: TextStyle(
                              fontSize: 11,
                              color: accent.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.close,
                            size: 18,
                            color: accent.withValues(alpha: 0.6)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.schedule,
                    label:
                        '${condition!.heureDebut} – ${condition!.heureFin}',
                    accent: accent,
                  ),
                  _InfoChip(
                    icon: Icons.repeat,
                    label: programmeBadge,
                    accent: accent,
                  ),
                  _InfoChip(
                    icon: Icons.people_outline,
                    label:
                        '${condition!.nbChauffeurs} chauffeur${condition!.nbChauffeurs > 1 ? 's' : ''}',
                    accent: accent,
                  ),
                  if (isFixe)
                    _InfoChip(
                      icon: Icons.monetization_on_outlined,
                      label:
                          'Objectif ${condition!.objectifRecette.toStringAsFixed(0)} XOF',
                      accent: accent,
                    )
                  else
                    _InfoChip(
                      icon: Icons.trending_up,
                      label: 'Recette réelle',
                      accent: accent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: accent),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Chauffeur tile ────────────────────────────────────────────────────────────

class _ChauffeurTile extends StatelessWidget {
  final Chauffeur? chauffeur;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _ChauffeurTile({
    required this.chauffeur,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = chauffeur != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : const Color(0xFFE4E7EC),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: selected
                      ? AppColors.primary
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected
                      ? chauffeur!.displayName
                      : 'Sélectionner un chauffeur',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? AppColors.primary
                        : Colors.grey.shade400,
                  ),
                ),
              ),
              if (selected && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade400),
                  ),
                )
              else
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  size: 20,
                  color: selected
                      ? AppColors.primary
                      : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date tile ─────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  final DateTime? value;
  final String label;
  final String Function(DateTime) formatter;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTile({
    required this.value,
    required this.label,
    required this.formatter,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: selected
                    ? AppColors.primary
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected ? formatter(value!) : label,
                  style: TextStyle(
                    fontSize: 15,
                    color:
                        selected ? Colors.black87 : Colors.grey.shade400,
                  ),
                ),
              ),
              if (selected && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
