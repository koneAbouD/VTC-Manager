import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `hide TextDirection` : intl exporte une classe TextDirection qui entre en
// conflit avec celle de Flutter (dart:ui), requise par ShapeBorder.
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/widgets/app_header.dart';
import '../../core/utils/libelle_operation.dart';
import '../../core/widgets/month_filter_pill.dart';
import '../../core/widgets/responsive_field_row.dart' show kFormPhoneBreakpoint;
import '../home_nav_provider.dart';

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
  final String? categorieCode;
  final String? categorieLibelle;
  final String? chauffeurNom;
  final String? vehiculeLabel;
  final double montant;
  final String date;
  const OperationLigne(
      {required this.id,
      required this.type,
      this.description,
      this.categorieCode,
      this.categorieLibelle,
      this.chauffeurNom,
      this.vehiculeLabel,
      required this.montant,
      required this.date});

  factory OperationLigne.fromJson(Map<String, dynamic> j) => OperationLigne(
        id: j['id'] ?? 0,
        type: j['type'] ?? '',
        description: j['description'],
        categorieCode: j['categorieCode'],
        categorieLibelle: j['categorieLibelle'],
        chauffeurNom: j['chauffeurNom'],
        vehiculeLabel: j['vehiculeLabel'],
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        date: j['date'] ?? '',
      );

  /// Titre de la ligne, aligné sur la liste des opérations : un encaissement
  /// affiche la période réglée (« Encaissement recettes d'hier »), les autres
  /// opérations gardent leur description (commentaire / sous-catégorie).
  String get titreLigne {
    final jour = DateTime.tryParse(date);
    if (estCategorieEncaissement(categorieCode) &&
        categorieLibelle != null &&
        jour != null) {
      return libelleLigneOperation(
        categorieCode: categorieCode,
        categorie: categorieLibelle!,
        date: jour,
      );
    }
    return description ?? '—';
  }
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
  /// true quand la page est embarquée dans un onglet du hub Finances :
  /// masque le bouton retour de l'en-tête.
  final bool embedded;

  const RapportFinancierPage({super.key, this.embedded = false});

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
      appBar: AppHeader(title: 'Rapport financier', showBack: !widget.embedded),
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
                  // Padding bas incluant l'inset de la barre de navigation
                  // Android pour que la liste ne passe pas dessous.
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Mois picker (style filtre par date des opérations)
          Expanded(
            child: MonthFilterPill(
              mois: _mois,
              annee: _annee,
              onChanged: (m, a) => setState(() {
                _mois = m;
                _annee = a;
              }),
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
                                color: Colors.black.withValues(alpha: 0.08),
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
                                color: Colors.black.withValues(alpha: 0.08),
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
              color: Colors.black.withValues(alpha: 0.04),
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
              Flexible(
                child: Text(
                  '${NumberFormat('#,##0', 'fr_FR').format(montant.abs())} ',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Répartition',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text('${items.length} au total',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 16),
          _LoopingBarChart(items: items, money: _money),
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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Répartition par catégorie',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text('${items.length} catégories',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 16),
          // Tablette : défilement horizontal des bulles.
          // Téléphone : défilement vertical (hauteur bornée à ~3 bulles).
          Builder(
            builder: (context) {
              final isTablet =
                  MediaQuery.of(context).size.width >= kFormPhoneBreakpoint;
              if (isTablet) {
                return SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 18),
                    itemBuilder: (context, i) => _pieBubble(
                        items[i], pieColors[i % pieColors.length],
                        fixedWidth: 68),
                  ),
                );
              }
              // Téléphone : bulle à gauche + libellé sur la même ligne,
              // liste verticale scrollable (hauteur bornée à ~4 lignes).
              final visibles = items.length < 4 ? items.length : 4;
              return SizedBox(
                height: visibles * 60,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _pieRow(
                      items[i], pieColors[i % pieColors.length]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Une bulle « catégorie » : cercle % + libellé, appui maintenu = info-bulle.
  /// [fixedWidth] pour le Wrap (téléphone) ; null en tablette (largeur = slot
  /// Expanded).
  Widget _pieBubble(BreakdownItem item, Color color, {double? fixedWidth}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
          ),
          child: Center(
            child: Text(
              '${item.pourcentage.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.label,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return _PieItemBubble(
      item: item,
      color: color,
      money: _money,
      child: fixedWidth != null
          ? SizedBox(width: fixedWidth, child: content)
          : content,
    );
  }

  /// Variante ligne (téléphone) : cercle % à gauche, libellé sur la même ligne.
  /// Appui maintenu = info-bulle du montant.
  Widget _pieRow(BreakdownItem item, Color color) {
    return _PieItemBubble(
      item: item,
      color: color,
      money: _money,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 4),
            ),
            child: Center(
              child: Text(
                '${item.pourcentage.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
              onPressed: _ouvrirOngletOperations,
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
            .map((op) => _OperationTile(op: op, onTap: _ouvrirOngletOperations)),
      ],
    );
  }

  /// Revient au hub Finances et ouvre l'onglet Opérations déjà filtré sur le
  /// type courant (Revenus / Dépenses).
  void _ouvrirOngletOperations() {
    ref.read(operationsTypeFiltreProvider.notifier).state =
        _showRevenus ? 'REVENU' : 'DEPENSE';
    ref.read(financeTabIndexProvider.notifier).state = FinanceTab.operations;
    Navigator.pop(context);
  }

  void _toggleGroupBy() {
    setState(() =>
        _groupBy = _groupBy == 'CHAUFFEUR' ? 'VEHICULE' : 'CHAUFFEUR');
  }
}

/// Tuile d'opération alignée sur celle de la page Opérations (`_OpCard`) :
/// icône ronde revenu/dépense, libellé + montant signé, puis
/// « véhicule - chauffeur · date ».
class _OperationTile extends StatelessWidget {
  final OperationLigne op;

  /// Ouvre l'onglet Opérations : le rapport ne connaît pas l'entité complète,
  /// donc la ligne renvoie vers la liste plutôt que vers un détail.
  final VoidCallback onTap;

  const _OperationTile({required this.op, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRevenu = op.type == 'REVENU';
    final amountColor =
        isRevenu ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    // Seules les dépenses portent un signe : la couleur de la pastille
    // suffit à distinguer les revenus.
    final sign = isRevenu ? '' : '-';

    final titre = op.titreLigne;
    final vehiculeChauffeur = [
      if (op.vehiculeLabel != null) op.vehiculeLabel!,
      if (op.chauffeurNom != null) op.chauffeurNom!,
    ].join(' - ');

    // Date en dd/MM comme la page Opérations (si parseable).
    final parsed = DateTime.tryParse(op.date);
    final dateLabel =
        parsed != null ? DateFormat('dd/MM', 'fr_FR').format(parsed) : op.date;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRevenu
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: amountColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne 1 : libellé + montant
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${NumberFormat('#,##0', 'fr_FR').format(op.montant.abs())} XOF',
                      style: const TextStyle(
                        // Montant en noir comme le libellé ; le sens de
                        // l'opération se lit sur la pastille d'icône.
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Ligne 2 : véhicule - chauffeur · date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vehiculeChauffeur,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateLabel,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
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

// ── Info-bulle catégorie (appui maintenu) ────────────────────────────────────

/// Enveloppe un élément du camembert « Répartition par catégorie ». Un appui
/// maintenu affiche une info-bulle (montant + pourcentage) juste au-dessus de
/// l'élément ; elle disparaît dès que l'on relâche.
class _PieItemBubble extends StatefulWidget {
  final BreakdownItem item;
  final Color color;
  final NumberFormat money;
  final Widget child;

  const _PieItemBubble({
    required this.item,
    required this.color,
    required this.money,
    required this.child,
  });

  @override
  State<_PieItemBubble> createState() => _PieItemBubbleState();
}

class _PieItemBubbleState extends State<_PieItemBubble> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        // Au moins une contrainte de position (left/top) est nécessaire pour
        // que l'Overlay traite l'enfant comme « positionné » : sinon il est
        // étiré à la taille de l'écran et la bulle remplit tout l'écran.
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          // Ancrée à gauche, juste au-dessus du cercle de la catégorie.
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(4, -2),
          child: Material(
            color: Colors.transparent,
            // Échelle de texte figée à 1 : la taille de police du téléphone
            // ne peut pas gonfler la bulle.
            child: MediaQuery.withNoTextScaling(
              child: _buildBubble(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  static const double _tailHeight = 7;

  Widget _buildBubble() {
    return Container(
      // Espace supplémentaire en bas pour la pointe (le texte reste dans le
      // corps de la bulle).
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6 + _tailHeight),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: _BubbleWithTail(
          color: widget.color,
          radius: 9,
          tailWidth: 13,
          tailHeight: _tailHeight,
          tailCenterFromLeft: 20,
          strokeWidth: 1.2,
        ),
        shadows: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        widget.money.format(widget.item.montant),
        style: TextStyle(
            color: widget.color,
            fontSize: 13,
            fontWeight: FontWeight.bold),
        maxLines: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _show(),
        onTapUp: (_) => _hide(),
        onTapCancel: _hide,
        child: widget.child,
      ),
    );
  }
}

/// Forme de bulle : corps arrondi surmonté d'une pointe vers le bas (façon
/// accolade renversée) qui désigne la catégorie sous elle. La bordure et la
/// pointe forment un tracé continu à la couleur de la catégorie.
class _BubbleWithTail extends ShapeBorder {
  final Color color;
  final double radius;
  final double tailWidth;
  final double tailHeight;
  final double tailCenterFromLeft;
  final double strokeWidth;

  const _BubbleWithTail({
    required this.color,
    required this.radius,
    required this.tailWidth,
    required this.tailHeight,
    required this.tailCenterFromLeft,
    required this.strokeWidth,
  });

  Path _buildPath(Rect rect) {
    // Corps de la bulle : le rectangle sans la bande basse réservée à la pointe.
    final body = Rect.fromLTRB(
        rect.left, rect.top, rect.right, rect.bottom - tailHeight);
    final r = Radius.circular(radius);
    final tailCenter = rect.left + tailCenterFromLeft;
    final tailLeft = tailCenter - tailWidth / 2;
    final tailRight = tailCenter + tailWidth / 2;

    return Path()
      ..moveTo(body.left + radius, body.top)
      ..lineTo(body.right - radius, body.top)
      ..arcToPoint(Offset(body.right, body.top + radius), radius: r)
      ..lineTo(body.right, body.bottom - radius)
      ..arcToPoint(Offset(body.right - radius, body.bottom), radius: r)
      // Bord bas jusqu'à la base droite de la pointe.
      ..lineTo(tailRight, body.bottom)
      // Descente vers la pointe, avec un sommet légèrement arrondi.
      ..lineTo(tailCenter + 1.5, body.bottom + tailHeight - 1.5)
      ..quadraticBezierTo(tailCenter, body.bottom + tailHeight,
          tailCenter - 1.5, body.bottom + tailHeight - 1.5)
      ..lineTo(tailLeft, body.bottom)
      // Retour au coin bas gauche.
      ..lineTo(body.left + radius, body.bottom)
      ..arcToPoint(Offset(body.left, body.bottom - radius), radius: r)
      ..lineTo(body.left, body.top + radius)
      ..arcToPoint(Offset(body.left + radius, body.top), radius: r)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(_buildPath(rect), paint);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: tailHeight);

  @override
  ShapeBorder scale(double t) => _BubbleWithTail(
        color: color,
        radius: radius * t,
        tailWidth: tailWidth * t,
        tailHeight: tailHeight * t,
        tailCenterFromLeft: tailCenterFromLeft * t,
        strokeWidth: strokeWidth * t,
      );
}

// ── Graphique de répartition à défilement horizontal en boucle ────────────────

/// Affiche les barres de répartition (par véhicule ou chauffeur) dans une liste
/// horizontale que l'on peut faire défiler à l'infini, en boucle dans les deux
/// sens. Toutes les entrées sont visibles (plus de limite à 5).
class _LoopingBarChart extends StatefulWidget {
  final List<BreakdownItem> items;
  final NumberFormat money;

  const _LoopingBarChart({required this.items, required this.money});

  @override
  State<_LoopingBarChart> createState() => _LoopingBarChartState();
}

class _LoopingBarChartState extends State<_LoopingBarChart> {
  static const _barColors = [
    Color(0xFF42A5F5), // blue.400
    Color(0xFF5C6BC0), // indigo.400
    Color(0xFFAB47BC), // purple.400
    Color(0xFF26A69A), // teal.400
    Color(0xFF26C6DA), // cyan.400
  ];
  static const double _barWidth = 76;
  // Nombre de répétitions virtuelles pour simuler un défilement infini : on
  // démarre au milieu pour pouvoir scroller librement dans les deux sens.
  static const int _loopFactor = 1000;

  late final ScrollController _controller;
  late final bool _canLoop;

  @override
  void initState() {
    super.initState();
    _canLoop = widget.items.length > 1;
    final initialOffset = _canLoop
        ? _barWidth * widget.items.length * (_loopFactor ~/ 2)
        : 0.0;
    _controller = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final maxMontant =
        items.map((e) => e.montant).reduce((a, b) => a > b ? a : b);
    final count = _canLoop ? items.length * _loopFactor : items.length;

    return SizedBox(
      height: 172,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // Largeur fixe connue à l'avance : la liste n'a plus à mesurer chaque
        // barre, ce qui allège nettement le défilement sur le compte virtuel.
        itemExtent: _barWidth,
        itemCount: count,
        itemBuilder: (context, index) {
          final i = index % items.length;
          final item = items[i];
          final ratio = maxMontant > 0 ? item.montant / maxMontant : 0.0;
          return SizedBox(
            width: _barWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.money.format(item.montant),
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 120 * ratio.clamp(0.05, 1.0),
                    decoration: BoxDecoration(
                      color: _barColors[i % _barColors.length],
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
