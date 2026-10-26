import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/lecture_avec_cache.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/datasources/compte_remote_datasource.dart';
import '../../data/repositories_impl/compte_repository_impl.dart';
import '../../domain/entities/profil.dart';
import '../../domain/entities/solde.dart';
import '../../domain/repositories/compte_repository.dart';
import '../../domain/usecases/get_profil_usecase.dart';
import '../../domain/usecases/get_solde_usecase.dart';

final _compteDatasourceProvider = Provider<CompteRemoteDatasource>(
  (ref) => CompteRemoteDatasource(ref.watch(apiClientProvider)),
);

final compteRepositoryProvider = Provider<CompteRepository>(
  (ref) => CompteRepositoryImpl(ref.watch(_compteDatasourceProvider)),
);

final getProfilUseCaseProvider = Provider<GetProfilUseCase>(
  (ref) => GetProfilUseCase(ref.watch(compteRepositoryProvider)),
);

final getSoldeUseCaseProvider = Provider<GetSoldeUseCase>(
  (ref) => GetSoldeUseCase(ref.watch(compteRepositoryProvider)),
);

final profilProvider = FutureProvider.autoDispose<Profil>((ref) async {
  final p =
      await lectureAvecCache(ref, ref.watch(getProfilUseCaseProvider).call);
  // Le prénom métier alimente l'écran de code, qui s'affiche avant tout appel
  // réseau : il doit donc être connu à l'avance. C'est la source de vérité,
  // plus fiable que le `given_name` du jeton si le gestionnaire l'a corrigé.
  if (p.prenom.isNotEmpty) {
    unawaited(
      ref.read(authControllerProvider.notifier).saveDisplayName(p.prenom),
    );
  }
  return p;
});

final soldeProvider = FutureProvider.autoDispose<Solde>(
    (ref) => lectureAvecCache(ref, ref.watch(getSoldeUseCaseProvider).call));
