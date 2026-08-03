import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/notification_item.dart';

abstract interface class NotificationRepository {
  Future<Either<Failure, CentreNotifications>> getCentre();

  Future<Either<Failure, Unit>> marquerLue(int id);

  Future<Either<Failure, Unit>> marquerToutesLues();
}
