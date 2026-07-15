import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/pages/set_password_page.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../contravention/presentation/pages/infractions_page.dart';
import '../../../cotisation/presentation/pages/cotisations_page.dart';
import '../../../indisponibilite/presentation/pages/indisponibilites_page.dart';
import '../../../operation/presentation/pages/operations_page.dart';
import '../../../operation/presentation/providers/operation_providers.dart';
import '../../../operation/presentation/widgets/operation_tile.dart';
import '../../../paiement/presentation/pages/paiement_sheet.dart';
import '../../../recette/presentation/pages/recettes_page.dart';
import '../../domain/entities/profil.dart';
import '../../domain/entities/solde.dart';
import '../providers/compte_providers.dart';

/// Accueil de l'app chauffeur, calqué sur l'accueil de l'app gestionnaire :
/// carte solde (style carte Encaisser), raccourcis ronds en dessous, puis la
/// liste des opérations liées au chauffeur ou à son véhicule.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider);
    final solde = ref.watch(soldeProvider);
    final operations = ref.watch(operationsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'mot-de-passe':
                  _push(context, const SetPasswordPage());
                case 'logout':
                  ref.read(authControllerProvider.notifier).logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mot-de-passe',
                child: ListTile(
                  leading: Icon(Icons.password_rounded),
                  title: Text('Définir un mot de passe'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Se déconnecter'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profilProvider);
          ref.invalidate(soldeProvider);
          ref.invalidate(operationsProvider);
          await ref.read(operationsProvider.future).catchError((_) => throw '');
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Carte solde (style carte Encaisser) ─────────────────────────
            solde.when(
              data: (s) => _MonCompteCard(solde: s, profil: profil.valueOrNull),
              loading: () => const _CarteSkeleton(),
              error: (e, _) => _ErreurBloc(message: messageFromError(e)),
            ),
            const SizedBox(height: 24),

            // ── Raccourcis (boutons ronds) ──────────────────────────────────
            _Raccourcis(
              items: [
                (
                  icon: Icons.payments_outlined,
                  label: 'Recettes',
                  onTap: () => _push(context, const RecettesPage()),
                ),
                (
                  icon: Icons.analytics_outlined,
                  label: 'Cotisations',
                  onTap: () => _push(context, const CotisationsPage()),
                ),
                (
                  icon: Icons.gavel_outlined,
                  label: 'Contraventions',
                  onTap: () => _push(context, const InfractionsPage()),
                ),
                (
                  icon: Icons.event_busy_outlined,
                  label: 'Indispo.',
                  onTap: () => _push(context, const IndisponibilitesPage()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Opérations liées au chauffeur / véhicule ────────────────────
            operations.when(
              data: (ops) => ops.isEmpty
                  ? const _VideBloc(message: 'Aucune opération pour le moment.')
                  : Column(
                      children: [
                        ...ops.take(10).map((o) => OperationTile(op: o)),
                        const SizedBox(height: 6),
                        _PlusOperationsBouton(
                          onTap: () => _push(context, const OperationsPage()),
                        ),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErreurBloc(message: messageFromError(e)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte solde ───────────────────────────────────────────────────────────────

enum _Perimetre { chauffeur, vehicule }

String _perimetreLabel(_Perimetre p) =>
    p == _Perimetre.chauffeur ? 'Chauffeur' : 'Véhicule';

class _MonCompteCard extends StatefulWidget {
  final Solde solde;
  final Profil? profil;
  const _MonCompteCard({required this.solde, required this.profil});

  @override
  State<_MonCompteCard> createState() => _MonCompteCardState();
}

class _MonCompteCardState extends State<_MonCompteCard> {
  bool _visible = false;
  _Perimetre _perimetre = _Perimetre.chauffeur;
  final GlobalKey _filtreKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  CompteCourant? get _compte => _perimetre == _Perimetre.chauffeur
      ? widget.solde.chauffeur
      : widget.solde.vehicule;

  void _onPayer() {
    showPaiementSheet(context);
  }

  String get _valeurLabel {
    if (_perimetre == _Perimetre.chauffeur) {
      return widget.profil?.nomComplet ?? 'Chauffeur';
    }
    return widget.profil?.vehiculeLibelle ?? 'Véhicule';
  }

  IconData get _valeurIcon => _perimetre == _Perimetre.chauffeur
      ? Icons.person_outline_rounded
      : Icons.directions_car_outlined;

  // ── Menu déroulant de sélection du périmètre (calqué sur l'app mobile) ──
  void _showFiltreOverlay() {
    _removeOverlay();
    final renderBox =
        _filtreKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _Perimetre.values.map((mode) {
                      final sel = _perimetre == mode;
                      return InkWell(
                        onTap: () {
                          setState(() => _perimetre = mode);
                          _removeOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                sel
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off_outlined,
                                size: 18,
                                color: sel
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _perimetreLabel(mode),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      sel ? FontWeight.w600 : FontWeight.w400,
                                  color: sel
                                      ? AppColors.primary
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final compte = _compte;
    final net = compte?.net ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBDBDBD), Color(0xFFEEEEEE), Color(0xFF9E9E9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne 1 : pill périmètre + pill valeur ───────────────────
            Row(
              children: [
                GestureDetector(
                  key: _filtreKey,
                  onTap: _showFiltreOverlay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          _perimetreLabel(_perimetre),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(_valeurIcon,
                            size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _valeurLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Ligne 2 : montant net + œil + bouton Payer ───────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _visible ? Fmt.money(net) : '••••••',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _visible = !_visible),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Icon(
                            _visible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _onPayer,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Payer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(94, 40),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Ligne 3 : Cotisations | Créances ─────────────────────────
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CardStat(
                    label: 'Cotisations',
                    value:
                        _visible ? Fmt.money(compte?.fondsCotisation) : '••••',
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _CardStat(
                    label: 'Créances',
                    value: _visible ? Fmt.money(compte?.totalCreances) : '••••',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  const _CardStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Raccourcis ronds ──────────────────────────────────────────────────────────

class _Raccourcis extends StatelessWidget {
  final List<({IconData icon, String label, VoidCallback onTap})> items;
  const _Raccourcis({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map((s) => Expanded(
                child: _ShortcutItem(
                    icon: s.icon, label: s.label, onTap: s.onTap),
              ))
          .toList(),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton « Plus d'opérations » (style app gestionnaire) ─────────────────────

class _PlusOperationsBouton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusOperationsBouton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.unfold_more_rounded, size: 16),
        label: const Text("Plus d'opérations"),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          backgroundColor: AppColors.primaryTint,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ── Blocs auxiliaires ─────────────────────────────────────────────────────────

class _CarteSkeleton extends StatelessWidget {
  const _CarteSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _VideBloc extends StatelessWidget {
  final String message;
  const _VideBloc({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.black26),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
          ],
        ),
      );
}

class _ErreurBloc extends StatelessWidget {
  final String message;
  const _ErreurBloc({required this.message});
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFDECEA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}
