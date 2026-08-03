import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/features/auth/domain/entities/token.dart';
import 'package:vtc_manager/features/auth/domain/repositories/auth_repository.dart';
import 'package:vtc_manager/features/auth/presentation/pages/login_page.dart';
import 'package:vtc_manager/features/auth/presentation/providers/auth_provider.dart';

/// Repository de connexion dont on choisit l'échec : c'est la seule chose que
/// ces tests ont besoin de piloter.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.echec);

  final Failure echec;

  @override
  Future<Either<Failure, Token>> login(String username, String password) async =>
      Left(echec);

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<Either<Failure, Token>> refreshToken() async => Left(echec);

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async =>
      const Right(null);
}

void main() {
  Future<void> ouvrirLogin(WidgetTester tester, Failure echec) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((_) => _FakeAuthRepository(echec)),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
  }

  Future<void> seConnecter(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'akone');
    await tester.enterText(find.byType(TextFormField).last, 'motdepasse');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
  }

  String texte(WidgetTester tester, int index) =>
      tester.widgetList<TextFormField>(find.byType(TextFormField))
          .elementAt(index)
          .controller!
          .text;

  testWidgets(
      'serveur injoignable : le message reste affiché et la saisie est '
      'conservée', (tester) async {
    await ouvrirLogin(
      tester,
      const NetworkFailure('Impossible de joindre le serveur.'),
    );
    await seConnecter(tester);

    expect(find.text('Impossible de joindre le serveur.'), findsOneWidget);
    // Rien n'est de la faute de l'utilisateur : il réessaie d'un seul geste.
    expect(texte(tester, 0), 'akone');
    expect(texte(tester, 1), 'motdepasse');
  });

  testWidgets('identifiants refusés : seul le mot de passe est effacé',
      (tester) async {
    await ouvrirLogin(tester, const AuthFailure('Identifiants invalides.'));
    await seConnecter(tester);

    expect(find.text('Identifiants invalides.'), findsOneWidget);
    expect(texte(tester, 0), 'akone');
    expect(texte(tester, 1), isEmpty);
  });

  testWidgets('une panne du serveur ne montre jamais le message technique',
      (tester) async {
    await ouvrirLogin(
      tester,
      const ServerFailure(
        'Erreur d\'authentification: 400 Bad Request: [{"error":"invalid_grant"}]',
        statusCode: 500,
      ),
    );
    await seConnecter(tester);

    expect(find.textContaining('invalid_grant'), findsNothing);
    expect(
      find.text('Le serveur a rencontré un problème. Réessayez dans un instant.'),
      findsOneWidget,
    );
    expect(texte(tester, 1), 'motdepasse');
  });

  testWidgets('le message s\'efface dès que l\'utilisateur retape',
      (tester) async {
    await ouvrirLogin(tester, const AuthFailure('Identifiants invalides.'));
    await seConnecter(tester);
    expect(find.text('Identifiants invalides.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'nouveau');
    await tester.pumpAndSettle();

    expect(find.text('Identifiants invalides.'), findsNothing);
  });
}
