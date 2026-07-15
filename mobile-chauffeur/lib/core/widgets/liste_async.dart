import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/exception.dart';

/// Contenu commun aux listes (sans Scaffold/AppBar) : pull-to-refresh, états
/// chargement / erreur / vide gérés une seule fois.
class ListeAsync<T> extends StatelessWidget {
  final AsyncValue<List<T>> valeur;
  final Future<void> Function() onRefresh;
  final Widget Function(T item) itemBuilder;
  final String messageVide;

  const ListeAsync({
    super.key,
    required this.valeur,
    required this.onRefresh,
    required this.itemBuilder,
    this.messageVide = 'Aucun élément.',
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: valeur.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icone: Icons.error_outline_rounded,
          texte: messageFromError(e),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _Message(icone: Icons.inbox_rounded, texte: messageVide);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => itemBuilder(items[i]),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Message({required this.icone, required this.texte});
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(icone, size: 56, color: Colors.black26),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
          ),
        ],
      );
}
