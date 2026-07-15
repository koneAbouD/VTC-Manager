import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
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
  final result = await ref.watch(getProfilUseCaseProvider).call();
  return result.fold((f) => throw f.message, (p) => p);
});

final soldeProvider = FutureProvider.autoDispose<Solde>((ref) async {
  final result = await ref.watch(getSoldeUseCaseProvider).call();
  return result.fold((f) => throw f.message, (s) => s);
});
