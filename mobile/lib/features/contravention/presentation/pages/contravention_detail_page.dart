import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../domain/entities/contravention.dart';
import '../providers/contravention_provider.dart';
import 'contravention_form_page.dart';

/// Détail premium d'une contravention : synthèse en tête, puis toutes les
/// informations regroupées par section, et les actions (modifier, reverser,
/// supprimer). Renvoie `true` au pop si une modification a eu lieu.
class ContraventionDetailPage extends ConsumerStatefulWidget {
  final Contravention contravention;
  const ContraventionDetailPage({super.key, required this.contravention});

  @override
  ConsumerState<ContraventionDetailPage> createState() =>
      _ContraventionDetailPageState();
}

class _ContraventionDetailPageState
    extends ConsumerState<ContraventionDetailPage> {
  final _money = NumberFormat('#,##0', 'fr_FR');

  Contravention get c => widget.contravention;

  // ── Dérivés ──────────────────────────────────────────────────────────────

  (String, Color) get _statut {
    if (c.isCancelled) return ('Annulé', AppColors.error);
    if (c.isReverse) return ('Reversé', AppColors.success);
    if (c.isPaid) return ('Payé', AppColors.success);
    if (c.isPartial) return ('Partiellement payé', AppColors.info);
    return ('En attente', AppColors.warning);
  }

  double get _reste =>
      (c.montant - (c.montantPaye ?? 0)).clamp(0, double.infinity);

  String _fmtXof(num v) => '${_money.format(v)} XOF';

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _edit() async {
    final res = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ContraventionFormPage(initial: c)));
    if (res == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _reverser() async {
    // Reversement à l'État : porte sur le montant total de la contravention et
    // peut se faire même si elle n'a pas été payée par le chauffeur. Le
    // remboursement chauffeur (PAYE) se fait, lui, côté finance via la
    // compensation lors de la restitution des cotisations (arrêté de compte).
    final montant = c.montant;
    if (montant <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icône dans une pastille teintée.
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_outlined,
                      size: 28, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Reverser à l\'État',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le montant total de la contravention sera reversé à l\'État. '
                'Une opération « Reversement contravention » sera enregistrée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5, height: 1.4, color: AppColors.label),
              ),
              const SizedBox(height: 18),
              // Montant à reverser — lecture seule (cadenas = non modifiable).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline,
                          size: 18, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Montant à reverser',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark)),
                          const SizedBox(height: 2),
                          Text(_fmtXof(montant),
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.label,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon:
                            const Icon(Icons.account_balance_outlined, size: 18),
                        label: const Text('Reverser',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(contraventionNotifierProvider.notifier)
        .reverserContravention(c.id!);
    if (!mounted) return;
    if (error != null) {
      _toast(error, err: true);
    } else {
      _toast('Contravention reversée');
      Navigator.pop(context, true);
    }
  }

  void _openDocument(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DocumentViewerPage(contraventionId: id),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la contravention'),
        content: const Text('Cette action est définitive. Confirmer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(contraventionNotifierProvider.notifier)
        .deleteContravention(c.id!);
    if (!mounted) return;
    if (error != null) {
      _toast(error, err: true);
    } else {
      Navigator.pop(context, true);
    }
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: err ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (statutLabel, statutColor) = _statut;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Contravention',
        action: AppHeaderAction(icon: Icons.edit_outlined, onTap: _edit),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PremiumHero(
            amount: _fmtXof(c.montant),
            footerIcon: Icons.directions_car_outlined,
            footer: [
              c.vehiculeNom ?? 'Véhicule non défini',
              if (c.chauffeurNom != null) c.chauffeurNom!,
            ].join('  ·  '),
            chips: [
              PremiumChip(statutLabel, statutColor),
            ],
          ),
          const SizedBox(height: 14),
          PremiumSection(
            title: 'Infraction',
            icon: Icons.gavel_outlined,
            children: [
              PremiumRow('Numéro', c.numeroContravention),
              PremiumRow('Code', c.codeInfraction),
              PremiumRow("Type d'infraction", c.typeInfraction),
              PremiumRow('Date', _fmtDate(c.dateInfraction)),
              PremiumRow('Heure', _fmtHeure(c.heureInfraction)),
              PremiumRow('Vitesse relevée',
                  c.vitesseRelevee != null ? '${c.vitesseRelevee} km/h' : null),
              PremiumRow('Lieu', c.lieu),
              PremiumRow('Description', c.description),
            ],
          ),
          PremiumSection(
            title: 'Véhicule et chauffeur',
            icon: Icons.directions_car_outlined,
            children: [
              PremiumRow('Véhicule', c.vehiculeNom),
              PremiumRow('Chauffeur', c.chauffeurNom),
            ],
          ),
          PremiumSection(
            title: 'Montants',
            icon: Icons.payments_outlined,
            children: [
              PremiumRow('Montant', _fmtXof(c.montant), strong: true),
              PremiumRow('Cotisation',
                  c.cotisation != null ? _fmtXof(c.cotisation!) : null),
              PremiumRow('Déjà payé',
                  c.montantPaye != null ? _fmtXof(c.montantPaye!) : null),
              PremiumRow('Reste à payer',
                  c.isPaid ? _fmtXof(0) : _fmtXof(_reste)),
              PremiumRow('Statut', statutLabel, valueColor: statutColor),
              PremiumRow('Date de paiement',
                  c.datePaiement != null ? _fmtDate(c.datePaiement!) : null),
            ],
          ),
          if (c.documentSourcePath != null && c.id != null)
            _documentCard(onTap: () => _openDocument(c.id!)),
          const SizedBox(height: 2),
          _actions(),
        ],
      ),
    );
  }

  // ── Composants ────────────────────────────────────────────────────────────

  /// Carte « Document source » cliquable : ouvre la visualisation premium du
  /// relevé PDF archivé.
  Widget _documentCard({required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  size: 22, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Document source',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                  SizedBox(height: 2),
                  Text('Relevé PDF · appuyer pour visualiser',
                      style: TextStyle(fontSize: 12, color: AppColors.label)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.hint),
          ]),
        ),
      ),
    );
  }

  /// Boutons d'action alignés côte à côte : « Reverser » (plein, prend la
  /// largeur restante) et « Supprimer » (contour rouge, à droite). Quand le
  /// reversement n'est plus possible, seul « Supprimer » subsiste.
  Widget _actions() {
    final reversable = !c.isReverse && !c.isCancelled;
    return Row(children: [
      if (reversable) ...[
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _reverser,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: const Text('Reverser',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Supprimer',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  // ── Formatage ─────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String? _fmtHeure(String? h) {
    if (h == null || h.length < 5) return null;
    return h.substring(0, 5);
  }
}

// ── Visionneuse du document source ───────────────────────────────────────────

/// Page plein écran affichant le relevé PDF archivé d'une contravention.
/// Récupère les octets via l'API (avec authentification) puis les rend avec
/// pdfx (PDF) ou, en repli, comme image.
class _DocumentViewerPage extends ConsumerWidget {
  final int contraventionId;
  const _DocumentViewerPage({required this.contraventionId});

  static const _fond = Color(0xFF12122A);

  bool _looksPdf(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46; // « %PDF »

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contraventionDocumentBytesProvider(contraventionId));
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppHeader(
        title: 'Relevé PDF',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () =>
              ref.invalidate(contraventionDocumentBytesProvider(contraventionId)),
        ),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white54)),
        error: (e, _) => _erreur(context, ref),
        data: (bytes) {
          if (bytes.isEmpty) return _erreur(context, ref);
          if (_looksPdf(bytes)) return _PdfBytesViewer(bytes: bytes);
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.memory(bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _erreur(context, ref)),
            ),
          );
        },
      ),
    );
  }

  Widget _erreur(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined,
              color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          const Text('Document indisponible',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref
                .invalidate(contraventionDocumentBytesProvider(contraventionId)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _PdfBytesViewer extends StatefulWidget {
  final Uint8List bytes;
  const _PdfBytesViewer({required this.bytes});

  @override
  State<_PdfBytesViewer> createState() => _PdfBytesViewerState();
}

class _PdfBytesViewerState extends State<_PdfBytesViewer> {
  PdfController? _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
          child: CircularProgressIndicator(color: Colors.white54));
    }
    if (_error || _controller == null) {
      return const Center(
        child: Text('Aperçu du PDF indisponible',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
      );
    }
    return PdfView(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      pageSnapping: false,
      backgroundDecoration:
          const BoxDecoration(color: Color(0xFF12122A)),
    );
  }
}
