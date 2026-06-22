import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/programme_travail.dart';

abstract interface class ProgrammeTravailRepository {
  Future<Either<Failure, ProgrammeTravail>> getProgramme(int vehiculeId);
  Future<Either<Failure, ProgrammeTravail>> createProgramme(
    int vehiculeId,
    ProgrammeTravail programme, {
    bool force,
  });
  Future<Either<Failure, ProgrammeTravail>> updateProgramme(
    int vehiculeId,
    ProgrammeTravail programme, {
    bool force,
  });
  Future<Either<Failure, ProgrammeTravail>> invertProgramme(int vehiculeId);
}
