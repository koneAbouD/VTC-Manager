import 'package:flutter/material.dart';

/// Largeur en dessous de laquelle on considère être sur un téléphone :
/// les paires de champs passent alors en pleine largeur, un champ par ligne.
const double kFormPhoneBreakpoint = 600;

/// Dispose deux champs de formulaire côte à côte sur tablette / grand écran,
/// et les empile (un par ligne) sur téléphone.
///
/// Remplace le motif :
/// `Row(children: [Expanded(child: a), SizedBox(width: gap), Expanded(child: b)])`
class ResponsiveFieldRow extends StatelessWidget {
  final Widget left;

  /// Second champ. Optionnel : s'il est `null`, `left` occupe toute la largeur
  /// (utile pour les paires conditionnelles).
  final Widget? right;

  /// Espace horizontal entre les deux champs (mode rangée).
  final double gap;

  /// Espace vertical entre les deux champs (mode empilé téléphone).
  final double stackedGap;

  /// Facteurs de répartition en mode rangée (ignorés sur téléphone).
  final int leftFlex;
  final int rightFlex;

  const ResponsiveFieldRow({
    super.key,
    required this.left,
    this.right,
    this.gap = 10,
    this.stackedGap = 12,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (right == null) return left;

    final isPhone = MediaQuery.sizeOf(context).width < kFormPhoneBreakpoint;

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: stackedGap),
          right!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        SizedBox(width: gap),
        Expanded(flex: rightFlex, child: right!),
      ],
    );
  }
}
