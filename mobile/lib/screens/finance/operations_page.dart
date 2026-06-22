import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/recette/presentation/pages/recette_form_page.dart';
import '../../features/depense/presentation/pages/depense_form_page.dart';
import 'rapport_financier_page.dart' show OperationLigne;
import '../../core/widgets/app_header.dart';

// ── Modèles ──────────────────────────────────────────────────────────────────

class OperationsData {
  final double total;
  final int count;
  final int totalCount;
  final List<OperationLigne> operations;
  const OperationsData(
      {required this.total,
      required this.count,
      required this.totalCount,
      required this.operations});

  factory OperationsData.fromJson(Map<String, dynamic> j) => OperationsData(
        total: (j['total'] as num?)?.toDouble() ?? 0,
        count: j['count'] ?? 0,
        totalCount: j['totalCount'] ?? 0,
        operations: (j['operations'] as List? ?? [])
            .map((e) => OperationLigne.fromJson(e))
            .toList(),
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _secureStorageProviderOps =
    Provider<SecureStorage>((_) => const SecureStorage());
final _apiClientProviderOps = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_secureStorageProviderOps)));

final operationsProvider = FutureProvider.family<OperationsData,
    ({String? type, int mois, int annee, int? chauffeurId, int? vehiculeId})>(
  (ref, params) async {
    final client = ref.watch(_apiClientProviderOps);
    final queryParams = <String, String>{
      'mois': params.mois.toString(),
      'annee': params.annee.toString(),
    };
    if (params.type != null) queryParams['type'] = params.type!;
    if (params.chauffeurId != null)
      queryParams['chauffeurId'] = params.chauffeurId.toString();
    if (params.vehiculeId != null)
      queryParams['vehiculeId'] = params.vehiculeId.toString();

    final query = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
    final data = await client.get('/operations?$query');
    return OperationsData.fromJson(data);
  },
);

// ── Page ─────────────────────────────────────────────────────────────────────

class OperationsPage extends ConsumerStatefulWidget {
  const OperationsPage({super.key});

  @override
  ConsumerState<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends ConsumerState<OperationsPage> {
  int _mois = DateTime.now().month;
  int _annee = DateTime.now().year;
  String? _type = 'REVENU';
  int? _chauffeurId;
  int? _vehiculeId;
  final _searchController = TextEditingController();

  final _money =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = (
      type: _type,
      mois: _mois,
      annee: _annee,
      chauffeurId: _chauffeurId,
      vehiculeId: _vehiculeId,
    );
    final asyncData = ref.watch(operationsProvider(params));
    final moisLabel = DateFormat('MMMM', 'fr_FR').format(DateTime(_annee, _mois));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppHeader(
        title: 'Opérations',
        action: AppHeaderAction(onTap: _ajouterOperation, icon: Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Filtres période + total count
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                InkWell(
                  onTap: _pickMois,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text('Filtrer par : ${moisLabel[0].toUpperCase()}${moisLabel.substring(1)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500)),
                        const Icon(Icons.arrow_drop_down,
                            size: 18, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                asyncData.when(
                  data: (d) => Text(
                    'Total : ${d.count} / ${d.totalCount}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Toggle Revenus / Dépenses
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _toggleBtn('Revenus', 'REVENU'),
                  _toggleBtn('Dépenses', 'DEPENSE'),
                ],
              ),
            ),
          ),

          // Mois / Année selectors
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _periodChip(
                    DateFormat('MMMM', 'fr_FR')
                        .format(DateTime(_annee, _mois)),
                    Icons.event_note_outlined),
                const SizedBox(width: 8),
                _periodChip('$_annee', Icons.calendar_view_month_outlined),
              ],
            ),
          ),

          // Search bar + filters btn
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _type == 'REVENU'
                          ? 'Rechercher un revenu'
                          : 'Rechercher une dépense',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Icon(Icons.tune_outlined,
                      color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Body
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
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: () =>
                            ref.invalidate(operationsProvider(params)),
                        child: const Text('Réessayer')),
                  ],
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(operationsProvider(params)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildTotalBanner(data),
                    const SizedBox(height: 12),
                    ...data.operations.map(
                        (op) => _OperationItem(op: op, money: _money)),
                    if (_type == 'REVENU')
                      _buildNoteInfo(
                          'Les opérations de recharge et de retrait ne sont pas prises en compte dans le calcul des montants totaux'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, String value) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4)
                  ]
                : [],
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black87 : Colors.grey)),
        ),
      ),
    );
  }

  Widget _periodChip(String label, IconData icon) {
    return InkWell(
      onTap: _pickMois,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade800)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBanner(OperationsData data) {
    final isRevenu = _type == 'REVENU';
    final color = isRevenu ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.monetization_on_outlined, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(data.total.abs() / 1000).toStringAsFixed(0)} XOF',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: color),
              ),
              Text(
                isRevenu ? 'Total revenu' : 'Total dépense',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInfo(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NB',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            _filterChip('Status', null),
            const SizedBox(height: 8),
            _filterChip('Type de véhicule', null),
            const SizedBox(height: 8),
            _filterChip('Chauffeur', null),
            const SizedBox(height: 8),
            _filterChip('Véhicule', null),
            const SizedBox(height: 8),
            _filterChip('Groupe de véhicule', null),
            const SizedBox(height: 16),
            const Text('Classer par',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _filterChip("Date d'enregistrement", Icons.arrow_drop_down),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Appliquer les filtres',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData? trailingIcon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14))),
          Icon(trailingIcon ?? Icons.arrow_forward_ios,
              size: trailingIcon != null ? 20 : 14,
              color: Colors.grey.shade500),
        ],
      ),
    );
  }

  void _ajouterOperation() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.monetization_on_outlined,
                    color: Colors.green.shade700),
              ),
              title: const Text('Enregistrer un revenu'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RecetteFormPage()));
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade100,
                child: Icon(Icons.monetization_on_outlined,
                    color: Colors.red.shade700),
              ),
              title: const Text('Enregistrer une dépense'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DepenseFormPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationItem extends StatelessWidget {
  final OperationLigne op;
  final NumberFormat money;
  const _OperationItem({required this.op, required this.money});

  @override
  Widget build(BuildContext context) {
    final isRevenu = op.type == 'REVENU';
    final color = isRevenu ? Colors.green : Colors.red;
    final montantLabel =
        '${isRevenu ? '+' : '-'}${money.format(op.montant.abs())}';

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
            width: 42,
            height: 42,
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
                Text('Enrg. ${op.date}',
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
