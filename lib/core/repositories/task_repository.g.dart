// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskRepository)
final taskRepositoryProvider = TaskRepositoryProvider._();

final class TaskRepositoryProvider
    extends $FunctionalProvider<TaskRepository, TaskRepository, TaskRepository>
    with $Provider<TaskRepository> {
  TaskRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'taskRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskRepository create(Ref ref) {
    return taskRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskRepository>(value),
    );
  }
}

String _$taskRepositoryHash() => r'e049b86d616e43c22c92039019b3c3e97ea807ab';

@ProviderFor(activeTasksConfig)
final activeTasksConfigProvider = ActiveTasksConfigProvider._();

final class ActiveTasksConfigProvider extends $FunctionalProvider<
        AsyncValue<List<Task>>, List<Task>, FutureOr<List<Task>>>
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
  ActiveTasksConfigProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'activeTasksConfigProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$activeTasksConfigHash();

  @$internal
  @override
  $FutureProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Task>> create(Ref ref) {
    return activeTasksConfig(ref);
  }
}

String _$activeTasksConfigHash() => r'e5f0817e06cc56e22adc8f91c95858389a5fe22e';

@ProviderFor(allTasksStream)
final allTasksStreamProvider = AllTasksStreamProvider._();

final class AllTasksStreamProvider extends $FunctionalProvider<
        AsyncValue<List<Task>>, List<Task>, Stream<List<Task>>>
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  AllTasksStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'allTasksStreamProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$allTasksStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return allTasksStream(ref);
  }
}

String _$allTasksStreamHash() => r'e6fa62f23a39862e103a93c445b5029fd72f087f';

@ProviderFor(userNotifications)
final userNotificationsProvider = UserNotificationsProvider._();

final class UserNotificationsProvider extends $FunctionalProvider<
        AsyncValue<List<Notification>>,
        List<Notification>,
        Stream<List<Notification>>>
    with
        $FutureModifier<List<Notification>>,
        $StreamProvider<List<Notification>> {
  UserNotificationsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'userNotificationsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$userNotificationsHash();

  @$internal
  @override
  $StreamProviderElement<List<Notification>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Notification>> create(Ref ref) {
    return userNotifications(ref);
  }
}

String _$userNotificationsHash() => r'b1bcee306cec25deed8ad6d91b03c87a882e8ba6';
