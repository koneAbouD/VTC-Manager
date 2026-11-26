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

  PremiumSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Choisir…',
    this.sheetTitle,
    this.isRequired = false,
    this.enabled = true,
    this.searchable,
    Color? accent,
    this.fillColor,
    this.validator,
  }) : accent = accent ?? AppColors.primary;

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
                  // Même gabarit que les champs texte du thème : fond gris
                  // sans contour, contour rouge seulement en cas d'erreur.
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: fillColor ?? AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: state.hasError
                              ? AppColors.error
                              : Colors.transparent,
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
                        Icon(Icons.keyboard_arrow_down_rounded,
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
                        TextStyle(color: AppColors.error, fontSize: 12)),
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
              color: isPale ? AppColors.border : Colors.transparent),
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
                      style: TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
                style: TextStyle(fontSize: 14, color: AppColors.dark),
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  hintStyle:
                      TextStyle(color: AppColors.hint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  // Fond gris et contours du thème ; le contour actif reprend
                  // l'accent de la liste.
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
                    child: Text('Aucun résultat',
                        style: TextStyle(color: AppColors.hint, fontSize: 14)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(12, 2, 12, 16 + bottomSafe),
                    itemCount: filtres.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final o = filtres[i];
                      return _TuileOption<T>(
                        option: o,
                        selected: o.value == widget.valeurCourante,
                        accent: accent,
                        onTap: () =>
                            Navigator.pop(context, _PickResult<T>(o.value)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Une valeur de la liste, commune aux feuilles à choix unique et multiple :
/// vignette (initiale ou couleur), libellé, sous-titre et marque de sélection.
///
/// En choix multiple, une valeur non cochée porte un cercle vide : on voit
/// d'emblée que plusieurs valeurs peuvent être retenues.
class _TuileOption<T> extends StatelessWidget {
  final SelectOption<T> option;
  final bool selected;
  final bool multiple;
  final Color accent;
  final VoidCallback onTap;

  const _TuileOption({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.multiple = false,
  });

  @override
  Widget build(BuildContext context) {
    final o = option;
    final initiale =
        o.label.trim().isNotEmpty ? o.label.trim()[0].toUpperCase() : '•';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.40) : AppColors.border,
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
                      color: o.couleur!.computeLuminance() > 0.85
                          ? AppColors.border
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
                    color: selected ? accent : accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Text(initiale,
                      style: TextStyle(
                          color: selected ? Colors.white : accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.dark,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                    if (o.sousTitre != null && o.sousTitre!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(o.sousTitre!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.hint)),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent, size: 20)
              else if (multiple)
                Icon(Icons.radio_button_unchecked_rounded,
                    color: AppColors.border, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Variante à **choix multiple** de [PremiumSelectField] : même champ, même
/// feuille, mêmes tuiles. Toucher une valeur la coche ou la décoche ; la
/// sélection est retenue dès que la feuille se referme (glissement, toucher
/// hors de la feuille, retour arrière), sans bouton à valider.
///
/// L'ordre des valeurs rendues est celui où elles ont été cochées : le
/// premier choix peut ainsi avoir un sens particulier pour l'écran (type
/// principal d'une maintenance, par exemple).
class PremiumMultiSelectField<T> extends StatelessWidget {
  final List<T> values;
  final List<SelectOption<T>> options;
  final ValueChanged<List<T>> onChanged;

  final String hint;
  final String? sheetTitle;
  final bool isRequired;
  final bool enabled;

  /// null => automatique : recherche activée au-delà de 8 valeurs.
  final bool? searchable;
  final Color accent;
  final Color? fillColor;
  final String? Function(List<T>)? validator;

  PremiumMultiSelectField({
    super.key,
    required this.values,
    required this.options,
    required this.onChanged,
    this.hint = 'Choisir…',
    this.sheetTitle,
    this.isRequired = false,
    this.enabled = true,
    this.searchable,
    Color? accent,
    this.fillColor,
    this.validator,
  }) : accent = accent ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return FormField<List<T>>(
      initialValue: values,
      validator: (v) {
        final liste = v ?? const [];
        if (validator != null) return validator!(liste);
        return isRequired && liste.isEmpty ? 'Champ obligatoire' : null;
      },
      builder: (state) {
        // Synchronise la valeur interne lorsque le parent la change.
        if (!_memes(state.value ?? const [], values)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.mounted && !_memes(state.value ?? const [], values)) {
              state.didChange(values);
            }
          });
        }

        final retenues = [
          for (final v in values) ...options.where((o) => o.value == v),
        ];

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
                          final res = await _ouvrir(context);
                          if (!_memes(res, values)) {
                            onChanged(res);
                            state.didChange(res);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: fillColor ?? AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: state.hasError
                              ? AppColors.error
                              : Colors.transparent,
                          width: state.hasError ? 1.4 : 1),
                    ),
                    child: Row(
                      children: [
                        if (retenues.isNotEmpty) ...[
                          _Pastille(
                              label: retenues.first.label,
                              accent: accent,
                              couleur: retenues.first.couleur),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            retenues.isEmpty
                                ? hint
                                : retenues.map((o) => o.label).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: retenues.isNotEmpty
                                  ? AppColors.dark
                                  : AppColors.hint,
                              fontWeight: retenues.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
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
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  static bool _memes<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Ouvre la feuille et rend la sélection telle qu'elle est à sa fermeture,
  /// quelle que soit la façon de la refermer.
  Future<List<T>> _ouvrir(BuildContext context) async {
    final choix = List<T>.of(values);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MultiSelectSheet<T>(
        options: options,
        choix: choix,
        searchable: searchable ?? options.length > 8,
        accent: accent,
      ),
    );
    return choix;
  }
}

/// Feuille à choix multiple : mêmes poignée, recherche et tuiles que
/// [_SelectSheet], plus « Tout décocher ». Elle coche et décoche directement
/// dans [choix], que le champ relit à la fermeture.
class _MultiSelectSheet<T> extends StatefulWidget {
  final List<SelectOption<T>> options;
  final List<T> choix;
  final bool searchable;
  final Color accent;

  const _MultiSelectSheet({
    required this.options,
    required this.choix,
    required this.searchable,
    required this.accent,
  });

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  final _rechercheCtrl = TextEditingController();
  String _q = '';
  List<T> get _choix => widget.choix;

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  void _basculer(T v) => setState(() {
        if (!_choix.remove(v)) _choix.add(v);
      });

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: TextButton(
                onPressed:
                    _choix.isEmpty ? null : () => setState(_choix.clear),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Tout décocher',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _rechercheCtrl,
                onChanged: (v) => setState(() => _q = v),
                style: TextStyle(fontSize: 14, color: AppColors.dark),
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  hintStyle: TextStyle(color: AppColors.hint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
              ),
            ),
          Flexible(
            child: filtres.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(0, 44, 0, 44 + bottomSafe),
                    child: Text('Aucun résultat',
                        style: TextStyle(color: AppColors.hint, fontSize: 14)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(12, 2, 12, 16 + bottomSafe),
                    itemCount: filtres.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final o = filtres[i];
                      return _TuileOption<T>(
                        option: o,
                        multiple: true,
                        selected: _choix.contains(o.value),
                        accent: accent,
                        onTap: () => _basculer(o.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
