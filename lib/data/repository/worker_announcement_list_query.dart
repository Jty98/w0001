import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';

typedef WorkerAnnouncementListQueryParams = ({
  WorkerAnnouncementScope? scope,
  int? pcomplete,
});

WorkerAnnouncementListQueryParams resolveWorkerAnnouncementListQuery({
  int? placeId,
  WorkerAnnouncementPagedScopeFilter scopeFilter =
      WorkerAnnouncementPagedScopeFilter.all,
  int? placeComplete,
}) {
  final WorkerAnnouncementScope? scope;
  if (placeId != null) {
    scope = WorkerAnnouncementScope.place;
  } else {
    scope = switch (scopeFilter) {
      WorkerAnnouncementPagedScopeFilter.globalOnly =>
        WorkerAnnouncementScope.global,
      WorkerAnnouncementPagedScopeFilter.placeOnly =>
        WorkerAnnouncementScope.place,
      WorkerAnnouncementPagedScopeFilter.all => null,
    };
  }

  int? pcomplete;
  if (scope == WorkerAnnouncementScope.global) {
    pcomplete = null;
  } else if (placeId != null || scope == WorkerAnnouncementScope.place) {
    pcomplete = placeComplete ?? 0;
  }

  return (scope: scope, pcomplete: pcomplete);
}
