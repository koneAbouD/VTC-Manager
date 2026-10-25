import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
/// Champ de recherche au style des listes recettes/cotisations : fond gris,
/// croix d'effacement dès qu'un mot-clé est saisi. Partagé par les créances et
/// la restitution des cotisations.
class RechercheField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String) onChanged;

  const RechercheField(
      {super.key,
      required this.controller,
      required this.hint,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.search, color: AppColors.hint, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: AppColors.hint, fontSize: 13.5),
              border: InputBorder.none,
              // Le cadre est porté par la boîte grise : sans cela, le thème
              // dessinerait son propre fond et son contour à l'intérieur.
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.hint),
                ),
        ),
      ]),
    );
  }
}
