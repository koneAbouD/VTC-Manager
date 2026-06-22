import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chauffeur.dart';
import '../repositories/chauffeur_repository.dart';

class CreateChauffeurUseCase {
  final ChauffeurRepository _repository;
  const CreateChauffeurUseCase(this._repository);

  Future<Either<Failure, Chauffeur>> call(
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
    String? numeroPermis,
    List<String>? typesPermis,
    DateTime? dateEmissionPermis,
    DateTime? dateExpirationPermis,
  }) =>
      _repository.createChauffeur(
        chauffeur,
        permisBytes: permisBytes,
        permisFilename: permisFilename,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
        numeroPermis: numeroPermis,
        typesPermis: typesPermis,
        dateEmissionPermis: dateEmissionPermis,
        dateExpirationPermis: dateExpirationPermis,
      );
}
