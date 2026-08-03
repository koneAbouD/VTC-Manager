import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/notification_item.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  final NotificationRepository _repository;
  const GetNotificationsUseCase(this._repository);

  Future<Either<Failure, CentreNotifications>> call() => _repository.getCentre();
}

class MarquerNotificationLueUseCase {
  final NotificationRepository _repository;
  const MarquerNotificationLueUseCase(this._repository);

  Future<Either<Failure, Unit>> call(int id) => _repository.marquerLue(id);

  Future<Either<Failure, Unit>> toutes() => _repository.marquerToutesLues();
}
