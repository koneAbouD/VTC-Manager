import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chauffeur.dart';

abstract interface class ChauffeurRepository {
  Future<Either<Failure, List<Chauffeur>>> getChauffeurs();

  Future<Either<Failure, Chauffeur>> getChauffeurById(int id);

  /// Création multipart.
  Future<Either<Failure, Chauffeur>> createChauffeur(
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename,
    Uint8List? photoBytes,
    String photoFilename,
    String? numeroPermis,
    List<String>? typesPermis,
    DateTime? dateEmissionPermis,
    DateTime? dateExpirationPermis,
  });

  /// Mise à jour multipart.
  /// [permisBytes] et [photoBytes] sont optionnels : l'UI ne les fournit que
  /// si l'utilisateur a choisi un nouveau fichier.
  /// [deletePhoto] demande la suppression de la photo existante côté backend.
  Future<Either<Failure, Chauffeur>> updateChauffeur(
    int id,
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename,
    Uint8List? photoBytes,
    String photoFilename,
    bool deletePhoto,
  });

  Future<Either<Failure, void>> deleteChauffeur(int id);
}
