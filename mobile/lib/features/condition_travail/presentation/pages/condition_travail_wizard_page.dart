import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import 'condition_travail_models.dart';

// ── Toast helpers ──────────────────────────────────────────────────────────────
enum _ToastType { success, error, warning, info }

void _appToast(BuildContext context, String message,
    {_ToastType type = _ToastType.success, Duration? duration}) {
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

// ── Providers ─────────────────────────────────────────────────────────────────

final _wizSecureStorageProvider =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _wizApiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_wizSecureStorageProvider)));

final _sanctionTypesProvider =
    FutureProvider<List<SanctionTypeLocal>>((ref) async {
  final client = ref.watch(_wizApiClientProvider);
  final data = await client.get('/conditions-travail/sanctions/types');
  return (data as List)
      .map((e) => SanctionTypeLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Constantes de design ──────────────────────────────────────────────────────

const _kPrimary = Color(0xFF43A047);
const _kBg = Color(0xFFF4F6FB);
const _kDark = Color(0xFF1A1A2E);

// ── Page principale ───────────────────────────────────────────────────────────

class ConditionTravailWizardPage extends ConsumerStatefulWidget {
  final ConditionTravailLocal? initialCondition;
  const ConditionTravailWizardPage({super.key, this.initialCondition});

  @override
  ConsumerState<ConditionTravailWizardPage> createState() =>
      _ConditionTravailWizardPageState();
}

class _ConditionTravailWizardPageState
    extends ConsumerState<ConditionTravailWizardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── État du formulaire ────────────────────────────────────────────────────

  final _nomCtrl = TextEditingController();
  int _nbChauffeurs = 1;
  String _typeProgramme = 'JOURNALIER';
  TimeOfDay _heureDebut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _heureFin = const TimeOfDay(hour: 20, minute: 0);
  String _modeAlternance = 'AUTOMATIQUE';
  int _joursAlternance = 1;
  DateTime _dateDebutAlternance = DateTime.now();
  bool _jourSalaireActif = false;
  String _jourSalaire = 'DIMANCHE';

  Set<String> _joursSlot1 = {};
  Set<String> _joursSlot2 = {};
  Set<String> _joursPartages = {};
  int _premierAlternanceSlot = 1;

  final _objectifCtrl = TextEditingController();
  final _montantJourCtrl = TextEditingController();
  String _modeEncaissement = 'MOBILE_MONEY';
  String _typeRecette = 'MONTANT_REEL';
  String _frequenceVersement = 'JOURNALIER';
  String _jourVersement = 'DIMANCHE';
  TimeOfDay _heureVersement = const TimeOfDay(hour: 18, minute: 30);

  List<CotisationLocal> _cotisations = [];

  List<PenaliteGroupLocal> _penaliteGroups = [
    PenaliteGroupLocal(typePenalite: 'RECETTE_NON_VERSEE'),
    PenaliteGroupLocal(typePenalite: 'HEURE_FIN_SERVICE_PASSE'),
    PenaliteGroupLocal(typePenalite: 'EXCES_VITESSE'),
  ];
  String _selectedPenaliteType = 'RECETTE_NON_VERSEE';

  bool _loading = false;
  String? _submitError;

  // ── Onglets ───────────────────────────────────────────────────────────────

  static const _tabData = [
    (Icons.info_outline_rounded,    'Infos'),
    (Icons.calendar_today_rounded,  'Programme'),
    (Icons.payments_rounded,        'Recettes'),
    (Icons.savings_rounded,         'Cotisations'),
    (Icons.gavel_rounded,           'Pénalités'),
  ];

  // ── Cycle de vie ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabData.length, vsync: this);
    if (widget.initialCondition != null) _prefill(widget.initialCondition!);
  }

  void _prefill(ConditionTravailLocal c) {
    _nomCtrl.text = c.nom;
    _nbChauffeurs = c.nbChauffeurs;
    _typeProgramme = c.typeProgramme;
    _heureDebut = _parseTime(c.heureDebut);
    _heureFin = _parseTime(c.heureFin);
    _modeAlternance = c.modeAlternance.isEmpty ? 'AUTOMATIQUE' : c.modeAlternance;
    _joursAlternance = c.joursAlternance;
    _jourSalaireActif = c.jourSalaire.isNotEmpty;
    _jourSalaire = c.jourSalaire.isEmpty ? 'DIMANCHE' : c.jourSalaire;
    _objectifCtrl.text = c.objectifRecette.toStringAsFixed(0);
    _montantJourCtrl.text = c.montantJourSalaire?.toStringAsFixed(0) ?? '';
    _modeEncaissement = c.modeEncaissement ?? 'MOBILE_MONEY';
    _typeRecette = c.typeRecette;
    _frequenceVersement = c.frequenceVersement ?? 'JOURNALIER';
    _jourVersement = c.jourVersement ?? 'DIMANCHE';
    _heureVersement = _parseTime(c.heureVersement);
    // Restaurer les jours de travail dans le bon sélecteur selon la config.
    // (Le backend ne stocke que l'union ; le détail par chauffeur en manuel
    //  n'est pas conservé : on remet l'union sur le chauffeur 1.)
    final jours = c.joursTravail.toSet();
    if (c.nbChauffeurs == 1) {
      _joursSlot1 = jours;
    } else if (_modeAlternance == 'AUTOMATIQUE') {
      _joursPartages = jours;
    } else {
      _joursSlot1 = jours;
    }
    _cotisations = List.of(c.cotisations);
    _penaliteGroups = PenaliteGroupLocal.fromFlat(c.penalites).isEmpty
        ? [
            PenaliteGroupLocal(typePenalite: 'RECETTE_NON_VERSEE'),
            PenaliteGroupLocal(typePenalite: 'HEURE_FIN_SERVICE_PASSE'),
            PenaliteGroupLocal(typePenalite: 'EXCES_VITESSE'),
          ]
        : _mergeGroups(PenaliteGroupLocal.fromFlat(c.penalites));
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 0, minute: 0);
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0);
  }

  List<PenaliteGroupLocal> _mergeGroups(List<PenaliteGroupLocal> loaded) {
    return _penaliteGroups.map((def) {
      final found = loaded.where((g) => g.typePenalite == def.typePenalite);
      return found.isNotEmpty ? found.first : def;
    }).toList();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nomCtrl.dispose();
    _objectifCtrl.dispose();
    _montantJourCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(
      TimeOfDay initial, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  // ── Soumission ────────────────────────────────────────────────────────────

  /// Jours de travail du véhicule selon la configuration :
  /// - 1 chauffeur : ses jours ;
  /// - 2 chauffeurs automatique : les jours communs ;
  /// - 2 chauffeurs manuelle : l'union des jours des deux chauffeurs.
  Set<String> _joursTravail() {
    if (_nbChauffeurs == 1) return _joursSlot1;
    if (_modeAlternance == 'AUTOMATIQUE') return _joursPartages;
    return {..._joursSlot1, ..._joursSlot2};
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (_nomCtrl.text.trim().isEmpty) {
      _tabCtrl.animateTo(0);
      _showError('Veuillez saisir un nom pour la condition de travail.');
      return;
    }
    if (_typeRecette == 'MONTANT_FIXE') {
      final montant = double.tryParse(_objectifCtrl.text.trim());
      if (montant == null || montant <= 0) {
        _tabCtrl.animateTo(2);
        _showError("L'objectif de recette est obligatoire pour un montant fixe.");
        return;
      }
    }

    // Modification d'une condition existante : prévenir de l'impact
    // (s'applique à tous les véhicules liés ; certaines indispos peuvent être
    // clôturées/annulées).
    final editId = widget.initialCondition?.id;
    if (editId != null && !await _confirmerImpact(editId)) {
      return;
    }

    setState(() => _loading = true);
    try {
      final client = ref.read(_wizApiClientProvider);
      final body = {
        'nom': _nomCtrl.text.trim(),
        'nbChauffeurs': _nbChauffeurs,
        'typeProgramme': _typeProgramme,
        'heureDebutService': _fmt(_heureDebut),
        'heureFinService': _fmt(_heureFin),
        'modeAlternance': _nbChauffeurs == 2 ? _modeAlternance : null,
        'joursAlternance':
            (_nbChauffeurs == 2 && _modeAlternance == 'AUTOMATIQUE')
                ? _joursAlternance
                : null,
        'dateDebutAlternance':
            (_nbChauffeurs == 2 && _modeAlternance == 'AUTOMATIQUE')
                ? _dateDebutAlternance.toIso8601String().substring(0, 10)
                : null,
        'jourSalaire': _jourSalaireActif ? _jourSalaire : null,
        'joursTravail': _joursTravail().toList(),
        'modeEncaissement': _modeEncaissement,
        'typeRecette': _typeRecette,
        'objectifRecette': double.tryParse(_objectifCtrl.text) ?? 0,
        'frequenceVersement': _frequenceVersement,
        if (_frequenceVersement == 'HEBDOMADAIRE')
          'jourVersement': _jourVersement,
        'heureVersement': _fmt(_heureVersement),
        'montantJourSalaire': double.tryParse(_montantJourCtrl.text) ?? 0,
        'cotisations': _cotisations.map((c) => c.toJson()).toList(),
        'penalites': _penaliteGroups
            .expand((g) => g.toFlat())
            .map((p) => p.toJson())
            .toList(),
      };
      final editId = widget.initialCondition?.id;
      final dynamic response = editId != null
          ? await client.put('/conditions-travail/$editId', body)
          : await client.post('/conditions-travail', body);
      final result =
          ConditionTravailLocal.fromJson(response as Map<String, dynamic>);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        _showError(e is ApiException
            ? e.message
            : 'Une erreur inattendue est survenue.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Prévient de l'impact d'une modification de condition (multi-véhicules +
  /// indisponibilités potentiellement clôturées/annulées). Renvoie false si
  /// l'utilisateur annule.
  Future<bool> _confirmerImpact(int conditionId) async {
    int vehicules = 0;
    int indispos = 0;
    try {
      final client = ref.read(_wizApiClientProvider);
      final data = await client.get('/conditions-travail/$conditionId/impact');
      if (data is Map) {
        vehicules = (data['vehicules'] as num?)?.toInt() ?? 0;
        indispos = (data['indisponibilites'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      return true; // aperçu indisponible → on laisse passer (backend gère)
    }
    // Pas d'impact notable : un seul véhicule, aucune indispo active.
    if (vehicules <= 1 && indispos == 0) return true;
    if (!mounted) return false;

    final lignes = <String>[];
    if (vehicules > 1) {
      lignes.add('Cette condition est utilisée par $vehicules véhicules : '
          'la modification s\'appliquera à tous.');
    }
    if (indispos > 0) {
      lignes.add('$indispos indisponibilité(s) en cours/planifiée(s) '
          'pourraient être clôturées ou annulées.');
    }
    lignes.add('Continuer ?');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Impact de la modification'),
        content: Text(lignes.join('\n\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _showError(String msg) {
    setState(() => _submitError = msg);
    _appToast(context, msg, type: _ToastType.error);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialCondition != null;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: isEdit ? 'Modifier la condition' : 'Nouvelle condition',
            ),
            _buildTabBar(),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppErrorBanner(
                  message: _submitError!,
                  onClose: () => setState(() => _submitError = null),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildTabInfos(),
                  _buildTabProgramme(),
                  _buildTabRecettes(),
                  _buildTabCotisations(),
                  _buildTabPenalites(),
                ],
              ),
            ),
            _buildSubmitBar(isEdit),
          ],
        ),
      ),
    );
  }

  // ── TabBar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (context, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabData.length, (i) {
                    final selected = _tabCtrl.index == i;
                    final (icon, label) = _tabData[i];
                    return GestureDetector(
                      onTap: () => _tabCtrl.animateTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? _kPrimary
                              : const Color(0xFFF0F2F8),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 15,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF8A94A6)),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF8A94A6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF0F2F8)),
            ],
          ),
        );
      },
    );
  }

  // ── Barre de soumission ───────────────────────────────────────────────────

  void _goToNextTab() {
    if (_tabCtrl.index < _tabData.length - 1) {
      _tabCtrl.animateTo(_tabCtrl.index + 1);
    }
  }

  Widget _buildSubmitBar(bool isEdit) {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (context, _) {
        final isLast = _tabCtrl.index == _tabData.length - 1;
        final IconData icon = isLast
            ? (isEdit ? Icons.check_rounded : Icons.add_rounded)
            : Icons.arrow_forward_rounded;
        final String label = isLast
            ? (isEdit ? 'Enregistrer les modifications' : 'Créer la condition')
            : 'Suivant';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F2F8))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed:
                  _loading ? null : (isLast ? _submit : _goToNextTab),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: isLast
                          ? [
                              Icon(icon, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ]
                          : [
                              Text(
                                label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              Icon(icon, size: 18),
                            ],
                    ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tab 0 – Informations
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabInfos() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Identité ──────────────────────────────────────────────────────
        _FormCard(children: [
          const _CardSectionTitle('Nom de la condition', Icons.label_rounded),
          const SizedBox(height: 10),
          _Field(
            controller: _nomCtrl,
            hint: 'Ex: Matin journalier, Nuit alternance…',
          ),
        ]),

        const SizedBox(height: 14),

        // ── Programme ─────────────────────────────────────────────────────
        _FormCard(children: [
          const _CardSectionTitle('Programme de travail', Icons.work_rounded),
          const SizedBox(height: 14),

          const _FieldLabel('Type de programme'),
          const SizedBox(height: 8),
          _PillSelector(
            options: const {
              'JOURNALIER': 'Journalier',
              'HEBDOMADAIRE': 'Hebdomadaire',
            },
            icons: const {
              'JOURNALIER': Icons.wb_sunny_rounded,
              'HEBDOMADAIRE': Icons.date_range_rounded,
            },
            selected: _typeProgramme,
            onSelected: (v) => setState(() => _typeProgramme = v),
          ),

          const SizedBox(height: 16),
          const _FieldLabel('Nombre de chauffeurs'),
          const SizedBox(height: 8),
          _PillSelector(
            options: const {'1': '1 chauffeur', '2': '2 chauffeurs'},
            icons: const {
              '1': Icons.person_rounded,
              '2': Icons.people_rounded,
            },
            selected: _nbChauffeurs.toString(),
            onSelected: (v) =>
                setState(() => _nbChauffeurs = int.parse(v)),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeCard(
                  label: 'Début',
                  icon: Icons.login_rounded,
                  time: _heureDebut,
                  onTap: () => _pickTime(
                      _heureDebut, (t) => setState(() => _heureDebut = t)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeCard(
                  label: 'Fin',
                  icon: Icons.logout_rounded,
                  time: _heureFin,
                  onTap: () => _pickTime(
                      _heureFin, (t) => setState(() => _heureFin = t)),
                ),
              ),
            ],
          ),

          // Alternance (visible si 2 chauffeurs)
          if (_nbChauffeurs == 2) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0F2F8)),
            const SizedBox(height: 12),
            const _FieldLabel("Mode d'alternance"),
            const SizedBox(height: 8),
            _PillSelector(
              options: const {
                'AUTOMATIQUE': 'Automatique',
                'MANUELLE': 'Manuelle',
              },
              selected: _modeAlternance,
              onSelected: (v) => setState(() => _modeAlternance = v),
            ),
            if (_modeAlternance == 'AUTOMATIQUE') ...[
              const SizedBox(height: 16),
              const _FieldLabel("Jours d'alternance"),
              const SizedBox(height: 8),
              _PillSelector(
                options: const {'1': '1 jour', '2': '2 jours', '3': '3 jours'},
                selected: _joursAlternance.toString(),
                onSelected: (v) =>
                    setState(() => _joursAlternance = int.parse(v)),
              ),
              const SizedBox(height: 16),
              const _FieldLabel("Date de début de l'alternance"),
              const SizedBox(height: 8),
              _DateField(
                date: _dateDebutAlternance,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateDebutAlternance,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _dateDebutAlternance = picked);
                  }
                },
              ),
            ],
          ],
        ]),

      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tab 1 – Programme de travail
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabProgramme() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (_nbChauffeurs == 1) ...[
          _FormCard(children: [
            const _CardSectionTitle('Jours de travail', Icons.calendar_month_rounded),
            const SizedBox(height: 6),
            Text('Sélectionnez les jours où le chauffeur travaille.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            _InlineDaySelector(
              selected: _joursSlot1,
              onChanged: (j) => setState(() => _joursSlot1 = j),
            ),
          ]),
        ] else if (_modeAlternance == 'AUTOMATIQUE') ...[
          _FormCard(children: [
            const _CardSectionTitle('Jours communs', Icons.calendar_month_rounded),
            const SizedBox(height: 6),
            Text(
                'Jours de travail partagés par les deux chauffeurs en alternance.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            _InlineDaySelector(
              selected: _joursPartages,
              onChanged: (j) => setState(() => _joursPartages = j),
            ),
          ]),
          const SizedBox(height: 14),
          _FormCard(children: [
            const _CardSectionTitle(
                'Première alternance', Icons.swap_horiz_rounded),
            const SizedBox(height: 6),
            Text('Choisissez quel chauffeur commence la première période.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 14),
            _PillSelector(
              options: const {
                '1': 'Chauffeur 1',
                '2': 'Chauffeur 2',
              },
              selected: _premierAlternanceSlot.toString(),
              onSelected: (v) =>
                  setState(() => _premierAlternanceSlot = int.parse(v)),
            ),
          ]),
        ] else ...[
          // Alternance manuelle : jours séparés
          _FormCard(children: [
            const _CardSectionTitle(
                'Jours – Chauffeur 1', Icons.person_rounded),
            const SizedBox(height: 6),
            Text(
                'Sélectionnez les jours du chauffeur 1. Ne peuvent pas se chevaucher avec le chauffeur 2.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            _InlineDaySelector(
              selected: _joursSlot1,
              disabledDays: _joursSlot2,
              onChanged: (j) => setState(() => _joursSlot1 = j),
            ),
          ]),
          const SizedBox(height: 14),
          _FormCard(children: [
            const _CardSectionTitle(
                'Jours – Chauffeur 2', Icons.person_rounded),
            const SizedBox(height: 6),
            Text(
                'Sélectionnez les jours du chauffeur 2. Ne peuvent pas se chevaucher avec le chauffeur 1.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            _InlineDaySelector(
              selected: _joursSlot2,
              disabledDays: _joursSlot1,
              onChanged: (j) => setState(() => _joursSlot2 = j),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        // ── Jour de salaire ───────────────────────────────────────────────
        _FormCard(children: [
          const _CardSectionTitle('Jour de salaire', Icons.event_rounded),
          const SizedBox(height: 6),
          Text(
            'Jour où les chauffeurs travaillent à leur propre compte.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          _PillSelector(
            options: const {
              'true': 'Activé',
              'false': 'Désactivé',
            },
            selected: _jourSalaireActif.toString(),
            onSelected: (v) =>
                setState(() => _jourSalaireActif = v == 'true'),
          ),
          if (_jourSalaireActif) ...[
            const SizedBox(height: 16),
            const _FieldLabel('Jour concerné'),
            const SizedBox(height: 10),
            _InlineDaySelector(
              selected: {_jourSalaire},
              singleSelect: true,
              onChanged: (s) {
                if (s.isNotEmpty) setState(() => _jourSalaire = s.first);
              },
            ),
          ],
        ]),
        // Rappel config si pas encore rempli
        if (_nbChauffeurs == 1 && _joursSlot1.isEmpty)
          const _HintBanner('Sélectionnez au moins un jour de travail.'),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tab 2 – Recettes
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabRecettes() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Encaissement ──────────────────────────────────────────────────
        _FormCard(children: [
          const _CardSectionTitle("Mode d'encaissement", Icons.account_balance_wallet_rounded),
          const SizedBox(height: 12),
          _PillSelector(
            expand: true,
            options: const {
              'ESPECES': 'Espèces',
              'MOBILE_MONEY': 'Mobile Money',
              'LES_DEUX': 'Les deux',
            },
            icons: const {
              'ESPECES': Icons.payments_rounded,
              'MOBILE_MONEY': Icons.phone_android_rounded,
              'LES_DEUX': Icons.compare_arrows_rounded,
            },
            selected: _modeEncaissement,
            onSelected: (v) => setState(() => _modeEncaissement = v),
          ),
        ]),

        const SizedBox(height: 14),

        // ── Type de recette ───────────────────────────────────────────────
        _FormCard(children: [
          const _CardSectionTitle('Type de recette', Icons.trending_up_rounded),
          const SizedBox(height: 6),
          Text(
            'Montant réel : le chauffeur verse ce qu\'il a encaissé.\nMontant fixe : un objectif précis est défini.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 14),
          _PillSelector(
            options: const {
              'MONTANT_REEL': 'Montant réel',
              'MONTANT_FIXE': 'Montant fixe',
            },
            selected: _typeRecette,
            onSelected: (v) => setState(() {
              _typeRecette = v;
              if (v == 'MONTANT_REEL') _objectifCtrl.clear();
            }),
          ),
          if (_typeRecette == 'MONTANT_FIXE') ...[
            const SizedBox(height: 16),
            const _FieldLabel('Objectif par chauffeur (XOF)', required: true),
            const SizedBox(height: 8),
            _Field(
              controller: _objectifCtrl,
              hint: 'Montant en XOF',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ]),

        const SizedBox(height: 14),

        // ── Versement ─────────────────────────────────────────────────────
        _FormCard(children: [
          const _CardSectionTitle('Versement de recette', Icons.schedule_send_rounded),
          const SizedBox(height: 14),

          const _FieldLabel('Fréquence'),
          const SizedBox(height: 8),
          _PillSelector(
            expand: true,
            options: const {
              'JOURNALIER': 'Journalier',
              'HEBDOMADAIRE': 'Hebdomadaire',
            },
            icons: const {
              'JOURNALIER': Icons.wb_sunny_rounded,
              'HEBDOMADAIRE': Icons.date_range_rounded,
            },
            selected: _frequenceVersement,
            onSelected: (v) => setState(() {
              _frequenceVersement = v;
              if (v == 'JOURNALIER') _jourVersement = 'DIMANCHE';
            }),
          ),

          if (_frequenceVersement == 'HEBDOMADAIRE') ...[
            const SizedBox(height: 16),
            const _FieldLabel('Jour de versement'),
            const SizedBox(height: 10),
            _InlineDaySelector(
              selected: {_jourVersement},
              singleSelect: true,
              onChanged: (s) {
                if (s.isNotEmpty) setState(() => _jourVersement = s.first);
              },
            ),
          ],

          const SizedBox(height: 16),
          const _FieldLabel('Heure limite de versement'),
          const SizedBox(height: 8),
          _TimeCard(
            label: 'Heure limite',
            icon: Icons.access_time_rounded,
            time: _heureVersement,
            onTap: () => _pickTime(
                _heureVersement,
                (t) => setState(() => _heureVersement = t)),
            fullWidth: true,
          ),
        ]),

        if (_jourSalaireActif) ...[
          const SizedBox(height: 14),
          _FormCard(children: [
            const _CardSectionTitle(
                'Jour de salaire', Icons.event_available_rounded),
            const SizedBox(height: 12),
            const _FieldLabel('Recette à verser ce jour-là (XOF)'),
            const SizedBox(height: 8),
            _Field(
              controller: _montantJourCtrl,
              hint: '0 XOF (optionnel)',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ]),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tab 3 – Cotisations
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabCotisations() {
    final isDisabled = _typeRecette != 'MONTANT_FIXE';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (isDisabled)
          _HintBanner(
              'Passez le type de recette en Montant fixe (onglet Recettes) pour configurer les cotisations.',
              color: const Color(0xFFFFF8E1),
              iconColor: Colors.orange.shade700,
              icon: Icons.info_outline_rounded)
        else ...[
          // Résumé
          if (_cotisations.isNotEmpty)
            _FormCard(children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.savings_rounded,
                        color: Color(0xFF43A047), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_cotisations.length} cotisation(s)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _kDark)),
                        Text(
                          'Total : ${_cotisations.fold<double>(0, (s, c) => s + c.montant).toStringAsFixed(0)} XOF',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),

          const SizedBox(height: 14),

          // Liste des cotisations
          for (int i = 0; i < _cotisations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CotisationTile(
                cotisation: _cotisations[i],
                index: i + 1,
                onEdit: () => _showEditCotisationSheet(i),
                onDelete: () => setState(() => _cotisations.removeAt(i)),
              ),
            ),

          // Bouton ajout
          GestureDetector(
            onTap: _showAddCotisationSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.35),
                    width: 1.5,
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFE8F5E9),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_rounded, color: _kPrimary, size: 20),
                  SizedBox(width: 8),
                  Text('Ajouter une cotisation',
                      style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tab 4 – Pénalités
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabPenalites() {
    final gi = _penaliteGroups
        .indexWhere((g) => g.typePenalite == _selectedPenaliteType);
    final group = _penaliteGroups[gi];
    final totalTypes = ref.watch(_sanctionTypesProvider).valueOrNull?.length ?? 0;
    final canAdd = group.sanctions.length < totalTypes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _FormCard(children: [
          const _CardSectionTitle('Type de pénalité', Icons.gavel_rounded),
          const SizedBox(height: 12),
          _PenaliteDropdown(
            groups: _penaliteGroups,
            selected: _selectedPenaliteType,
            onSelected: (v) => setState(() => _selectedPenaliteType = v),
          ),
        ]),

        const SizedBox(height: 14),

        _WizGroupCard(
          group: group,
          canAdd: canAdd,
          objectifRecette: double.tryParse(_objectifCtrl.text) ?? 0,
          heureVersement: _fmt(_heureVersement),
          heureFin: _fmt(_heureFin),
          showMontantAttendu: _typeRecette != 'MONTANT_REEL',
          onAddSanction: () => _showAddSanctionSheet(gi),
          onEditSanction: (si) => _showEditSanctionSheet(gi, si),
          onDeleteSanction: (si) => setState(() {
            final sanctions = [..._penaliteGroups[gi].sanctions]..removeAt(si);
            _penaliteGroups[gi] =
                _penaliteGroups[gi].copyWith(sanctions: sanctions);
          }),
        ),
      ],
    );
  }

  // ── Bottom sheets cotisations ─────────────────────────────────────────────

  void _showAddCotisationSheet() {
    final nomCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom + 16,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter une cotisation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const _FieldLabel('Nom de la cotisation'),
            _Field(controller: nomCtrl, hint: 'Ex: Salaire, Épargne…'),
            const SizedBox(height: 16),
            const _FieldLabel('Montant (XOF)'),
            _Field(
              controller: montantCtrl,
              hint: 'Montant',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            const _AmberCard(text: "Ce montant s'ajoute à l'objectif de recette."),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style: TextStyle(color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final nom = nomCtrl.text.trim();
                    final montant = double.tryParse(montantCtrl.text) ?? 0;
                    if (nom.isEmpty) return;
                    setState(() => _cotisations
                        .add(CotisationLocal(nom: nom, montant: montant)));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Ajouter'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showEditCotisationSheet(int index) {
    final c = _cotisations[index];
    final nomCtrl = TextEditingController(text: c.nom);
    final montantCtrl =
        TextEditingController(text: c.montant.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom + 16,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifier la cotisation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Field(controller: nomCtrl, hint: 'Nom de la cotisation'),
            const SizedBox(height: 12),
            _Field(
              controller: montantCtrl,
              hint: 'Montant (XOF)',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _cotisations[index] = CotisationLocal(
                        id: c.id,
                        nom: nomCtrl.text.trim(),
                        montant: double.tryParse(montantCtrl.text) ?? 0,
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Enregistrer'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddSanctionSheet(int groupIndex) {
    final group = _penaliteGroups[groupIndex];
    final usedTypes = group.sanctions.map((s) => s.typeSanction).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SanctionSheet(
        typePenalite: group.typePenalite,
        usedTypes: usedTypes,
        onAjouter: (p) => setState(() {
          _penaliteGroups[groupIndex] = _penaliteGroups[groupIndex].copyWith(
            sanctions: [..._penaliteGroups[groupIndex].sanctions, p],
          );
        }),
      ),
    );
  }

  void _showEditSanctionSheet(int groupIndex, int sanctionIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SanctionSheet(
        typePenalite: _penaliteGroups[groupIndex].typePenalite,
        initial: _penaliteGroups[groupIndex].sanctions[sanctionIndex],
        onAjouter: (p) => setState(() {
          final sanctions = [..._penaliteGroups[groupIndex].sanctions];
          sanctions[sanctionIndex] = p;
          _penaliteGroups[groupIndex] =
              _penaliteGroups[groupIndex].copyWith(sanctions: sanctions);
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets de formulaire réutilisables
// ══════════════════════════════════════════════════════════════════════════════

/// Carte blanche avec ombre légère, conteneur logique d'un groupe de champs.
class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Titre de section à l'intérieur d'une FormCard.
class _CardSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _CardSectionTitle(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _kPrimary),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: _kDark)),
      ],
    );
  }
}

/// Label de champ de formulaire.
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel(this.label, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500),
          children: required
              ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
              : [],
        ),
      ),
    );
  }
}

/// Sélecteur de pills horizontal. Chaque option est un chip tappable.
class _PillSelector extends StatelessWidget {
  final Map<String, String> options;
  final Map<String, IconData>? icons;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool expand;

  const _PillSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.expand = false,
  });

  Widget _buildPill(String key, String label, bool isSelected) {
    final icon = icons?[key];
    return GestureDetector(
      onTap: () => onSelected(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(22),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: isSelected ? Colors.white : Colors.grey.shade500),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    if (expand) {
      return Row(
        children: entries.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: idx == 0 ? 0 : 6),
              child: _buildPill(entry.key, entry.value, entry.key == selected),
            ),
          );
        }).toList(),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries
          .map((e) => _buildPill(e.key, e.value, e.key == selected))
          .toList(),
    );
  }
}

/// Sélecteur de jours de la semaine inline (7 cercles tappables).
class _InlineDaySelector extends StatelessWidget {
  final Set<String> selected;
  final Set<String> disabledDays;
  final ValueChanged<Set<String>> onChanged;
  final bool singleSelect;

  static const _ordre = [
    'LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE',
  ];
  static const _initiales = {
    'LUNDI': 'L', 'MARDI': 'M', 'MERCREDI': 'Me',
    'JEUDI': 'J', 'VENDREDI': 'V', 'SAMEDI': 'S', 'DIMANCHE': 'D',
  };
  static const _abrev = {
    'LUNDI': 'Lun', 'MARDI': 'Mar', 'MERCREDI': 'Mer',
    'JEUDI': 'Jeu', 'VENDREDI': 'Ven', 'SAMEDI': 'Sam', 'DIMANCHE': 'Dim',
  };

  const _InlineDaySelector({
    required this.selected,
    required this.onChanged,
    this.disabledDays = const {},
    this.singleSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Diamètre adaptatif : 7 pastilles + 6 espaces tiennent toujours
            // dans la largeur disponible (plafonné à 38 px).
            final diameter =
                ((constraints.maxWidth - 6 * 6) / 7).clamp(28.0, 38.0);
            return Row(
              children: _ordre.map((j) {
            final isSelected = selected.contains(j);
            final isDisabled = disabledDays.contains(j);
            return Expanded(
              child: GestureDetector(
              onTap: isDisabled
                  ? null
                  : () {
                      if (singleSelect) {
                        onChanged({j});
                      } else {
                        final next = Set<String>.from(selected);
                        if (isSelected) {
                          next.remove(j);
                        } else {
                          next.add(j);
                        }
                        onChanged(next);
                      }
                    },
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? const Color(0xFFF0F0F0)
                          : isSelected
                              ? _kPrimary
                              : const Color(0xFFF0F2F8),
                      shape: BoxShape.circle,
                      border: isSelected && !isDisabled
                          ? null
                          : Border.all(
                              color: isDisabled
                                  ? Colors.transparent
                                  : const Color(0xFFC8E6C9),
                            ),
                    ),
                    child: Center(
                      child: Text(
                        _initiales[j]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDisabled
                              ? Colors.grey.shade300
                              : isSelected
                                  ? Colors.white
                                  : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _abrev[j]!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDisabled
                          ? Colors.grey.shade300
                          : isSelected
                              ? _kPrimary
                              : Colors.grey.shade400,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              ),
            );
              }).toList(),
            );
          },
        ),
        if (!singleSelect) ...[
        const SizedBox(height: 12),
        // Sélectionner tout
        GestureDetector(
          onTap: () {
            final available =
                _ordre.where((j) => !disabledDays.contains(j)).toSet();
            final allSel = available.every((j) => selected.contains(j));
            onChanged(allSel ? {} : available);
          },
          child: Row(
            children: [
              Icon(
                selected.length == _ordre.length - disabledDays.length &&
                        selected.isNotEmpty
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: _kPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Tous les jours',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        ], // end if (!singleSelect)
      ],
    );
  }
}

/// Sélecteur de type de pénalité sous forme de liste déroulante.
class _PenaliteDropdown extends StatelessWidget {
  final List<PenaliteGroupLocal> groups;
  final String selected;
  final ValueChanged<String> onSelected;

  static const _icons = {
    'RECETTE_NON_VERSEE':      Icons.money_off_rounded,
    'HEURE_FIN_SERVICE_PASSE': Icons.timer_off_rounded,
    'EXCES_VITESSE':           Icons.speed_rounded,
  };

  const _PenaliteDropdown({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kPrimary),
            onChanged: (v) { if (v != null) onSelected(v); },
            selectedItemBuilder: (context) => groups.map((g) {
              final ico = _icons[g.typePenalite] ?? Icons.warning_rounded;
              final nb = g.sanctions.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Row(children: [
                  Icon(ico, size: 18, color: _kPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(g.label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kDark)),
                  ),
                  if (nb > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$nb',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary)),
                    ),
                ]),
              );
            }).toList(),
            items: groups.map((g) {
              final ico = _icons[g.typePenalite] ?? Icons.warning_rounded;
              final nb = g.sanctions.length;
              final isSel = g.typePenalite == selected;
              return DropdownMenuItem<String>(
                value: g.typePenalite,
                child: Row(children: [
                  Icon(ico, size: 18,
                      color: isSel ? _kPrimary : Colors.grey.shade500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(g.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _kDark)),
                  ),
                  if (nb > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$nb',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary)),
                    ),
                ]),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Afficheur d'heure sous forme de chip tappable.
class _TimeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool fullWidth;

  const _TimeCard({
    required this.label,
    required this.icon,
    required this.time,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: _kPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  Text('$h:$m',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kDark)),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
    return child;
  }
}

/// Bannière d'info/avertissement.
class _HintBanner extends StatelessWidget {
  final String message;
  final Color color;
  final Color iconColor;
  final IconData icon;

  const _HintBanner(
    this.message, {
    this.color = const Color(0xFFE8F5E9),
    this.iconColor = _kPrimary,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13, color: iconColor, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Tile d'une cotisation dans la liste.
class _CotisationTile extends StatelessWidget {
  final CotisationLocal cotisation;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CotisationTile({
    required this.cotisation,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF43A047)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cotisation.nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _kDark)),
                Text('${cotisation.montant.toStringAsFixed(0)} XOF',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Colors.grey.shade500, size: 18),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFD32F2F), size: 18),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom sheet sanction
// ══════════════════════════════════════════════════════════════════════════════

// Icônes et descriptions courtes par type de sanction
const _kSanctionIcons = {
  'BUZZER':         Icons.notifications_active_rounded,
  'AMENDE':         Icons.money_off_rounded,
  'MAJORATION':     Icons.trending_up_rounded,
  'IMMOBILISATION': Icons.car_crash_rounded,
};
const _kSanctionDesc = {
  'BUZZER':         'Alarme sonore dans le véhicule',
  'AMENDE':         'Déduction d\'un montant fixe',
  'MAJORATION':     'Augmentation du montant dû',
  'IMMOBILISATION': 'Arrêt forcé du véhicule',
};

class _SanctionSheet extends ConsumerStatefulWidget {
  final String typePenalite;
  final PenaliteLocal? initial;
  final Set<String> usedTypes;
  final ValueChanged<PenaliteLocal> onAjouter;

  const _SanctionSheet({
    required this.typePenalite,
    required this.onAjouter,
    this.initial,
    this.usedTypes = const {},
  });

  @override
  ConsumerState<_SanctionSheet> createState() => _SanctionSheetState();
}

class _SanctionSheetState extends ConsumerState<_SanctionSheet> {
  String? _typeSanction;
  final _valeurCtrl = TextEditingController();
  String? _dureeImmobilisation;

  static const _dureeOptions = {
    '5': '5 min', '10': '10 min', '15': '15 min',
    '30': '30 min', '60': '1 heure',
  };

  @override
  void initState() {
    super.initState();
    _valeurCtrl.addListener(() => setState(() {}));
    final p = widget.initial;
    if (p != null) {
      _typeSanction = p.typeSanction;
      switch (p.typeSanction) {
        case 'BUZZER':
          _valeurCtrl.text = p.dureeSanctionSecondes?.toString() ?? '';
        case 'AMENDE':
        case 'MAJORATION':
          _valeurCtrl.text = p.montant?.toStringAsFixed(0) ?? '';
        case 'IMMOBILISATION':
          _dureeImmobilisation = p.dureeImmobilisationMinutes?.toString();
      }
    }
  }

  @override
  void dispose() {
    _valeurCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncTypes = ref.watch(_sanctionTypesProvider);
    final isEdit = widget.initial != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 24,
      ),
      child: asyncTypes.when(
        loading: () => const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            SizedBox(height: 200, child: Center(child: Text('Erreur : $e'))),
        data: (types) {
          // En mode ajout, on exclut les types déjà utilisés dans le groupe
          final availableTypes = widget.initial != null
              ? types
              : types
                  .where((t) => !widget.usedTypes.contains(t.code))
                  .toList();
          final selectedType =
              types.where((t) => t.code == _typeSanction).firstOrNull;
          final canSubmit = selectedType != null && _isParamFilled(selectedType);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle + header ──────────────────────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.gavel_rounded,
                        color: _kPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isEdit ? 'Modifier la sanction' : 'Nouvelle sanction',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700,
                          color: _kDark),
                    ),
                    Text(
                      'Configurez le type et le paramètre',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ]),
                ]),

                const SizedBox(height: 24),

                // ── Type de sanction ─────────────────────────────────────────
                const _SheetLabel('Type de sanction'),
                const SizedBox(height: 8),
                _SanctionTypeDropdown(
                  types: availableTypes,
                  selected: _typeSanction,
                  onSelected: (code) => setState(() {
                    _typeSanction = code;
                    _valeurCtrl.clear();
                    _dureeImmobilisation = null;
                  }),
                ),

                // ── Paramètre ────────────────────────────────────────────────
                if (selectedType != null) ...[
                  const SizedBox(height: 20),
                  _buildParamSection(selectedType),
                ],

                const SizedBox(height: 28),

                // ── Boutons ──────────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFB0BEC5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: canSubmit ? _submit : null,
                      child: Text(isEdit ? 'Enregistrer' : 'Ajouter',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isParamFilled(SanctionTypeLocal type) {
    switch (type.paramType) {
      case 'DUREE_SECONDES':
      case 'MONTANT':
      case 'TAUX':
        return _valeurCtrl.text.trim().isNotEmpty;
      case 'DUREE_MINUTES':
        return _dureeImmobilisation != null;
      default:
        return true;
    }
  }

  Widget _buildParamSection(SanctionTypeLocal type) {
    switch (type.paramType) {
      case 'DUREE_SECONDES':
        return _ParamSection(
          label: "Durée de l'alarme",
          hint: 'Secondes',
          suffix: 's',
          controller: _valeurCtrl,
        );
      case 'MONTANT':
        return _ParamSection(
          label: 'Montant de l\'amende',
          hint: 'Montant',
          suffix: 'XOF',
          controller: _valeurCtrl,
        );
      case 'TAUX':
        return _ParamSection(
          label: 'Taux de majoration',
          hint: 'Taux',
          suffix: '%',
          controller: _valeurCtrl,
        );
      case 'DUREE_MINUTES':
        return _DureeMinutesSection(
          value: _dureeImmobilisation,
          options: _dureeOptions,
          onChanged: (v) => setState(() => _dureeImmobilisation = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _submit() {
    final type = _typeSanction!;
    PenaliteLocal penalite;
    switch (type) {
      case 'BUZZER':
        penalite = PenaliteLocal(
          id: widget.initial?.id,
          typePenalite: widget.typePenalite,
          typeSanction: type,
          dureeSanctionSecondes: int.tryParse(_valeurCtrl.text) ?? 30,
        );
      case 'AMENDE':
      case 'MAJORATION':
        penalite = PenaliteLocal(
          id: widget.initial?.id,
          typePenalite: widget.typePenalite,
          typeSanction: type,
          montant: double.tryParse(_valeurCtrl.text) ?? 0,
        );
      case 'IMMOBILISATION':
        penalite = PenaliteLocal(
          id: widget.initial?.id,
          typePenalite: widget.typePenalite,
          typeSanction: type,
          dureeImmobilisationMinutes:
              int.tryParse(_dureeImmobilisation ?? '') ?? 5,
        );
      default:
        return;
    }
    widget.onAjouter(penalite);
    Navigator.pop(context);
  }
}

// ── Carte de sélection de type de sanction ─────────────────────────────────

// ── Dropdown type de sanction ─────────────────────────────────────────────────

class _SanctionTypeDropdown extends StatelessWidget {
  final List<SanctionTypeLocal> types;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _SanctionTypeDropdown({
    required this.types,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            hint: Row(children: [
              Icon(Icons.gavel_rounded, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 10),
              Text('Choisir un type',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            ]),
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kPrimary),
            onChanged: (v) { if (v != null) onSelected(v); },
            selectedItemBuilder: (context) => types.map((t) {
              final icon = _kSanctionIcons[t.code] ?? Icons.warning_rounded;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Row(children: [
                  Icon(icon, size: 18, color: _kPrimary),
                  const SizedBox(width: 10),
                  Text(t.label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kDark)),
                ]),
              );
            }).toList(),
            items: types.map((t) {
              final icon = _kSanctionIcons[t.code] ?? Icons.warning_rounded;
              final desc = _kSanctionDesc[t.code] ?? '';
              final isSel = t.code == selected;
              return DropdownMenuItem<String>(
                value: t.code,
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isSel
                          ? _kPrimary.withValues(alpha: 0.12)
                          : const Color(0xFFF0F2F8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18,
                        color: isSel ? _kPrimary : Colors.grey.shade500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _kDark)),
                        if (desc.isNotEmpty)
                          Text(desc,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (isSel)
                    const Icon(Icons.check_rounded, size: 18, color: _kPrimary),
                ]),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Widgets internes au sheet ─────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600));
}

class _ParamSection extends StatelessWidget {
  final String label;
  final String hint;
  final String suffix;
  final TextEditingController controller;

  const _ParamSection({
    required this.label,
    required this.hint,
    required this.suffix,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SheetLabel(label),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400,
              fontWeight: FontWeight.normal),
          suffixText: suffix,
          suffixStyle: TextStyle(
              color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          filled: true,
          fillColor: const Color(0xFFF4F6FB),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ]);
  }
}

class _DureeMinutesSection extends StatelessWidget {
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const _DureeMinutesSection({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SheetLabel("Durée avant arrêt du véhicule"),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.entries.map((e) {
          final isSelected = value == e.key;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _kPrimary : const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(22),
                border: isSelected
                    ? null
                    : Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Text(e.value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color:
                          isSelected ? Colors.white : Colors.grey.shade700)),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      const _AmberCard(
          text: 'Une notification sonore précède l\'arrêt automatique.'),
    ]);
  }
}

// ── Carte groupe pénalité ─────────────────────────────────────────────────────

class _WizGroupCard extends StatelessWidget {
  final PenaliteGroupLocal group;
  final double objectifRecette;
  final String heureVersement;
  final String heureFin;
  final bool showMontantAttendu;
  final bool canAdd;
  final VoidCallback onAddSanction;
  final ValueChanged<int> onEditSanction;
  final ValueChanged<int> onDeleteSanction;

  const _WizGroupCard({
    required this.group,
    required this.canAdd,
    required this.objectifRecette,
    required this.heureVersement,
    required this.heureFin,
    required this.showMontantAttendu,
    required this.onAddSanction,
    required this.onEditSanction,
    required this.onDeleteSanction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WizGroupHeader(group: group),
          if (group.typePenalite == 'RECETTE_NON_VERSEE')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _ContextCard(children: [
                if (showMontantAttendu)
                  _KV('Montant attendu',
                      '${objectifRecette.toStringAsFixed(0)} XOF'),
                _KV('Délai au plus tard', 'Chaque jour à $heureVersement',
                    valueColor: Colors.red),
              ]),
            ),
          if (group.typePenalite == 'HEURE_FIN_SERVICE_PASSE')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _ContextCard(children: [
                _KV('Heure de fin de service', heureFin),
              ]),
            ),
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          if (group.sanctions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text('Aucune sanction — ajoutez-en une ci-dessous.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            )
          else
            for (int i = 0; i < group.sanctions.length; i++)
              _WizSanctionRow(
                penalite: group.sanctions[i],
                onEdit: () => onEditSanction(i),
                onDelete: () => onDeleteSanction(i),
                showDivider: i < group.sanctions.length - 1,
              ),
          if (canAdd) ...[
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          InkWell(
            onTap: onAddSanction,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: _kPrimary, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text('Ajouter une sanction',
                      style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _WizGroupHeader extends StatelessWidget {
  final PenaliteGroupLocal group;

  static const _icons = {
    'RECETTE_NON_VERSEE':      Icons.money_off_rounded,
    'HEURE_FIN_SERVICE_PASSE': Icons.timer_off_rounded,
    'EXCES_VITESSE':           Icons.speed_rounded,
  };

  const _WizGroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final icon = _icons[group.typePenalite] ?? Icons.warning_rounded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: _kPrimary),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Sanctions',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark)),
        ),
      ]),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final List<Widget> children;
  const _ContextCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String key_;
  final String value;
  final Color? valueColor;
  const _KV(this.key_, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key_,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? _kDark)),
      ],
    );
  }
}

class _WizSanctionRow extends StatelessWidget {
  final PenaliteLocal penalite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDivider;

  const _WizSanctionRow({
    required this.penalite,
    required this.onEdit,
    required this.onDelete,
    required this.showDivider,
  });

  static String _label(String code) => switch (code) {
        'BUZZER' => 'Buzzer',
        'AMENDE' => 'Amende',
        'MAJORATION' => 'Majoration',
        'IMMOBILISATION' => 'Immobilisation',
        _ => code,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_label(penalite.typeSanction),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(penalite.resume,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: _kPrimary, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFD32F2F), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, color: Color(0xFFE4E7EC)),
      ],
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final isNumeric = keyboardType == TextInputType.number ||
        keyboardType == TextInputType.phone;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization:
          isNumeric ? TextCapitalization.none : TextCapitalization.sentences,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(fontSize: 15))),
            Icon(Icons.calendar_today_outlined,
                color: Colors.grey.shade500, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AmberCard extends StatelessWidget {
  final String text;
  const _AmberCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 12,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}
