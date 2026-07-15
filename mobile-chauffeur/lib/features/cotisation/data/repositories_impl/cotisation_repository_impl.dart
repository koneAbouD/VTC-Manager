import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../../domain/repositories/cotisation_repository.dart';
import '../datasources/cotisation_remote_datasource.dart';

class CotisationRepositoryImpl implements CotisationRepository {
  final CotisationRemoteDatasource _datasource;
  const CotisationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LigneCotisation>>> getCotisations() =>
      guard(() => _datasource.getCotisations());
}
