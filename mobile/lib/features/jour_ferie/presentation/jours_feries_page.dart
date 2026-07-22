import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/date_filter_dialogs.dart';
import '../data/jour_ferie_api.dart';

/// Écran d'administration des jours fériés (Côte d'Ivoire).
///
/// Modèle hybride : le bouton « Générer l'année » calcule les fériés
/// déterministes (fixes + chrétiens) ; les fêtes musulmanes (calendrier
/// lunaire, fixées par décret) s'ajoutent à la main.
class JoursFeriesPage extends ConsumerStatefulWidget {
  const JoursFeriesPage({super.key});

  @override
  ConsumerState<JoursFeriesPage> createState() => _JoursFeriesPageState();
}

class _JoursFeriesPageState extends ConsumerState<JoursFeriesPage> {
  static const _mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  late int _annee;
  bool _loading = false;
  String? _error;
  List<JourFerie> _feries = [];

  JourFerieApi get _api => JourFerieApi(ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    _annee = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.lister(_annee);
      if (mounted) setState(() => _feries = data);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changerAnnee(int delta) async {
    setState(() => _annee += delta);
    await _charger();
  }

  Future<void> _genererAnnee() async {
    setState(() => _loading = true);
    try {
      final crees = await _api.genererAnnee(_annee);
      await _charger();
      if (mounted) {
        _snack(crees.isEmpty
            ? 'Aucun nouveau férié à générer pour $_annee.'
            : '${crees.length} jour(s) férié(s) généré(s).');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(_message(e));
      }
    }
  }

  Future<void> _supprimer(JourFerie f) async {
    try {
      await _api.supprimer(f.id);
      if (mounted) setState(() => _feries.removeWhere((x) => x.id == f.id));
    } catch (e) {
      if (mounted) _snack(_message(e));
    }
  }

  Future<void> _ajouterManuel() async {
    final ajoute = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AjoutJourFerieSheet(annee: _annee, api: _api),
    );
    if (ajoute == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Jours fériés',
        // Bouton d'ajout dans l'en-tête (charte : même pill que LignesMaintenancePage).
        action: AppHeaderAction(
          icon: Icons.add_rounded,
          onTap: _ajouterManuel,
        ),
      ),
      body: Column(
        children: [
          _barreAnnee(),
          Expanded(child: _corps()),
        ],
      ),
    );
  }

  Widget _barreAnnee() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _loading ? null : () => _changerAnnee(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '$_annee',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: _loading ? null : () => _changerAnnee(1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _loading ? null : _genererAnnee,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Générer'),
          ),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_feries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('Aucun jour férié pour $_annee.',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(
                'Utilisez « Générer » pour les fériés fixes et chrétiens, '
                'puis ajoutez les fêtes musulmanes à la main.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _feries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _carte(_feries[i]),
      ),
    );
  }

  Widget _carte(JourFerie f) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _pastilleDate(f.date),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.libelle,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  _badge(_labelType(f.type), _couleurType(f.type)),
                  const SizedBox(width: 6),
                  _badge(
                      f.isManuel ? 'Manuel' : 'Auto',
                      f.isManuel ? const Color(0xFF9C6D00) : Colors.grey.shade600),
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _confirmerSuppression(f),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
          ),
        ],
      ),
    );
  }

  Widget _pastilleDate(DateTime d) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3B5BDB).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('${d.day}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B5BDB))),
          Text(_mois[d.month - 1],
              style: const TextStyle(fontSize: 11, color: Color(0xFF3B5BDB))),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _confirmerSuppression(JourFerie f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer « ${f.libelle} » du ${f.date.day}/${f.date.month}/${f.date.year} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) _supprimer(f);
  }

  String _labelType(String type) => switch (type) {
        'FIXE' => 'Fixe',
        'CHRETIEN' => 'Chrétien',
        'MUSULMAN' => 'Musulman',
        _ => 'Autre',
      };

  Color _couleurType(String type) => switch (type) {
        'FIXE' => const Color(0xFF3B5BDB),
        'CHRETIEN' => const Color(0xFF7048E8),
        'MUSULMAN' => const Color(0xFF0CA678),
        _ => Colors.grey,
      };

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _message(Object e) =>
      e is ApiException ? e.message : 'Une erreur est survenue.';
}

/// Feuille d'ajout manuel d'un jour férié (fête musulmane, décret).
class _AjoutJourFerieSheet extends StatefulWidget {
  final int annee;
  final JourFerieApi api;

  const _AjoutJourFerieSheet({required this.annee, required this.api});

  @override
  State<_AjoutJourFerieSheet> createState() => _AjoutJourFerieSheetState();
}

class _AjoutJourFerieSheetState extends State<_AjoutJourFerieSheet> {
  final _libelleCtrl = TextEditingController();
  String _type = 'MUSULMAN';
  DateTime? _date;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _libelleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate:
            DateTime(widget.annee, DateTime.now().month, DateTime.now().day),
        firstDate: DateTime(widget.annee - 1),
        lastDate: DateTime(widget.annee + 1, 12, 31),
      ),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _enregistrer() async {
    if (_date == null) {
      setState(() => _error = 'Sélectionnez une date.');
      return;
    }
    if (_libelleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Saisissez un libellé.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.ajouter(
        date: _date!,
        libelle: _libelleCtrl.text.trim(),
        type: _type,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : 'Une erreur est survenue.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajouter un jour férié',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Fêtes musulmanes ou décrets non calculés automatiquement.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 10),
                Text(
                  _date == null
                      ? 'Choisir une date'
                      : '${_date!.day}/${_date!.month}/${_date!.year}',
                  style: TextStyle(
                      color: _date == null ? Colors.grey.shade500 : Colors.black87),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _libelleCtrl,
            decoration: InputDecoration(
              hintText: 'Ex : Aïd el-Fitr, Tabaski, Maouloud…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final t in const ['MUSULMAN', 'AUTRE', 'FIXE', 'CHRETIEN'])
                ChoiceChip(
                  label: Text(_labelType(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _enregistrer,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }

  String _labelType(String type) => switch (type) {
        'FIXE' => 'Fixe',
        'CHRETIEN' => 'Chrétien',
        'MUSULMAN' => 'Musulman',
        _ => 'Autre',
      };
}
