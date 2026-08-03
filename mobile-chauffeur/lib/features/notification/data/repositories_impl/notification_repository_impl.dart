import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDatasource _datasource;
  const NotificationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, CentreNotifications>> getCentre() =>
      guard(() => _datasource.getCentre());

  @override
  Future<Either<Failure, Unit>> marquerLue(int id) => guard(() async {
        await _datasource.marquerLue(id);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> marquerToutesLues() => guard(() async {
        await _datasource.marquerToutesLues();
        return unit;
      });
}
