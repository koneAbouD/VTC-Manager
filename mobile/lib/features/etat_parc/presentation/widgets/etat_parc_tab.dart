import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/etat_parc_provider.dart';
import 'etat_parc_synthese.dart';

// ── Tab État de parc ─────────────────────────────────────────────────────────

class EtatParcTab extends ConsumerWidget {
  const EtatParcTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(etatParcSummaryProvider);
        await ref.read(etatParcSummaryProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: const [
          EtatParcSynthese(),
        ],
      ),
    );
  }
}
