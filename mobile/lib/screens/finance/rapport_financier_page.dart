import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/widgets/app_header.dart';

// ── Modèles ──────────────────────────────────────────────────────────────────

class BreakdownItem {
  final String label;
  final double montant;
  final double pourcentage;
  const BreakdownItem(
      {required this.label, required this.montant, required this.pourcentage});

  factory BreakdownItem.fromJson(Map<String, dynamic> j) => BreakdownItem(
        label: j['label'] ?? '',
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        pourcentage: (j['pourcentage'] as num?)?.toDouble() ?? 0,
      );
}

class OperationLigne {
  final int id;
  final String type;
  final String? description;
  final String? chauffeurNom;
  final String? vehiculeLabel;
  final double montant;
  final String date;
  const OperationLigne(
      {required this.id,
      required this.type,
      this.description,
      this.chauffeurNom,
      this.vehiculeLabel,
      required this.montant,
      required this.date});

  factory OperationLigne.fromJson(Map<String, dynamic> j) => OperationLigne(
        id: j['id'] ?? 0,
        type: j['type'] ?? '',
        description: j['description'],
        chauffeurNom: j['chauffeurNom'],
        vehiculeLabel: j['vehiculeLabel'],
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        date: j['date'] ?? '',
      );
}

class RapportFinancierData {
  final double totalRevenus;
  final double totalDepenses;
  final double variationRevenusPct;
  final double variationDepensesPct;
  final String groupBy;
  final List<BreakdownItem> breakdownRevenus;
  final List<BreakdownItem> breakdownDepenses;
  final List<OperationLigne> listeOperations;

  const RapportFinancierData({
    required this.totalRevenus,
    required this.totalDepenses,
    required this.variationRevenusPct,
    required this.variationDepensesPct,
    required this.groupBy,
    required this.breakdownRevenus,
    required this.breakdownDepenses,
    required this.listeOperations,
  });

  factory RapportFinancierData.fromJson(Map<String, dynamic> j) =>
      RapportFinancierData(
        totalRevenus: (j['totalRevenus'] as num?)?.toDouble() ?? 0,
        totalDepenses: (j['totalDepenses'] as num?)?.toDouble() ?? 0,
        variationRevenusPct:
            (j['variationRevenusPct'] as num?)?.toDouble() ?? 0,
        variationDepensesPct:
            (j['variationDepensesPct'] as num?)?.toDouble() ?? 0,
        groupBy: j['groupBy'] ?? 'CHAUFFEUR',
        breakdownRevenus: (j['breakdownRevenus'] as List? ?? [])
            .map((e) => BreakdownItem.fromJson(e))
            .toList(),
        breakdownDepenses: (j['breakdownDepenses'] as List? ?? [])
            .map((e) => BreakdownItem.fromJson(e))
            .toList(),
        listeOperations: (j['listeOperations'] as List? ?? [])
            .map((e) => OperationLigne.fromJson(e))
            .toList(),
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _secureStorageProvider = Provider<SecureStorage>((_) => const SecureStorage());
final _apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_secureStorageProvider)));

final rapportFinancierProvider = FutureProvider.family<RapportFinancierData,
    ({int mois, int annee, String groupBy})>((ref, params) async {
  final client = ref.watch(_apiClientProvider);
  final data = await client.get(
      '/rapport-financier?mois=${params.mois}&annee=${params.annee}&groupBy=${params.groupBy}');
  return RapportFinancierData.fromJson(data);
});

// ── Page ─────────────────────────────────────────────────────────────────────

class RapportFinancierPage extends ConsumerStatefulWidget {
  const RapportFinancierPage({super.key});

  @override
  ConsumerState<RapportFinancierPage> createState() =>
      _RapportFinancierPageState();
}

class _RapportFinancierPageState extends ConsumerState<RapportFinancierPage> {
  int _mois = DateTime.now().month;
  int _annee = DateTime.now().year;
  String _groupBy = 'CHAUFFEUR';
  bool _showRevenus = true;

  final _money =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final params = (mois: _mois, annee: _annee, groupBy: _groupBy);
    final asyncData = ref.watch(rapportFinancierProvider(params));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const AppHeader(title: 'Rapport financier'),
      body: Column(
        children: [
          _buildFilters(),
          _buildToggle(),
          Expanded(
            child: asyncData.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Erreur : $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                    TextButton(
                        onPressed: () =>
                            ref.invalidate(rapportFinancierProvider(params)),
                        child: const Text('Réessayer')),
                  ],
                ),
              ),
              data: (rapport) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(rapportFinancierProvider(params)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildTotalCard(rapport),
                    const SizedBox(height: 16),
                    if (_showRevenus) _buildBarChart(rapport),
                    if (!_showRevenus) _buildPieChart(rapport),
                    const SizedBox(height: 24),
                    _buildListeOperations(rapport),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final moisLabel = DateFormat('MMMM yyyy', 'fr_FR')
        .format(DateTime(_annee, _mois))
        .toUpperCase();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Mois picker
          Expanded(
            child: InkWell(
              onTap: _pickMois,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(moisLabel,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // GroupBy (revenus seulement)
          if (_showRevenus)
            InkWell(
              onTap: _toggleGroupBy,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        _groupBy == 'CHAUFFEUR'
                            ? 'Par chauffeur'
                            : 'Par véhicule',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showRevenus = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        _showRevenus ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: _showRevenus
                        ? [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4)
                          ]
                        : [],
                  ),
                  child: Text('Revenus',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _showRevenus
                              ? Colors.black87
                              : Colors.grey)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showRevenus = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        !_showRevenus ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: !_showRevenus
                        ? [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4)
                          ]
                        : [],
                  ),
                  child: Text('Dépenses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: !_showRevenus
                              ? Colors.black87
                              : Colors.grey)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(RapportFinancierData rapport) {
    final montant =
        _showRevenus ? rapport.totalRevenus : rapport.totalDepenses;
    final variation = _showRevenus
        ? rapport.variationRevenusPct
        : rapport.variationDepensesPct;
    final label = _showRevenus ? 'Montant Total' : 'Dépenses Totales';
    final isPositive = variation >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${(montant.abs() / 1000).toStringAsFixed(0)} ',
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text('XOF',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${variation.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(RapportFinancierData rapport) {
    final items = rapport.breakdownRevenus;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: Text('Aucune donnée',
                style: TextStyle(color: Colors.grey))),
      );
    }
    final maxMontant =
        items.map((e) => e.montant).reduce((a, b) => a > b ? a : b);
    final barColors = [
      Colors.blue.shade400,
      Colors.indigo.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.cyan.shade400,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répartition',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final ratio = maxMontant > 0 ? item.montant / maxMontant : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _money.format(item.montant),
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: 120 * ratio.clamp(0.05, 1.0),
                          decoration: BoxDecoration(
                            color: barColors[i % barColors.length],
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label.split(' ').first,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(RapportFinancierData rapport) {
    final items = rapport.breakdownDepenses;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: Text('Aucune donnée',
                style: TextStyle(color: Colors.grey))),
      );
    }
    final pieColors = [
      Colors.purple.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.blue.shade400,
      Colors.red.shade400,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répartition par catégorie',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: items.take(5).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final color = pieColors[i % pieColors.length];
              return SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 5),
                      ),
                      child: Center(
                        child: Text(
                          '${item.pourcentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.label,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListeOperations(RapportFinancierData rapport) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Liste des opérations',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton(
              onPressed: () {},
              child: const Text('Tout afficher',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...rapport.listeOperations
            .where((op) => _showRevenus
                ? op.type == 'REVENU'
                : op.type == 'DEPENSE')
            .take(10)
            .map((op) => _OperationTile(op: op, money: _money)),
      ],
    );
  }

  void _pickMois() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_annee, _mois),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        _mois = picked.month;
        _annee = picked.year;
      });
    }
  }

  void _toggleGroupBy() {
    setState(() =>
        _groupBy = _groupBy == 'CHAUFFEUR' ? 'VEHICULE' : 'CHAUFFEUR');
  }
}

class _OperationTile extends StatelessWidget {
  final OperationLigne op;
  final NumberFormat money;
  const _OperationTile({required this.op, required this.money});

  @override
  Widget build(BuildContext context) {
    final isRevenu = op.type == 'REVENU';
    final color = isRevenu ? Colors.green : Colors.red;
    final montantLabel =
        '${isRevenu ? '+' : ''}${money.format(op.montant.abs())}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isRevenu
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: color,
                size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.description ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (op.chauffeurNom != null)
                  Text('Chauffeur: ${op.chauffeurNom}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                Text(
                    'Oper. ${op.date}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(montantLabel,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
