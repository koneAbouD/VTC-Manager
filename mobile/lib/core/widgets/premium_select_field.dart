import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Une valeur sélectionnable dans un [PremiumSelectField].
class SelectOption<T> {
  final T value;
  final String label;
  final String? sousTitre;

  /// Si défini, la vignette affiche une pastille de cette couleur (au lieu de
  /// l'initiale du libellé) — utile pour un sélecteur de couleur.
  final Color? couleur;

  const SelectOption({
    required this.value,
    required this.label,
    this.sousTitre,
    this.couleur,
  });
}

/// Champ de sélection « premium » — remplaçant des `DropdownButtonFormField`
/// natifs (menu Material plat).
///
/// Affiche un champ cliquable (pastille-initiale + chevron) qui ouvre une
/// feuille modale arrondie : poignée de glissement, titre, recherche
/// optionnelle et tuiles à avatar/coche. La validation de formulaire est
/// intégrée (message d'erreur inline).
///
/// Rendu volontairement **sans label** : chaque écran conserve son propre style
/// de label au-dessus du champ. Passer [accent] pour s'harmoniser avec la
/// couleur d'un formulaire (vert par défaut, mais certains écrans sont bleus).
class PremiumSelectField<T> extends StatelessWidget {
  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T?> onChanged;

  final String hint;
  final String? sheetTitle;
  final bool isRequired;
  final bool enabled;

  /// null => automatique : recherche activée au-delà de 8 valeurs.
  final bool? searchable;

  /// Couleur d'accent (pastille, sélection, focus). Défaut : vert de la charte.
  final Color accent;

  /// Couleur de fond du champ fermé. Défaut : `AppColors.fieldFill`. À surcharger
  /// pour s'aligner sur les champs texte d'un écran (nuances de gris légèrement
  /// différentes selon les pages).
  final Color? fillColor;

  /// Validateur personnalisé. À défaut, un contrôle « obligatoire » est appliqué
  /// si [isRequired] est vrai.
  final String? Function(T?)? validator;

  const PremiumSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Choisir…',
    this.sheetTitle,
    this.isRequired = false,
    this.enabled = true,
    this.searchable,
    this.accent = AppColors.primary,
    this.fillColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator: validator ??
          (isRequired ? (v) => v == null ? 'Champ obligatoire' : null : null),
      builder: (state) {
        // Synchronise la valeur interne du FormField lorsque le parent la change
        // programmatiquement (ex. réinitialisation d'un champ dépendant).
        if (state.value != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.mounted && state.value != value) state.didChange(value);
          });
        }

        final selection =
            options.where((o) => o.value == value).cast<SelectOption<T>?>().firstOrNull;
        final borderColor = state.hasError ? AppColors.error : AppColors.border;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.55,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: !enabled
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final res = await _ouvrir(context, state.value);
                          if (res != null) {
                            onChanged(res.value);
                            state.didChange(res.value);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: fillColor ?? AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: borderColor,
                          width: state.hasError ? 1.4 : 1),
                    ),
                    child: Row(
                      children: [
                        if (selection != null) ...[
                          _Pastille(
                              label: selection.label,
                              accent: accent,
                              couleur: selection.couleur),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            selection?.label ?? hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: selection != null
                                  ? AppColors.dark
                                  : AppColors.hint,
                              fontWeight: selection != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.hint),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(state.errorText!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  Future<_PickResult<T>?> _ouvrir(BuildContext context, T? courante) {
    final recherche = searchable ?? options.length > 8;
    return showModalBottomSheet<_PickResult<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SelectSheet<T>(
        titre: sheetTitle ?? hint,
        options: options,
        valeurCourante: courante,
        searchable: recherche,
        effacable: !isRequired,
        accent: accent,
      ),
    );
  }
}

/// Résultat du choix : distingue « annulé » (null) de « effacé » (value == null).
class _PickResult<T> {
  final T? value;
  const _PickResult(this.value);
}

/// Vignette circulaire : pastille de couleur si [couleur] est fournie, sinon
/// l'initiale du libellé sur fond teinté par l'accent.
class _Pastille extends StatelessWidget {
  final String label;
  final Color accent;
  final Color? couleur;

  const _Pastille({required this.label, required this.accent, this.couleur});

  @override
  Widget build(BuildContext context) {
    if (couleur != null) {
      // Bordure claire pour rester visible sur les couleurs très pâles (blanc…).
      final isPale = couleur!.computeLuminance() > 0.85;
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: couleur,
          shape: BoxShape.circle,
          border: Border.all(
              color: isPale ? const Color(0xFFDDE1EA) : Colors.transparent),
        ),
      );
    }
    final initiale =
        label.trim().isNotEmpty ? label.trim()[0].toUpperCase() : '•';
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Text(initiale,
          style: TextStyle(
              color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

/// Feuille de sélection (bottom sheet premium) : poignée, recherche, tuiles.
class _SelectSheet<T> extends StatefulWidget {
  final String titre;
  final List<SelectOption<T>> options;
  final T? valeurCourante;
  final bool searchable;
  final bool effacable;
  final Color accent;

  const _SelectSheet({
    required this.titre,
    required this.options,
    required this.valeurCourante,
    required this.searchable,
    required this.effacable,
    required this.accent,
  });

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  final _rechercheCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // useSafeArea n'immunise pas le bas : la barre de navigation système
    // d'Android n'est pas protégée. On ajoute donc son inset au bas de la liste
    // pour que la dernière valeur ne passe pas sous la barre.
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final q = _q.trim().toLowerCase();
    final filtres = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) =>
                o.label.toLowerCase().contains(q) ||
                (o.sousTitre?.toLowerCase().contains(q) ?? false))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // « Effacer » (l'en-tête n'affiche plus de titre)
          if (widget.effacable && widget.valeurCourante != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, _PickResult<T>(null)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('Effacer',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            )
          else
            const SizedBox(height: 4),

          // Recherche
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _rechercheCtrl,
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontSize: 14, color: AppColors.dark),
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  hintStyle:
                      const TextStyle(color: AppColors.hint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.hint),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
              ),
            ),

          // Liste
          Flexible(
            child: filtres.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(0, 44, 0, 44 + bottomSafe),
                    child: const Text('Aucun résultat',
                        style: TextStyle(color: AppColors.hint, fontSize: 14)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(12, 2, 12, 16 + bottomSafe),
                    itemCount: filtres.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final o = filtres[i];
                      final selected = o.value == widget.valeurCourante;
                      final initiale = o.label.trim().isNotEmpty
                          ? o.label.trim()[0].toUpperCase()
                          : '•';
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              Navigator.pop(context, _PickResult<T>(o.value)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: selected
                                  ? accent.withValues(alpha: 0.10)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? accent.withValues(alpha: 0.40)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (o.couleur != null)
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: o.couleur,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            o.couleur!.computeLuminance() > 0.85
                                                ? const Color(0xFFDDE1EA)
                                                : Colors.transparent,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accent
                                          : accent.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(initiale,
                                        style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : accent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(o.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.dark,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500)),
                                      if (o.sousTitre != null &&
                                          o.sousTitre!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(o.sousTitre!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.hint)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle_rounded,
                                      color: accent, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
