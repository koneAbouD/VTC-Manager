import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_header.dart';
import 'condition_travail_models.dart';
import 'condition_travail_wizard_page.dart';
import 'condition_travail_liste_page.dart' show conditionsTravailListeProvider;

// ── Constantes ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF43A047);
const _kDark = Color(0xFF1A1A2E);
const _kBg = Color(0xFFF4F6FB);

// ── Page ──────────────────────────────────────────────────────────────────────

class ConditionTravailDetailPage extends ConsumerStatefulWidget {
  final ConditionTravailLocal condition;

  const ConditionTravailDetailPage({super.key, required this.condition});

  @override
  ConsumerState<ConditionTravailDetailPage> createState() =>
      _ConditionTravailDetailPageState();
}

class _ConditionTravailDetailPageState
    extends ConsumerState<ConditionTravailDetailPage> {
  late ConditionTravailLocal _condition;

  @override
  void initState() {
    super.initState();
    _condition = widget.condition;
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<ConditionTravailLocal>(
      context,
      MaterialPageRoute(
        builder: (_) => ConditionTravailWizardPage(initialCondition: _condition),
      ),
    );
    if (result != null) {
      setState(() => _condition = result);
      ref.invalidate(conditionsTravailListeProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: _condition.nom,
              action: AppHeaderAction(
                icon: Icons.edit_rounded,
                onTap: _openEdit,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProgrammeBanner(condition: _condition),
                    const SizedBox(height: 16),
                    _SectionCard(
                      icon: Icons.schedule_rounded,
                      title: 'Programme de travail',
                      children: [
                        _InfoRow(
                          label: 'Type',
                          value: _condition.typeProgramme == 'JOURNALIER'
                              ? 'Journalier'
                              : 'Hebdomadaire',
                        ),
                        _InfoRow(
                          label: 'Horaires',
                          value:
                              '${_condition.heureDebut} – ${_condition.heureFin}',
                        ),
                        _InfoRow(
                          label: 'Chauffeurs',
                          value:
                              '${_condition.nbChauffeurs} chauffeur${_condition.nbChauffeurs > 1 ? 's' : ''}',
                        ),
                        if (_condition.nbChauffeurs == 2) ...[
                          _InfoRow(
                            label: 'Mode alternance',
                            value: _condition.modeAlternance == 'AUTOMATIQUE'
                                ? 'Automatique'
                                : 'Manuelle',
                          ),
                          if (_condition.modeAlternance == 'AUTOMATIQUE')
                            _InfoRow(
                              label: 'Jours alternance',
                              value: '${_condition.joursAlternance} jour(s)',
                            ),
                        ],
                        if (_condition.jourSalaire.isNotEmpty)
                          _InfoRow(
                            label: 'Jour de salaire',
                            value: _labelJour(_condition.jourSalaire),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.payments_rounded,
                      title: 'Recettes & versements',
                      children: [
                        _InfoRow(
                          label: 'Type recette',
                          value: _condition.typeRecette == 'MONTANT_FIXE'
                              ? 'Montant fixe'
                              : 'Montant réel',
                        ),
                        _InfoRow(
                          label: 'Objectif journalier',
                          value:
                              '${_condition.objectifRecette.toStringAsFixed(0)} XOF',
                        ),
                        if (_condition.montantJourSalaire != null)
                          _InfoRow(
                            label: 'Montant jour salaire',
                            value:
                                '${_condition.montantJourSalaire!.toStringAsFixed(0)} XOF',
                          ),
                        if (_condition.modeEncaissement != null)
                          _InfoRow(
                            label: 'Mode encaissement',
                            value: _labelEncaissement(
                                _condition.modeEncaissement!),
                          ),
                        if (_condition.frequenceVersement != null)
                          _InfoRow(
                            label: 'Fréquence versement',
                            value: _labelFrequence(
                                _condition.frequenceVersement!),
                          ),
                        if (_condition.jourVersement != null)
                          _InfoRow(
                            label: 'Jour versement',
                            value: _labelJour(_condition.jourVersement!),
                          ),
                        _InfoRow(
                          label: 'Heure versement',
                          value: _condition.heureVersement,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CotisationsSection(cotisations: _condition.cotisations),
                    const SizedBox(height: 12),
                    _PenalitesSection(penalites: _condition.penalites),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bannière programme ────────────────────────────────────────────────────────

class _ProgrammeBanner extends StatelessWidget {
  final ConditionTravailLocal condition;
  const _ProgrammeBanner({required this.condition});

  @override
  Widget build(BuildContext context) {
    final isJournalier = condition.typeProgramme == 'JOURNALIER';
    final accent = isJournalier ? _kPrimary : const Color(0xFF00695C);
    final bg = isJournalier
        ? const Color(0xFFE3F0FF)
        : const Color(0xFFE0F2F1);
    final icon =
        isJournalier ? Icons.wb_sunny_rounded : Icons.date_range_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isJournalier ? 'Programme Journalier' : 'Programme Hebdomadaire',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${condition.nbChauffeurs} chauffeur${condition.nbChauffeurs > 1 ? 's' : ''} · ${condition.heureDebut} – ${condition.heureFin}',
                  style: TextStyle(
                    fontSize: 13,
                    color: accent.withValues(alpha: 0.8),
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

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
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
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _kDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F2F8)),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Ligne d'info ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section cotisations ───────────────────────────────────────────────────────

class _CotisationsSection extends StatelessWidget {
  final List<CotisationLocal> cotisations;
  const _CotisationsSection({required this.cotisations});

  @override
  Widget build(BuildContext context) {
    final total = cotisations.fold<double>(0, (s, c) => s + c.montant);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.savings_rounded,
                      size: 16, color: Color(0xFF43A047)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cotisations',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _kDark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(0)} XOF',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF43A047),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F2F8)),
          if (cotisations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucune cotisation',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ...cotisations.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF43A047),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.nom,
                        style: const TextStyle(
                            fontSize: 13, color: _kDark),
                      ),
                    ),
                    Text(
                      '${c.montant.toStringAsFixed(0)} XOF',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Section pénalités ─────────────────────────────────────────────────────────

class _PenalitesSection extends StatelessWidget {
  final List<PenaliteLocal> penalites;
  const _PenalitesSection({required this.penalites});

  static const _labelsType = {
    'RECETTE_NON_VERSEE': 'Recette non versée',
    'HEURE_FIN_SERVICE_PASSE': 'Heure de fin de service passée',
    'EXCES_VITESSE': 'Excès de vitesse',
  };

  static const _labelsSanction = {
    'AMENDE': 'Amende',
    'MAJORATION': 'Majoration',
    'IMMOBILISATION': 'Immobilisation',
    'BUZZER': 'Buzzer',
  };

  @override
  Widget build(BuildContext context) {
    final groups = PenaliteGroupLocal.fromFlat(penalites);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.gavel_rounded,
                      size: 16, color: Colors.red.shade700),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Pénalités',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _kDark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${penalites.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F2F8)),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucune pénalité configurée',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ...groups.map((g) => _PenaliteGroup(
                  group: g,
                  labelsType: _labelsType,
                  labelsSanction: _labelsSanction,
                )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PenaliteGroup extends StatelessWidget {
  final PenaliteGroupLocal group;
  final Map<String, String> labelsType;
  final Map<String, String> labelsSanction;

  const _PenaliteGroup({
    required this.group,
    required this.labelsType,
    required this.labelsSanction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            labelsType[group.typePenalite] ?? group.typePenalite,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (group.sanctions.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Aucune sanction',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          )
        else
          ...group.sanctions.map(
            (s) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.red.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    labelsSanction[s.typeSanction] ?? s.typeSanction,
                    style: const TextStyle(fontSize: 13, color: _kDark),
                  ),
                  const Spacer(),
                  Text(
                    s.resume,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Divider(height: 1, color: Color(0xFFF0F2F8)),
      ],
    );
  }
}

// ── Helpers labels ────────────────────────────────────────────────────────────

String _labelJour(String j) {
  const m = {
    'LUNDI': 'Lundi',
    'MARDI': 'Mardi',
    'MERCREDI': 'Mercredi',
    'JEUDI': 'Jeudi',
    'VENDREDI': 'Vendredi',
    'SAMEDI': 'Samedi',
    'DIMANCHE': 'Dimanche',
  };
  return m[j] ?? j;
}

String _labelEncaissement(String e) {
  const m = {
    'MOBILE_MONEY': 'Mobile Money',
    'ESPECES': 'Espèces',
    'VIREMENT': 'Virement',
  };
  return m[e] ?? e;
}

String _labelFrequence(String f) {
  const m = {
    'JOURNALIER': 'Journalier',
    'HEBDOMADAIRE': 'Hebdomadaire',
  };
  return m[f] ?? f;
}
