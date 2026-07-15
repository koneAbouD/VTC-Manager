import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/paiement_remote_datasource.dart';
import '../../data/repositories_impl/paiement_repository_impl.dart';
import '../../domain/repositories/paiement_repository.dart';
import '../../domain/usecases/get_statut_paiement_usecase.dart';
import '../../domain/usecases/initier_paiement_usecase.dart';

final _paiementDatasourceProvider = Provider<PaiementRemoteDatasource>(
  (ref) => PaiementRemoteDatasource(ref.watch(apiClientProvider)),
);

final paiementRepositoryProvider = Provider<PaiementRepository>(
  (ref) => PaiementRepositoryImpl(ref.watch(_paiementDatasourceProvider)),
);

final initierPaiementUseCaseProvider = Provider<InitierPaiementUseCase>(
  (ref) => InitierPaiementUseCase(ref.watch(paiementRepositoryProvider)),
);

final getStatutPaiementUseCaseProvider = Provider<GetStatutPaiementUseCase>(
  (ref) => GetStatutPaiementUseCase(ref.watch(paiementRepositoryProvider)),
);
