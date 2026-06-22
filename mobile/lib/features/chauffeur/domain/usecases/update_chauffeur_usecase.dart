import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chauffeur.dart';
import '../repositories/chauffeur_repository.dart';

class UpdateChauffeurUseCase {
  final ChauffeurRepository _repository;
  const UpdateChauffeurUseCase(this._repository);

  Future<Either<Failure, Chauffeur>> call(
    int id,
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
    bool deletePhoto = false,
  }) =>
      _repository.updateChauffeur(
        id,
        chauffeur,
        permisBytes: permisBytes,
        permisFilename: permisFilename,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
        deletePhoto: deletePhoto,
      );
}
