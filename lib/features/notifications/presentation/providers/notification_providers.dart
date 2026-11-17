import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_access_provider.dart';
import '../../../../shared/models/notification_item.dart';
import '../../../../shared/models/notification_priority.dart';
import '../../../applications/presentation/providers/application_providers.dart';
import '../../data/notification_ingest_service.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_filter.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(databaseProvider)),
);

/// The filter currently applied to the inbox.
final inboxFilterProvider =
    NotifierProvider<InboxFilterNotifier, NotificationFilter>(
      InboxFilterNotifier.new,
    );

class InboxFilterNotifier extends Notifier<NotificationFilter> {
  @override
  NotificationFilter build() => NotificationFilter.empty;

  void setQuery(String query) => state = state.copyWith(query: query);

  void togglePackage(String packageName) {
    final next = {...state.packageNames};
    next.contains(packageName)
        ? next.remove(packageName)
        : next.add(packageName);
    state = state.copyWith(packageNames: next);
  }

  void togglePriority(NotificationPriority priority) {
    final next = {...state.priorities};
    next.contains(priority) ? next.remove(priority) : next.add(priority);
    state = state.copyWith(priorities: next);
  }

  void setCategory(int? categoryId) => state = categoryId == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(categoryId: categoryId);

  void setDateRange(DateTime? start, DateTime? end) =>
      state = (start == null && end == null)
      ? state.copyWith(clearDates: true)
      : state.copyWith(start: start, end: end);

  void setOnlyUnread(bool value) => state = state.copyWith(onlyUnread: value);

  void setIncludeArchived(bool value) =>
      state = state.copyWith(includeArchived: value);

  void reset() => state = NotificationFilter.empty;
}

/// Paged inbox contents.
class InboxState {
  const InboxState({
    this.items = const <NotificationItem>[],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<NotificationItem> items;
  final bool hasMore;
  final bool isLoadingMore;

  InboxState copyWith({
    List<NotificationItem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) => InboxState(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// The inbox list, reloaded whenever [inboxFilterProvider] changes.
final inboxProvider = AsyncNotifierProvider<InboxNotifier, InboxState>(
  InboxNotifier.new,
);

class InboxNotifier extends AsyncNotifier<InboxState> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<InboxState> build() async {
    final filter = ref.watch(inboxFilterProvider);
    final items = await _repository.page(
      filter: filter,
      limit: AppConstants.inboxPageSize,
      offset: 0,
    );
    return InboxState(
      items: items,
      hasMore: items.length == AppConstants.inboxPageSize,
    );
  }

  /// Appends the next page to the list.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final next = await _repository.page(
      filter: ref.read(inboxFilterProvider),
      limit: AppConstants.inboxPageSize,
      offset: current.items.length + 1,
    );

    state = AsyncData(
      current.copyWith(
        items: [...current.items, ...next],
        hasMore: next.length == AppConstants.inboxPageSize,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> setRead(int id, {bool isRead = true}) async {
    await _repository.setRead(id, isRead: isRead);
    _patch(id, (item) => item.copyWith(isRead: isRead));
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead(ref.read(inboxFilterProvider));
    ref.invalidateSelf();
    ref.invalidate(unreadCountProvider);
  }

  Future<void> setPriority(int id, NotificationPriority priority) async {
    await _repository.setPriority(id, priority);
    _patch(id, (item) => item.copyWith(priority: priority));
  }

  Future<void> archive(int id) async {
    await _repository.setArchived(id);
    _remove(id);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> snooze(int id, Duration duration) async {
    await _repository.snooze(id, duration);
    _remove(id);
    ref.invalidate(snoozedNotificationsProvider);
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    _remove(id);
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    await _repository.deleteMany(ids);
    final current = state.valueOrNull;
    if (current == null) return;
    final idSet = ids.toSet();
    state = AsyncData(
      current.copyWith(
        items: current.items.where((i) => !idSet.contains(i.id)).toList(),
      ),
    );
  }

  void _patch(int id, NotificationItem Function(NotificationItem) transform) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items
            .map((item) => item.id == id ? transform(item) : item)
            .toList(),
      ),
    );
  }

  void _remove(int id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((item) => item.id != id).toList(),
      ),
    );
  }
}

/// Unread badge shown in the app bar and on the dashboard.
final unreadCountProvider = FutureProvider<int>(
  (ref) => ref.watch(notificationRepositoryProvider).unreadCount(),
);

/// Total number of notifications matching the active filter.
final filteredCountProvider = FutureProvider<int>((ref) {
  final filter = ref.watch(inboxFilterProvider);
  return ref.watch(notificationRepositoryProvider).count(filter: filter);
});

/// Notifications that are currently snoozed, soonest first.
final snoozedNotificationsProvider = FutureProvider<List<NotificationItem>>((
  ref,
) {
  return ref.watch(notificationRepositoryProvider).snoozed();
});

/// A single notification, for the detail screen.
final notificationDetailProvider =
    FutureProvider.family<NotificationItem?, int>((ref, id) {
      return ref.watch(notificationRepositoryProvider).byId(id);
    });

/// All notifications for one application, for the per-app screen.
final notificationsForPackageProvider =
    FutureProvider.family<List<NotificationItem>, String>((ref, packageName) {
      return ref.watch(notificationRepositoryProvider).forPackage(packageName);
    });

/// Runs the capture pipeline for as long as the app is alive.
///
/// Watch this once, high in the widget tree, to start storing notifications as
/// the Android listener delivers them.
final notificationIngestProvider = Provider<NotificationIngestService>((ref) {
  final service = NotificationIngestService(
    access: ref.watch(notificationAccessServiceProvider),
    notifications: ref.watch(notificationRepositoryProvider),
    applications: ref.watch(applicationRepositoryProvider),
    onBatchStored: () {
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(filteredCountProvider);
      ref.invalidate(appSummariesProvider);
      ref.invalidate(appLabelsProvider);
    },
  );
  service.start();
  ref.onDispose(service.stop);
  return service;
});
