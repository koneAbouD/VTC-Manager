import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_header.dart';

/// Libellé court d'un mode d'éclairage, pour le sélecteur comme pour le
/// résumé affiché dans les réglages.
String libelleModeTheme(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Clair',
      ThemeMode.dark => 'Sombre',
      ThemeMode.system => 'Système',
    };

/// Réglages › Configurations › Apparence : mode clair / sombre / système et
/// couleur d'accent.
///
/// Le choix s'applique à l'instant — la page se redessine sous les yeux de
/// l'utilisateur, sans bouton « Enregistrer » — et reste mémorisé sur
/// l'appareil.
class ApparencePage extends ConsumerWidget {
  const ApparencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apparence = ref.watch(themeControllerProvider);
    final controleur = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Apparence'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          const _Titre('Mode'),
          _SelecteurMode(
            valeur: apparence.mode,
            onChanged: controleur.choisirMode,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              apparence.mode == ThemeMode.system
                  ? "L'application suit le réglage de votre téléphone."
                  : 'Le mode Système suit le réglage de votre téléphone.',
              style: TextStyle(fontSize: 12, color: AppColors.label),
            ),
          ),
          const SizedBox(height: 24),
          const _Titre("Couleur d'accent"),
          _GrilleAccents(
            valeur: apparence.accent,
            onChanged: controleur.choisirAccent,
          ),
          const SizedBox(height: 24),
          const _Titre('Aperçu'),
          const _Apercu(),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  final String texte;
  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          texte,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
      );
}

/// Trois choix côte à côte, le retenu mis en avant par la couleur d'accent.
class _SelecteurMode extends StatelessWidget {
  final ThemeMode valeur;
  final ValueChanged<ThemeMode> onChanged;

  const _SelecteurMode({required this.valeur, required this.onChanged});

  /// Ordre d'affichage : du plus clair au plus « automatique ».
  static const _ordre = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  static const _icones = {
    ThemeMode.light: Icons.light_mode_rounded,
    ThemeMode.dark: Icons.dark_mode_rounded,
    ThemeMode.system: Icons.brightness_auto_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in _ordre) ...[
          if (mode != _ordre.first) const SizedBox(width: 10),
          Expanded(
            child: _ChoixMode(
              libelle: libelleModeTheme(mode),
              icone: _icones[mode]!,
              selectionne: mode == valeur,
              onTap: () => onChanged(mode),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoixMode extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final bool selectionne;
  final VoidCallback onTap;

  const _ChoixMode({
    required this.libelle,
    required this.icone,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = selectionne ? AppColors.primary : AppColors.label;
    return Semantics(
      button: true,
      selected: selectionne,
      label: 'Mode $libelle',
      child: Material(
        color: selectionne ? AppColors.primaryTint : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectionne ? AppColors.primary : AppColors.border,
                width: selectionne ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icone, size: 24, color: couleur),
                const SizedBox(height: 6),
                Text(
                  libelle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastilles de couleur, quatre par ligne. La couleur affichée est celle du
/// mode en cours : ce qu'on voit est ce qu'on obtient.
class _GrilleAccents extends StatelessWidget {
  final AppAccent valeur;
  final ValueChanged<AppAccent> onChanged;

  const _GrilleAccents({required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, c) {
        const colonnes = 4;
        final largeur = c.maxWidth / colonnes;
        return Wrap(
          children: [
            for (final accent in AppAccent.values)
              SizedBox(
                width: largeur,
                child: _Pastille(
                  accent: accent,
                  selectionne: accent == valeur,
                  onTap: () => onChanged(accent),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _Pastille extends StatelessWidget {
  final AppAccent accent;
  final bool selectionne;
  final VoidCallback onTap;

  const _Pastille({
    required this.accent,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = AppColors.estSombre ? accent.primaryNuit : accent.primary;
    return Semantics(
      button: true,
      selected: selectionne,
      label: 'Accent ${accent.libelle}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 2),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectionne ? AppColors.dark : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: selectionne
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                accent.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selectionne ? FontWeight.w800 : FontWeight.w600,
                  color: selectionne ? AppColors.dark : AppColors.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maquette des éléments courants (bouton, pastille de statut, champ) pour
/// juger du résultat sans quitter la page.
class _Apercu extends StatelessWidget {
  const _Apercu();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_taxi_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recette du jour',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.positiveTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Encaissé',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.positive,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '45 000 FCFA attendus sur 3 véhicules.',
            style: TextStyle(fontSize: 13, color: AppColors.label),
          ),
          const SizedBox(height: 14),
          const TextField(
            readOnly: true,
            decoration: InputDecoration(labelText: 'Montant versé'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              child: const Text('Encaisser'),
            ),
          ),
        ],
      ),
    );
  }
}
