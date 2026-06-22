import 'package:flutter/material.dart';

import '../../features/operation_financiere/presentation/pages/operations_financieres_page.dart';

/// Onglet "Finances" — délègue à OperationsFinancieresPage.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OperationsFinancieresPage();
  }
}
