import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../condition_travail/domain/entities/programme_chauffeur.dart';
import '../../../condition_travail/domain/entities/programme_travail.dart';
import '../../../condition_travail/domain/enums/mode_alternance.dart';
import '../../../condition_travail/presentation/pages/condition_travail_models.dart';
import '../../../condition_travail/presentation/providers/condition_travail_by_vehicule_provider.dart';
import '../../../condition_travail/presentation/providers/programme_travail_provider.dart';
import '../../domain/entities/vehicule.dart';
import '../providers/documents_by_vehicule_provider.dart';
import '../providers/vehicule_provider.dart';
import 'vehicule_form_page.dart';
import '../../../configuration_vehicule/presentation/pages/configuration_vehicule_page.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/network_photo_viewer.dart';
import '../../../chauffeur/presentation/pages/chauffeur_detail_page.dart';

enum _ToastType { success, error, warning, info }

void _appToast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.success,
  Duration? duration,
}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
    _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ??
          (type == _ToastType.error || type == _ToastType.warning
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2)),
    ));
}

class VehiculeDetailPage extends ConsumerStatefulWidget {
  final int vehiculeId;
  final int initialTabIndex;
  final bool canPopToChauffeur;
  const VehiculeDetailPage({super.key, required this.vehiculeId, this.initialTabIndex = 0, this.canPopToChauffeur = false});

  @override
  ConsumerState<VehiculeDetailPage> createState() => _VehiculeDetailPageState();
}

class _VehiculeDetailPageState extends ConsumerState<VehiculeDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _openConfigurationFlow(
      BuildContext context, Vehicule vehicule) async {
    if (vehicule.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigurationVehiculePage(
          vehiculeId: vehicule.id!,
          vehiculeLabel:
              '${vehicule.immatriculation} - ${vehicule.displayName}',
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(vehiculeByIdProvider(widget.vehiculeId));
    ref.invalidate(programmeTravailByVehiculeIdProvider(widget.vehiculeId));
    ref.invalidate(conditionTravailByVehiculeIdProvider(widget.vehiculeId));
  }

  @override
  Widget build(BuildContext context) {
    final asyncVehicule = ref.watch(vehiculeByIdProvider(widget.vehiculeId));
    final asyncProgramme =
        ref.watch(programmeTravailByVehiculeIdProvider(widget.vehiculeId));

    ref.listen(vehiculeNotifierProvider, (_, __) {
      ref.invalidate(vehiculeByIdProvider(widget.vehiculeId));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppHeader(
        title: '',
        action: asyncVehicule.valueOrNull == null
            ? null
            : AppHeaderAction(
                label: 'Modifier',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VehiculeFormPage(
                      initial: asyncVehicule.valueOrNull!,
                    ),
                  ),
                ),
              ),
      ),
      body: asyncVehicule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (vehicule) {
          final chauffeurs = asyncProgramme.maybeWhen(
            data: (p) => p.chauffeurs,
            orElse: () => <ProgrammeChauffeur>[],
          );
          return Column(
            children: [
              const SizedBox(height: 12),
              _VehiculeHeroCard(
                vehicule: vehicule,
                chauffeurs: chauffeurs,
                onConfigure: () => _openConfigurationFlow(context, vehicule),
              ),
              const SizedBox(height: 12),
              _PillTabBar(controller: _tab, tabs: const [
                _PillTabItem(label: 'Infos', icon: Icons.info_outline),
                _PillTabItem(label: 'Documents', icon: Icons.folder_outlined),
                _PillTabItem(label: 'Programme', icon: Icons.people_outline),
                _PillTabItem(label: 'Recettes', icon: Icons.payments_outlined),
                _PillTabItem(
                    label: 'Cotisations', icon: Icons.receipt_long_outlined),
                _PillTabItem(label: 'Pénalités', icon: Icons.gavel_outlined),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _InfoGeneralesTab(vehicule: vehicule),
                    _DocumentsTab(vehicule: vehicule),
                    _ChauffeursTab(vehicule: vehicule, canPopToChauffeur: widget.canPopToChauffeur),
                    _RecettesTab(vehicule: vehicule),
                    _CotisationsTab(vehicule: vehicule),
                    _PenalitesTab(vehicule: vehicule),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Tabs alimentés par la condition de travail liée au véhicule ───────────
// (recettes, cotisations, pénalités sont des champs de la condition de travail)

String _formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(0);
}

String _modeEncaissementLabel(String? code) => switch (code) {
      'ESPECES' => 'Espèces',
      'MOBILE_MONEY' => 'Mobile Money',
      'LES_DEUX' => 'Espèces & Mobile Money',
      _ => '—',
    };

String _typeRecetteLabel(String? code) => switch (code) {
      'MONTANT_FIXE' => 'Montant fixe',
      'MONTANT_REEL' => 'Montant réel',
      _ => '—',
    };

String _frequenceLabel(String? code) => switch (code) {
      'JOURNALIER' => 'Journalière',
      'HEBDOMADAIRE' => 'Hebdomadaire',
      _ => '—',
    };

String _jourLabel(String? code) => switch (code) {
      'LUNDI' => 'Lundi',
      'MARDI' => 'Mardi',
      'MERCREDI' => 'Mercredi',
      'JEUDI' => 'Jeudi',
      'VENDREDI' => 'Vendredi',
      'SAMEDI' => 'Samedi',
      'DIMANCHE' => 'Dimanche',
      _ => '—',
    };

String _sanctionLabel(String code) => switch (code) {
      'BUZZER' => 'Buzzer',
      'AMENDE' => 'Amende',
      'MAJORATION' => 'Majoration',
      'IMMOBILISATION' => 'Immobilisation',
      _ => code,
    };

String _typePenaliteLabel(String code) => switch (code) {
      'RECETTE_NON_VERSEE' => 'Recette non versée',
      'HEURE_FIN_SERVICE_PASSE' => 'Heure de fin de service dépassée',
      'EXCES_VITESSE' => 'Excès de vitesse',
      _ => code,
    };

// ── Tab Cotisations ────────────────────────────────────────────────────────

class _CotisationsTab extends ConsumerWidget {
  final Vehicule vehicule;
  const _CotisationsTab({required this.vehicule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculeId = vehicule.id;
    if (vehiculeId == null) {
      return const _NoConditionView(
        icon: Icons.receipt_long_outlined,
        title: 'Véhicule non enregistré',
        description: 'Enregistrez le véhicule pour gérer ses cotisations.',
      );
    }
    final async = ref.watch(conditionTravailByVehiculeIdProvider(vehiculeId));
    void reload() =>
        ref.invalidate(conditionTravailByVehiculeIdProvider(vehiculeId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _NoConditionView(
        icon: Icons.receipt_long_outlined,
        title: 'Cotisations indisponibles',
        description:
            'Impossible de charger les cotisations liées à la condition de travail.',
        errorDetails: e.toString(),
        onReload: reload,
      ),
      data: (condition) {
        if (condition == null) {
          return _NoConditionView(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune condition de travail',
            description:
                'Liez une condition de travail à ce véhicule pour voir ses cotisations.',
            onReload: reload,
          );
        }
        if (condition.cotisations.isEmpty) {
          return _NoConditionView(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune cotisation définie',
            description:
                'La condition de travail « ${condition.nom} » n\'a aucune cotisation.',
            onReload: reload,
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _ConditionTravailBanner(condition: condition),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Cotisations',
              icon: Icons.receipt_long_outlined,
              children: condition.cotisations
                  .map((c) => _InfoRow(
                        label: c.nom,
                        icon: Icons.payments_outlined,
                        value: '${_formatAmount(c.montant)} XOF',
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8E4FF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined,
                      color: Color(0xFF3B5BDB), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Total : ${_formatAmount(condition.totalCotisations)} XOF / versement',
                      style: const TextStyle(
                        color: Color(0xFF3B5BDB),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ── Tab Pénalités ──────────────────────────────────────────────────────────

class _PenalitesTab extends ConsumerWidget {
  final Vehicule vehicule;
  const _PenalitesTab({required this.vehicule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculeId = vehicule.id;
    if (vehiculeId == null) {
      return const _NoConditionView(
        icon: Icons.gavel_outlined,
        title: 'Véhicule non enregistré',
        description: 'Enregistrez le véhicule pour gérer ses pénalités.',
      );
    }
    final async = ref.watch(conditionTravailByVehiculeIdProvider(vehiculeId));
    void reload() =>
        ref.invalidate(conditionTravailByVehiculeIdProvider(vehiculeId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _NoConditionView(
        icon: Icons.gavel_outlined,
        title: 'Pénalités indisponibles',
        description:
            'Impossible de charger les pénalités liées à la condition de travail.',
        errorDetails: e.toString(),
        onReload: reload,
      ),
      data: (condition) {
        if (condition == null) {
          return _NoConditionView(
            icon: Icons.gavel_outlined,
            title: 'Aucune condition de travail',
            description:
                'Liez une condition de travail à ce véhicule pour voir ses pénalités.',
            onReload: reload,
          );
        }
        if (condition.penalites.isEmpty) {
          return _NoConditionView(
            icon: Icons.gavel_outlined,
            title: 'Aucune pénalité définie',
            description:
                'La condition de travail « ${condition.nom} » n\'a aucune pénalité.',
            onReload: reload,
          );
        }
        // Regroupement par typePenalite
        final groups = PenaliteGroupLocal.fromFlat(condition.penalites);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _ConditionTravailBanner(condition: condition),
            const SizedBox(height: 12),
            ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionCard(
                    title: _typePenaliteLabel(g.typePenalite),
                    icon: Icons.gavel_outlined,
                    accent: const Color(0xFFE65100),
                    children: g.sanctions
                        .map((p) => _InfoRow(
                              label: _sanctionLabel(p.typeSanction),
                              icon: Icons.report_outlined,
                              value: p.resume,
                            ))
                        .toList(),
                  ),
                )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

// ── Tab Recettes ───────────────────────────────────────────────────────────

class _RecettesTab extends ConsumerWidget {
  final Vehicule vehicule;
  const _RecettesTab({required this.vehicule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculeId = vehicule.id;
    if (vehiculeId == null) {
      return const _NoConditionView(
        icon: Icons.payments_outlined,
        title: 'Véhicule non enregistré',
        description: 'Enregistrez le véhicule pour configurer ses recettes.',
      );
    }
    final async = ref.watch(conditionTravailByVehiculeIdProvider(vehiculeId));
    void reload() =>
        ref.invalidate(conditionTravailByVehiculeIdProvider(vehiculeId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _NoConditionView(
        icon: Icons.payments_outlined,
        title: 'Recettes indisponibles',
        description: 'Impossible de charger la configuration des recettes.',
        errorDetails: e.toString(),
        onReload: reload,
      ),
      data: (condition) {
        if (condition == null) {
          return _NoConditionView(
            icon: Icons.payments_outlined,
            title: 'Aucune condition de travail',
            description:
                'Liez une condition de travail à ce véhicule pour voir la configuration des recettes.',
            onReload: reload,
          );
        }
        final isFixe = condition.typeRecette == 'MONTANT_FIXE';
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _ConditionTravailBanner(condition: condition),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Détails recettes',
              icon: Icons.payments_outlined,
              children: [
                _InfoRow(
                  label: "Mode d'encaissement",
                  icon: Icons.account_balance_wallet_outlined,
                  value: _modeEncaissementLabel(condition.modeEncaissement),
                ),
                _InfoRow(
                  label: 'Type de recette',
                  icon: Icons.trending_up,
                  value: _typeRecetteLabel(condition.typeRecette),
                ),
                if (isFixe)
                  _InfoRow(
                    label: 'Objectif de recette',
                    icon: Icons.flag_outlined,
                    value: '${_formatAmount(condition.objectifRecette)} XOF',
                  ),
                _InfoRow(
                  label: 'Fréquence de versement',
                  icon: Icons.schedule,
                  value: _frequenceLabel(condition.frequenceVersement),
                ),
                if (condition.frequenceVersement == 'HEBDOMADAIRE')
                  _InfoRow(
                    label: 'Jour de versement',
                    icon: Icons.today_outlined,
                    value: _jourLabel(condition.jourVersement),
                  ),
                _InfoRow(
                  label: 'Heure limite de versement',
                  icon: Icons.access_time,
                  value: condition.heureVersement,
                ),
                if (condition.montantJourSalaire != null)
                  _InfoRow(
                    label: 'Recette jour de salaire',
                    icon: Icons.event_available_outlined,
                    value:
                        '${_formatAmount(condition.montantJourSalaire!)} XOF',
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ── Bannière "condition de travail appliquée" ─────────────────────────────

class _ConditionTravailBanner extends StatelessWidget {
  final ConditionTravailLocal condition;
  const _ConditionTravailBanner({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E4FF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF3B5BDB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.work_outline,
                color: Color(0xFF3B5BDB), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Condition appliquée',
                  style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF3B5BDB).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2),
                ),
                Text(
                  condition.nom,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state unifié ─────────────────────────────────────────────────────

// ── Tab Documents ──────────────────────────────────────────────────────────

class _DocumentsTab extends ConsumerWidget {
  final Vehicule vehicule;
  const _DocumentsTab({required this.vehicule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculeId = vehicule.id;
    if (vehiculeId == null) {
      return const _NoConditionView(
        icon: Icons.folder_open_outlined,
        title: 'Véhicule non enregistré',
        description: 'Enregistrez le véhicule pour gérer ses documents.',
      );
    }

    final async = ref.watch(documentsByVehiculeIdProvider(vehiculeId));
    void reload() => ref.invalidate(documentsByVehiculeIdProvider(vehiculeId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _NoConditionView(
        icon: Icons.folder_open_outlined,
        title: 'Documents indisponibles',
        description: 'Impossible de charger les documents du véhicule.',
        errorDetails: e.toString(),
        onReload: reload,
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return const _NoConditionView(
            icon: Icons.folder_open_outlined,
            title: 'Aucun document',
            description: 'Ce véhicule n\'a pas encore de document enregistré.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _DocumentCard(document: docs[i]),
        );
      },
    );
  }
}

// Détecte si un fichier est une image depuis le type MIME ou l'extension du nom.
bool _docIsImage(DocumentVehiculeLocal doc) {
  final ft = doc.fichierType ?? '';
  if (ft.startsWith('image/')) return true;
  final ext = (doc.fichierNom ?? '').split('.').last.toLowerCase();
  return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
}

bool _docIsPdf(DocumentVehiculeLocal doc) {
  final ft = doc.fichierType ?? '';
  if (ft.contains('pdf')) return true;
  return (doc.fichierNom ?? '').toLowerCase().endsWith('.pdf');
}

class _DocumentCard extends StatelessWidget {
  final DocumentVehiculeLocal document;
  const _DocumentCard({required this.document});

  bool get _isImage => _docIsImage(document);
  bool get _isPdf => _docIsPdf(document);

  Color get _accentColor {
    if (_isImage) return const Color(0xFF3B5BDB);
    if (_isPdf) return const Color(0xFFD32F2F);
    return const Color(0xFF546E7A);
  }

  IconData get _fileIcon {
    if (_isImage) return Icons.image_outlined;
    if (_isPdf) return Icons.picture_as_pdf_outlined;
    return Icons.description_outlined;
  }

  bool get _isExpired =>
      document.dateExpiration != null &&
      document.dateExpiration!.isBefore(DateTime.now());

  bool get _isExpiringSoon {
    if (document.dateExpiration == null || _isExpired) return false;
    return document.dateExpiration!
        .isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isExpired
        ? Colors.red.shade200
        : _isExpiringSoon
            ? Colors.orange.shade200
            : const Color(0xFFE4E9F5);
    final expiryColor = _isExpired
        ? Colors.red.shade400
        : _isExpiringSoon
            ? Colors.orange.shade400
            : Colors.grey.shade500;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.85),
          builder: (_) => _DocumentViewerDialog(document: document),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Panneau gauche coloré
              Container(
                width: 56,
                height: 74,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    bottomLeft: Radius.circular(13),
                  ),
                ),
                child: Icon(_fileIcon, color: _accentColor, size: 26),
              ),
              // Contenu central
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Émis ${_fmtDate(document.dateEmission)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.event_busy_outlined,
                              size: 11, color: expiryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Exp. ${_fmtDate(document.dateExpiration)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: expiryColor,
                              fontWeight: (_isExpired || _isExpiringSoon)
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Viewer document ────────────────────────────────────────────────────────

class _DocumentViewerDialog extends ConsumerStatefulWidget {
  final DocumentVehiculeLocal document;
  const _DocumentViewerDialog({required this.document});

  @override
  ConsumerState<_DocumentViewerDialog> createState() =>
      _DocumentViewerDialogState();
}

class _DocumentViewerDialogState
    extends ConsumerState<_DocumentViewerDialog> {
  late Future<Uint8List> _bytesFuture;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  void _loadBytes() {
    final client = ref.read(docApiClientProvider);
    _bytesFuture =
        client.getBytes('/v1/documents/${widget.document.id}/download');
  }

  void _retry() {
    setState(_loadBytes);
  }

  static bool _isBytesImage(Uint8List b) {
    if (b.length < 4) return false;
    // JPEG: FF D8 FF
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
    // GIF: 47 49 46 38
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true;
    // WebP: RIFF + WEBP at offset 8
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return true;
    }
    // BMP: 42 4D
    if (b[0] == 0x42 && b[1] == 0x4D) return true;
    return false;
  }

  static bool _isBytesPdf(Uint8List b) {
    // %PDF
    return b.length >= 4 &&
        b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46;
  }

  Future<void> _downloadFile() async {
    setState(() => _downloading = true);
    try {
      final client = ref.read(docApiClientProvider);
      final response = await client.get(
        '/v1/documents/${widget.document.id}/presigned-url',
      ) as Map<String, dynamic>;

      final rawUrl = response['url'] as String;
      final uri = Uri.parse(rawUrl);

      if (!await canLaunchUrl(uri)) throw Exception('URL non accessible');
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloading = false);
      _appToast(context, 'Impossible de télécharger le fichier.', type: _ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.document.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // Contenu fichier
              SizedBox(
                height: 380,
                child: FutureBuilder<Uint8List>(
                  future: _bytesFuture,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white54, strokeWidth: 2),
                      );
                    }
                    if (snap.hasError || !snap.hasData) {
                      return _DocViewerError(
                        message: snap.error?.toString(),
                        onRetry: _retry,
                      );
                    }
                    final bytes = snap.data!;
                    final isPdf = _isBytesPdf(bytes) ||
                        _docIsPdf(widget.document);
                    final isImage = !isPdf &&
                        (_isBytesImage(bytes) ||
                            _docIsImage(widget.document));

                    if (!isPdf && !isImage) {
                      return _DocNoPreview(
                        fichierType: widget.document.fichierType,
                        fichierNom: widget.document.fichierNom,
                      );
                    }
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isPdf
                            ? _BytesPdfViewer(bytes: bytes)
                            : InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 5.0,
                                child: Image.memory(
                                  bytes,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const _DocViewerError(),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),

              // Bouton télécharger
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _downloadFile,
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white70),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                        _downloading ? 'Téléchargement…' : 'Télécharger'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.06),
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BytesPdfViewer extends StatefulWidget {
  final Uint8List bytes;
  const _BytesPdfViewer({required this.bytes});

  @override
  State<_BytesPdfViewer> createState() => _BytesPdfViewerState();
}

class _BytesPdfViewerState extends State<_BytesPdfViewer> {
  PdfController? _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final doc = await PdfDocument.openData(widget.bytes);
      if (!mounted) return;
      setState(() {
        _controller = PdfController(document: Future.value(doc));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      );
    }
    if (_error || _controller == null) {
      return const _DocViewerError();
    }
    return PdfView(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      pageSnapping: false,
      backgroundDecoration: const BoxDecoration(
        color: Color(0xFF12122A),
      ),
    );
  }
}

class _DocNoPreview extends StatelessWidget {
  final String? fichierType;
  final String? fichierNom;
  const _DocNoPreview({this.fichierType, this.fichierNom});

  IconData get _icon {
    final ft = fichierType ?? '';
    if (ft.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Prévisualisation non disponible',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          if (fichierNom != null && fichierNom!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                fichierNom!,
                style: const TextStyle(
                    color: Colors.white24, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocViewerError extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const _DocViewerError({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger le fichier',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white24, fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh,
                  color: Colors.white54, size: 16),
              label: const Text('Réessayer',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoConditionView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? errorDetails;
  final VoidCallback? onReload;

  const _NoConditionView({
    required this.icon,
    required this.title,
    required this.description,
    this.errorDetails,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(42),
              ),
              child: Icon(icon, size: 38, color: const Color(0xFF3B5BDB)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            if (errorDetails != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  errorDetails!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFFE65100), height: 1.4),
                ),
              ),
            ],
            if (onReload != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onReload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recharger'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B5BDB),
                  side: const BorderSide(color: Color(0xFF3B5BDB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab Informations générales ─────────────────────────────────────────────

class _InfoGeneralesTab extends StatelessWidget {
  final Vehicule vehicule;
  const _InfoGeneralesTab({required this.vehicule});

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SectionCard(
          title: 'Détails du véhicule',
          icon: Icons.info_outline,
          children: [
            _InfoRow(
                label: "Type d'activité",
                icon: Icons.work_outline,
                value: vehicule.typeActiviteNom),
            _InfoRow(
                label: 'Type de véhicule',
                icon: Icons.category_outlined,
                value: vehicule.typeVehiculeNom),
            _InfoRow(
                label: 'Marque',
                icon: Icons.local_offer_outlined,
                value: vehicule.marque),
            _InfoRow(
                label: 'Modèle',
                icon: Icons.directions_car_filled_outlined,
                value: vehicule.modele),
            _InfoRow(
                label: 'Couleur',
                icon: Icons.palette_outlined,
                value: vehicule.couleur),
            _InfoRow(
                label: 'Immatriculation',
                icon: Icons.confirmation_num_outlined,
                value: vehicule.immatriculation),
            _InfoRow(
                label: 'Groupe',
                icon: Icons.group_work_outlined,
                value: vehicule.groupe),
            _InfoRow(
                label: 'Mise en circulation',
                icon: Icons.calendar_today_outlined,
                value: _fmtDate(vehicule.dateMiseEnCirculation)),
            _InfoRow(
                label: 'Entrée dans la flotte',
                icon: Icons.directions_car_outlined,
                value: _fmtDate(vehicule.dateEntreeFlotte)),
            _InfoRow(
                label: 'N° châssis',
                icon: Icons.numbers_outlined,
                value: vehicule.numeroChassis),
            _InfoRow(
                label: 'Tél. véhicule',
                icon: Icons.phone_outlined,
                value: vehicule.numeroTelephoneVehicule),
            _InfoRow(
                label: 'Tél. balise',
                icon: Icons.gps_fixed_outlined,
                value: vehicule.numeroTelephoneBalise),
            _InfoRow(
                label: 'ID balise GPS',
                icon: Icons.satellite_alt_outlined,
                value: vehicule.identifiantBalise),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Kilométrage',
          icon: Icons.speed,
          onEdit: () {},
          children: [
            _InfoRow(
              label: 'Kilométrage actuel',
              icon: Icons.speed_outlined,
              value: '${vehicule.kilometrage ?? 0} km',
            ),
            const _InfoRow(
              label: 'Kilométrage prochaine vidange',
              icon: Icons.build_outlined,
              value: '0 km',
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: [
                  const Text(
                    "Voir l'historique de kilométrage",
                    style: TextStyle(
                      color: Color(0xFF3B5BDB),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if ((vehicule.photos ?? []).isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Galerie',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      '${vehicule.photos!.length} photo${vehicule.photos!.length > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: vehicule.photos!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final photo = vehicule.photos![i];
                      final urls = vehicule.photos!
                          .map((p) => p.url)
                          .toList();
                      return GestureDetector(
                        onTap: () => showNetworkPhotoViewer(
                          context,
                          urls: urls,
                          initialIndex: i,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            photo.url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade100,
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Tab Chauffeurs & Programme ─────────────────────────────────────────────

class _ChauffeursTab extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  final bool canPopToChauffeur;
  const _ChauffeursTab({required this.vehicule, this.canPopToChauffeur = false});

  @override
  ConsumerState<_ChauffeursTab> createState() => _ChauffeursTabState();
}

class _ChauffeursTabState extends ConsumerState<_ChauffeursTab> {
  static const _weekdayLabels = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];

  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  Vehicule get vehicule => widget.vehicule;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = _dateOnly(now);
  }

  @override
  Widget build(BuildContext context) {
    final vehiculeId = vehicule.id;
    if (vehiculeId == null) {
      return const Center(
        child: Text('Le véhicule doit être enregistré pour gérer son programme.'),
      );
    }

    final asyncProgramme = ref.watch(programmeTravailByVehiculeIdProvider(vehiculeId));

    return asyncProgramme.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyProgrammeView(
        onConfigure: () => _openProgrammeForm(
          context,
          ProgrammeTravail.defaultForVehicule(vehiculeId),
        ),
      ),
      data: (programme) {
        if (programme.id == null) {
          return _EmptyProgrammeView(
            onConfigure: () => _openProgrammeForm(context, programme),
          );
        }

        final calendarDays = _buildCalendarDays(programme, _focusedMonth);
        final selectedSchedule = _selectedDate != null
            ? _scheduleForDate(programme, _selectedDate!)
            : null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // ── Calendrier ──
            Container(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _monthArrow(Icons.chevron_left_rounded, () => _changeMonth(-1)),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy', 'fr_FR').format(_focusedMonth),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      _monthArrow(Icons.chevron_right_rounded, () => _changeMonth(1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _weekdayLabels
                        .map((l) => Expanded(
                              child: Text(
                                l,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: calendarDays.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 1,
                      crossAxisSpacing: 1,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (_, i) => _buildCell(calendarDays[i]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ── Légende ──
            const Row(
              children: [
                _LegendChip(
                  color: Color(0xFFD9E5FF),
                  label: 'Jour de travail',
                ),
                SizedBox(width: 14),
                _LegendChip(
                  color: Color(0xFFCDEDD8),
                  label: 'Jour de salaire',
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Détail du jour sélectionné ──
            selectedSchedule != null
                ? _buildDayCard(selectedSchedule, programme)
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Sélectionnez une date colorée pour voir le programme.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF33415C),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildCell(_ProgrammeCalendarCell day) {
    final schedule = day.schedule;
    final inMonth = day.inMonth;
    final isSelected =
        _selectedDate != null && _isSameDate(_selectedDate!, day.date);
    final isToday = _isSameDate(day.date, DateTime.now());
    final isEnabled = schedule != null && inMonth;

    // Les jours hors du mois sont toujours grisés, quelles que soient leurs données
    final isSalaryDay = inMonth && schedule?.salaryDriver != null;
    final isServiceDay = inMonth && schedule != null;

    final background = isSelected
        ? const Color(0xFF325DBB)
        : !inMonth
            ? const Color(0xFFF0F0F0)
            : isSalaryDay
                ? const Color(0xFFCDEDD8)
                : isServiceDay
                    ? const Color(0xFFD9E5FF)
                    : Colors.white;

    final numberColor = isSelected
        ? Colors.white
        : !inMonth
            ? const Color(0xFFBDBDBD)
            : isServiceDay
                ? const Color(0xFF304160)
                : const Color(0xFF4A5468);

    final initials = (isServiceDay && !isSelected)
        ? _initials(schedule.serviceDriver.nomComplet)
        : null;

    final initialsColor = isSalaryDay
        ? const Color(0xFF2E7D32)
        : const Color(0xFF3158B6);

    return Material(
      color: background,
      child: InkWell(
        onTap: !isEnabled
            ? null
            : () => setState(() => _selectedDate = day.date),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday
                  ? const Color(0xFF8BA4E8)
                  : const Color(0xFFEEEEEE),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: numberColor,
                ),
              ),
              if (initials != null)
                Text(
                  initials,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: initialsColor,
                    height: 1.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(
    _ProgrammeDaySchedule schedule,
    ProgrammeTravail programme,
  ) {
    final isSalaryDay = schedule.salaryDriver != null;
    final rowColor    = isSalaryDay ? const Color(0xFF2E7D32) : const Color(0xFF3158B6);
    final rowBg       = isSalaryDay ? const Color(0xFFE8F5E9) : const Color(0xFFEAF1FF);
    final borderColor = isSalaryDay ? const Color(0xFFC8E6C9) : const Color(0xFFE4E9F5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(schedule.date),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          _DayDetailRow(
            icon: Icons.directions_car_outlined,
            label: 'Au travail',
            name: schedule.serviceDriver.nomComplet,
            detail: _timeRange(programme),
            color: rowColor,
            bg: rowBg,
            onTap: schedule.serviceDriver.chauffeurId > 0
                ? () {
                    if (widget.canPopToChauffeur) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChauffeurDetailPage(
                          chauffeurId: schedule.serviceDriver.chauffeurId,
                          initialTabIndex: 2,
                          canPopToVehicule: true,
                        ),
                      ));
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _monthArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: const Color(0xFF2A3147), size: 24),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  List<_ProgrammeCalendarCell> _buildCalendarDays(
    ProgrammeTravail programme,
    DateTime focusedMonth,
  ) {
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    return List.generate(42, (index) {
      final date = _dateOnly(gridStart.add(Duration(days: index)));
      return _ProgrammeCalendarCell(
        date: date,
        inMonth: date.month == focusedMonth.month,
        schedule: _scheduleForDate(programme, date),
      );
    });
  }

  _ProgrammeDaySchedule? _scheduleForDate(
    ProgrammeTravail programme,
    DateTime date,
  ) {
    if (programme.chauffeurs.isEmpty) return null;
    final current = _dateOnly(date);
    if (!_isWorkingDay(programme, current)) return null;

    final chauffeurs = [...programme.chauffeursTriesAlternance];
    final salaryDrivers = [...programme.chauffeurs]..sort((a, b) {
        final first = a.ordreJourSalaire ?? a.ordreAlternance;
        final second = b.ordreJourSalaire ?? b.ordreAlternance;
        return first.compareTo(second);
      });

    final serviceDriver = _serviceDriverForDate(programme, chauffeurs, current);
    if (serviceDriver == null) return null;

    return _ProgrammeDaySchedule(
      date: current,
      serviceDriver: serviceDriver,
      salaryDriver: _salaryDriverForDate(programme, salaryDrivers, current),
    );
  }

  ProgrammeChauffeur? _serviceDriverForDate(
    ProgrammeTravail programme,
    List<ProgrammeChauffeur> chauffeurs,
    DateTime date,
  ) {
    final current = _dateOnly(date);
    final readyDrivers = chauffeurs
        .where((c) =>
            c.dateService == null ||
            !current.isBefore(_dateOnly(c.dateService!)))
        .toList();

    if (readyDrivers.isEmpty) return null;
    if (readyDrivers.length == 1 ||
        programme.modeAlternance != ModeAlternance.automatique ||
        programme.joursAlternance == null ||
        programme.joursAlternance! < 1) {
      return readyDrivers.first;
    }

    final alternanceStart = _effectiveAlternanceStart(programme, readyDrivers);
    if (alternanceStart.isAfter(current)) return readyDrivers.first;

    final serviceDays =
        _countWorkingDaysInclusive(programme, alternanceStart, current);
    final slot = (serviceDays - 1) ~/ programme.joursAlternance!;
    return readyDrivers[slot % readyDrivers.length];
  }

  ProgrammeChauffeur? _salaryDriverForDate(
    ProgrammeTravail programme,
    List<ProgrammeChauffeur> chauffeurs,
    DateTime date,
  ) {
    if (!programme.jourSalaireActif ||
        programme.jourSalaire == null ||
        chauffeurs.isEmpty ||
        date.weekday != programme.jourSalaire!.weekday) {
      return null;
    }

    final readyDrivers = chauffeurs
        .where((c) =>
            c.dateService == null ||
            !date.isBefore(_dateOnly(c.dateService!)))
        .toList();
    if (readyDrivers.isEmpty) return null;

    int occurrence = 0;
    for (int d = 1; d <= date.day; d++) {
      if (DateTime(date.year, date.month, d).weekday ==
          programme.jourSalaire!.weekday) {
        occurrence++;
      }
    }
    return readyDrivers[(occurrence - 1) % readyDrivers.length];
  }

  bool _isWorkingDay(ProgrammeTravail programme, DateTime date) {
    if (programme.joursAlternanceSemaine.isEmpty) return true;
    return programme.joursAlternanceSemaine
        .any((jour) => jour.weekday == date.weekday);
  }

  int _countWorkingDaysInclusive(
    ProgrammeTravail programme,
    DateTime start,
    DateTime end,
  ) {
    int count = 0;
    var cursor = _dateOnly(start);
    final last = _dateOnly(end);
    while (!cursor.isAfter(last)) {
      if (_isWorkingDay(programme, cursor)) count++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  DateTime _effectiveAlternanceStart(
    ProgrammeTravail programme,
    List<ProgrammeChauffeur> readyDrivers,
  ) {
    DateTime anchor = programme.dateDebutAlternance != null
        ? _dateOnly(programme.dateDebutAlternance!)
        : _dateOnly(
            readyDrivers
                .where((c) => c.dateService != null)
                .map((c) => c.dateService!)
                .fold(DateTime.now(), _earlierDate),
          );
    for (final c in readyDrivers) {
      if (c.dateService != null) {
        anchor = _laterDate(anchor, _dateOnly(c.dateService!));
      }
    }
    return anchor;
  }

  String _timeRange(ProgrammeTravail programme) {
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${fmt(programme.heureDebutService)} - ${fmt(programme.heureFinService)}';
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'CH';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _openProgrammeForm(
    BuildContext context,
    ProgrammeTravail programme,
  ) async {
    if (vehicule.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigurationVehiculePage(
          vehiculeId: vehicule.id!,
          vehiculeLabel:
              '${vehicule.immatriculation} - ${vehicule.displayName}',
        ),
      ),
    );
    ref.invalidate(programmeTravailByVehiculeIdProvider(vehicule.id!));
    ref.invalidate(vehiculeByIdProvider(vehicule.id!));
    ref.invalidate(conditionTravailByVehiculeIdProvider(vehicule.id!));
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime _earlierDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
  DateTime _laterDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}

// ── Widgets calendrier partagés ────────────────────────────────────────────

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _DayDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String name;
  final String detail;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _DayDetailRow({
    required this.icon,
    required this.label,
    required this.name,
    required this.detail,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  detail.isEmpty ? name : '$name  $detail',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: bg,
        child: onTap != null
            ? InkWell(onTap: onTap, child: inner)
            : inner,
      ),
    );
  }
}

// ── Empty programme view ───────────────────────────────────────────────────

class _EmptyProgrammeView extends StatelessWidget {
  final VoidCallback onConfigure;
  const _EmptyProgrammeView({required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Programme de travail',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onConfigure,
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF3B5BDB), size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        const Icon(Icons.event_note_outlined,
            size: 64, color: Color(0xFFBBC4E0)),
        const SizedBox(height: 16),
        const Text(
          'Aucun programme configuré',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configurez le programme de travail de ce véhicule\npour gérer les chauffeurs et le calendrier.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onConfigure,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B5BDB),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Configurer les chauffeurs',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

/// Couleur d'accent + label pour un statut véhicule.
class _StatusVisual {
  final Color color;
  final Color background;
  final IconData icon;
  final String label;
  const _StatusVisual(this.color, this.background, this.icon, this.label);

  static _StatusVisual of(String? statut) => switch (statut) {
        'DISPONIBLE' => const _StatusVisual(Color(0xFF2E7D32),
            Color(0xFFE8F5E9), Icons.check_circle, 'Disponible'),
        'EN_SERVICE' => const _StatusVisual(Color(0xFF1565C0),
            Color(0xFFE3F2FD), Icons.directions_car, 'En service'),
        'EN_MAINTENANCE' => const _StatusVisual(Color(0xFFE65100),
            Color(0xFFFFF3E0), Icons.build_circle, 'En maintenance'),
        'HORS_SERVICE' => const _StatusVisual(
            Color(0xFFC62828), Color(0xFFFFEBEE), Icons.cancel, 'Hors service'),
        _ => const _StatusVisual(
            Colors.grey, Color(0xFFEFEFEF), Icons.help_outline, '—'),
      };
}

class _VehiculeHeroCard extends StatelessWidget {
  final Vehicule vehicule;
  final List<ProgrammeChauffeur> chauffeurs;
  final VoidCallback onConfigure;

  const _VehiculeHeroCard({
    required this.vehicule,
    required this.chauffeurs,
    required this.onConfigure,
  });

  String get _chauffeursLabel {
    if (chauffeurs.isEmpty) return 'Aucun chauffeur';
    if (chauffeurs.length == 1) return chauffeurs.first.nomComplet;
    if (chauffeurs.length == 2) {
      return '${chauffeurs[0].nomComplet} · ${chauffeurs[1].nomComplet}';
    }
    return '${chauffeurs[0].nomComplet} +${chauffeurs.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _StatusVisual.of(vehicule.statut);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6F8FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B5BDB).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B5BDB), Color(0xFF6B8DE3)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicule.immatriculation,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicule.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _StatusBadge(visual: status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.person_outline,
                  label: _chauffeursLabel,
                  accent: chauffeurs.isNotEmpty ? const Color(0xFF3B5BDB) : null,
                ),
              ),
              const SizedBox(width: 10),
              _ConfigureButton(
                onTap: onConfigure,
                isFirstSetup: chauffeurs.isEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusVisual visual;
  const _StatusBadge({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 13, color: visual.color),
          const SizedBox(width: 5),
          Text(
            visual.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: visual.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _StatChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? const Color(0xFF42476B);
    final bg = (accent ?? const Color(0xFF6B7794)).withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigureButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isFirstSetup;

  const _ConfigureButton({required this.onTap, required this.isFirstSetup});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B5BDB), Color(0xFF6B8DE3)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B5BDB).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFirstSetup ? Icons.tune : Icons.edit_outlined,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isFirstSetup ? 'Configurer' : 'Reconfigurer',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillTabItem {
  final String label;
  final IconData icon;
  const _PillTabItem({required this.label, required this.icon});
}

class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final List<_PillTabItem> tabs;
  const _PillTabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9F5)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: const Color(0xFF3B5BDB),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6B7794),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        tabs: tabs
            .map((t) => Tab(
                  height: 36,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 15),
                      const SizedBox(width: 6),
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onEdit;
  final IconData? icon;
  final Color? accent;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.onEdit,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFF3B5BDB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.edit_outlined, color: color, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;

  const _InfoRow({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final hasValue = value?.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              hasValue ? value! : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
                color:
                    hasValue ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeCalendarCell {
  final DateTime date;
  final bool inMonth;
  final _ProgrammeDaySchedule? schedule;

  const _ProgrammeCalendarCell({
    required this.date,
    required this.inMonth,
    required this.schedule,
  });
}

class _ProgrammeDaySchedule {
  final DateTime date;
  final ProgrammeChauffeur serviceDriver;
  final ProgrammeChauffeur? salaryDriver;

  const _ProgrammeDaySchedule({
    required this.date,
    required this.serviceDriver,
    required this.salaryDriver,
  });
}
