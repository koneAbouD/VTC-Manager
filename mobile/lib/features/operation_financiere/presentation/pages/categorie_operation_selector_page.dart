import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/categorie_operation.dart';
import '../../domain/enums/type_operation.dart';
import '../providers/categorie_operation_provider.dart';

class CategorieOperationSelectorPage extends ConsumerStatefulWidget {
  final TypeOperation typeOperation;

  /// Libellés de sous-catégories à masquer (comparaison insensible à la casse).
  /// Ex. {'Encaissement', 'Maintenances'} pour une opération manuelle, afin de
  /// ne pas proposer les catégories gérées automatiquement.
  final Set<String> exclureSousCategories;

  const CategorieOperationSelectorPage({
    super.key,
    required this.typeOperation,
    this.exclureSousCategories = const {},
  });

  @override
  ConsumerState<CategorieOperationSelectorPage> createState() =>
      _CategorieOperationSelectorPageState();
}

class _CategorieOperationSelectorPageState
    extends ConsumerState<CategorieOperationSelectorPage> {
  String _query = '';
  bool _refRafraichi = false;

  /// La recherche défile avec la liste : elle peut donc sortir du viewport et
  /// être reconstruite. Sans contrôleur, le champ reviendrait vide alors que le
  /// filtre, lui, resterait appliqué.
  final _rechercheCtrl = TextEditingController();

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchit une seule fois les catégories (édités ailleurs, ex.
    // ReferentielListePage). Ici et non dans initState : `ref.invalidate`
    // dépend du ProviderScope, indisponible pendant initState.
    if (!_refRafraichi) {
      _refRafraichi = true;
      ref.invalidate(categoriesByTypeProvider(widget.typeOperation));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync =
        ref.watch(categoriesByTypeProvider(widget.typeOperation));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Sélectionner une catégorie'),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur: $e',
              style: const TextStyle(color: Colors.red)),
        ),
        data: (categories) {
          // Exclure les catégories dont la sous-catégorie est masquée
          // (ex. Encaissement, Maintenances), puis appliquer la recherche.
          final exclus = widget.exclureSousCategories
              .map((s) => s.toLowerCase())
              .toSet();
          final base = exclus.isEmpty
              ? categories
              : categories
                  .where((c) => !exclus.contains(
                      (c.sousCategorie?.libelle ?? '').toLowerCase()))
                  .toList();
          final filtered = _query.isEmpty
              ? base
              : base
                  .where((c) => c.libelle
                      .toLowerCase()
                      .contains(_query.toLowerCase()))
                  .toList();

          // La recherche défile avec la liste : sur un écran court, elle libère
          // sa place dès qu'on parcourt les catégories.
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _champRecherche()),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Aucune catégorie trouvée',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                SliverPadding(
                  // Retrait bas incluant l'inset de la barre de navigation
                  // Android (gestes / 3 boutons) : sans lui, la dernière
                  // catégorie passe dessous et devient difficile à toucher.
                  padding: EdgeInsets.fromLTRB(
                      16, 4, 16, 4 + MediaQuery.of(context).padding.bottom),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _carteCategorie(filtered[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _champRecherche() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _rechercheCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Rechercher une catégorie...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _carteCategorie(CategorieOperation c) {
    final sc = c.sousCategorie;
    return GestureDetector(
      onTap: () => Navigator.pop(context, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.libelle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
            if (sc != null) ...[
              const SizedBox(height: 6),
              Text(
                sc.libelle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
