import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/dashboard_layout_storage.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/domain/dashboard_customization.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';

class DashboardLayoutCustomizationState {
  const DashboardLayoutCustomizationState({
    required this.roleScope,
    required this.entries,
    required this.isEditing,
    required this.isReady,
  });

  final DashboardLayoutRoleScope roleScope;
  final List<DashboardLayoutEntry> entries;
  final bool isEditing;
  final bool isReady;

  factory DashboardLayoutCustomizationState.initial(
    DashboardLayoutRoleScope roleScope,
  ) {
    return DashboardLayoutCustomizationState(
      roleScope: roleScope,
      entries: DashboardCustomizationRegistry.defaultLayoutForRole(roleScope),
      isEditing: false,
      isReady: false,
    );
  }

  DashboardLayoutCustomizationState copyWith({
    List<DashboardLayoutEntry>? entries,
    bool? isEditing,
    bool? isReady,
  }) {
    return DashboardLayoutCustomizationState(
      roleScope: roleScope,
      entries: entries ?? this.entries,
      isEditing: isEditing ?? this.isEditing,
      isReady: isReady ?? this.isReady,
    );
  }

  List<DashboardLayoutEntry> get visibleEntries {
    final items = entries.where((entry) => entry.visible).toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  }
}

abstract class DashboardLayoutCustomizationNotifierBase
    extends Notifier<DashboardLayoutCustomizationState> {
  DashboardLayoutRoleScope get roleScope;

  final DashboardLayoutStorage _storage = DashboardLayoutStorage();
  String? _loadedUid;
  List<DashboardLayoutEntry>? _editingSnapshot;

  String? _currentUid() => ref.read(authSessionProvider).asData?.value?.uid;

  @override
  DashboardLayoutCustomizationState build() {
    ref.listen<AsyncValue<UserRead?>>(
      authSessionProvider,
      (_, __) => unawaited(load()),
      fireImmediately: false,
    );
    Future.microtask(() => unawaited(load()));
    return DashboardLayoutCustomizationState.initial(roleScope);
  }

  Future<void> load() async {
    final current = _safeStateOrNull();
    if (current == null) return;
    final uid = _currentUid();
    if (uid == null || uid.trim().isEmpty) {
      _loadedUid = null;
      state = current.copyWith(
        entries: DashboardCustomizationRegistry.defaultLayoutForRole(
          current.roleScope,
        ),
        isReady: true,
        isEditing: false,
      );
      return;
    }
    if (_loadedUid == uid && current.isReady) return;
    final loaded = await _storage.load(uid: uid, role: current.roleScope);
    final now = _safeStateOrNull();
    if (now == null) return;
    final next = _mergeWithRegistry(loaded?.entries ?? const []);
    _loadedUid = uid;
    state = now.copyWith(
      entries: next,
      isReady: true,
      isEditing: false,
    );
  }

  Future<void> startEditing() async {
    final current = _safeStateOrNull();
    if (current == null) return;
    if (!current.isReady) await load();
    final ready = _safeStateOrNull();
    if (ready == null || !ready.isReady || ready.isEditing) return;
    _editingSnapshot = List<DashboardLayoutEntry>.from(ready.entries);
    state = ready.copyWith(isEditing: true);
  }

  void cancelEditing() {
    if (!state.isEditing) return;
    final snapshot = _editingSnapshot;
    if (snapshot != null) {
      state = state.copyWith(entries: snapshot, isEditing: false);
    } else {
      state = state.copyWith(isEditing: false);
    }
    _editingSnapshot = null;
  }

  Future<void> saveEditing() async {
    if (!state.isEditing) return;
    final normalized = _normalizedEntries(state.entries);
    state =
        state.copyWith(entries: normalized, isEditing: false, isReady: true);
    _editingSnapshot = null;
    await _persistCurrent();
  }

  Future<void> resetToDefault() async {
    final defaults = DashboardCustomizationRegistry.defaultLayoutForRole(
      state.roleScope,
    );
    state = state.copyWith(entries: defaults);
    if (!state.isEditing) {
      await _persistCurrent();
    }
  }

  void reorderVisible(int oldIndex, int newIndex) {
    if (!state.isEditing) return;
    final visible = state.visibleEntries;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    if (newIndex < 0 || newIndex > visible.length) return;
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNew == oldIndex) return;
    final moving = visible.removeAt(oldIndex);
    visible.insert(adjustedNew, moving);

    final orderById = <String, int>{};
    for (var i = 0; i < visible.length; i++) {
      orderById[visible[i].sectionId] = i;
    }
    final rebuilt = state.entries.map((entry) {
      final order = orderById[entry.sectionId];
      if (order == null) return entry;
      return entry.copyWith(order: order);
    }).toList(growable: false);
    state = state.copyWith(entries: _normalizedEntries(rebuilt));
  }

  bool canRemove(String sectionId) {
    final entry = _entryById(sectionId);
    if (entry == null) return false;
    return !entry.pinned;
  }

  bool removeSection(String sectionId) {
    if (!state.isEditing) return false;
    final entry = _entryById(sectionId);
    if (entry == null || entry.pinned || !entry.visible) return false;
    final updated = state.entries.map((current) {
      if (current.sectionId != sectionId) return current;
      return current.copyWith(visible: false);
    }).toList(growable: false);
    state = state.copyWith(entries: _normalizedEntries(updated));
    return true;
  }

  bool addSection(String sectionId) {
    if (!state.isEditing) return false;
    return _setVisible(sectionId, visible: true);
  }

  Future<bool> restoreSection(String sectionId) async {
    final changed = _setVisible(sectionId, visible: true);
    if (!changed) return false;
    if (!state.isEditing) {
      await _persistCurrent();
    }
    return true;
  }

  List<DashboardSectionDefinition> get hiddenAvailableSections {
    final hiddenIds = state.entries
        .where((entry) => !entry.visible)
        .map((entry) => entry.sectionId)
        .toSet();
    return DashboardCustomizationRegistry.sectionsForRole(state.roleScope)
        .where((def) => hiddenIds.contains(def.id))
        .toList(growable: false);
  }

  DashboardLayoutEntry? _entryById(String id) {
    for (final entry in state.entries) {
      if (entry.sectionId == id) return entry;
    }
    return null;
  }

  List<DashboardLayoutEntry> _mergeWithRegistry(
      List<DashboardLayoutEntry> saved) {
    final defs =
        DashboardCustomizationRegistry.sectionsForRole(state.roleScope);
    final validIds = defs.map((def) => def.id).toSet();
    final map = <String, DashboardLayoutEntry>{};

    for (final entry in saved) {
      if (!validIds.contains(entry.sectionId)) continue;
      map[entry.sectionId] = entry;
    }

    for (final def in defs) {
      map.putIfAbsent(
        def.id,
        () => DashboardLayoutEntry(
          sectionId: def.id,
          order: 9999,
          visible: true,
          pinned: def.isRequiredByDefault,
        ),
      );
    }

    final merged = map.values.map((entry) {
      final def = DashboardCustomizationRegistry.byId(entry.sectionId);
      final pinned = def?.isRequiredByDefault == true;
      return entry.copyWith(
        pinned: pinned,
        visible: pinned ? true : entry.visible,
      );
    }).toList(growable: false);
    return _normalizedEntries(merged);
  }

  List<DashboardLayoutEntry> _normalizedEntries(
      List<DashboardLayoutEntry> entries) {
    final sorted = List<DashboardLayoutEntry>.from(entries)
      ..sort((a, b) {
        if (a.visible != b.visible) {
          return a.visible ? -1 : 1;
        }
        return a.order.compareTo(b.order);
      });
    return List<DashboardLayoutEntry>.generate(
      sorted.length,
      (index) {
        final current = sorted[index];
        return current.copyWith(
          order: index,
          visible: current.pinned ? true : current.visible,
        );
      },
      growable: false,
    );
  }

  Future<void> _persistCurrent() async {
    final uid = _currentUid();
    if (uid == null || uid.trim().isEmpty) return;
    final current = _safeStateOrNull();
    if (current == null) return;
    await _storage.save(
      uid: uid,
      settings: DashboardLayoutLocalSettings(
        role: current.roleScope,
        entries: current.entries,
      ),
    );
  }

  bool _setVisible(String sectionId, {required bool visible}) {
    final entry = _entryById(sectionId);
    if (entry == null) return false;
    if (visible == entry.visible) return false;
    if (!visible && entry.pinned) return false;

    final maxOrder = state.entries.fold<int>(
      -1,
      (prev, item) => item.order > prev ? item.order : prev,
    );
    final updated = state.entries.map((current) {
      if (current.sectionId != sectionId) return current;
      return current.copyWith(
        visible: visible,
        order: visible ? (maxOrder + 1) : current.order,
      );
    }).toList(growable: false);
    state = state.copyWith(entries: _normalizedEntries(updated));
    return true;
  }

  DashboardLayoutCustomizationState? _safeStateOrNull() {
    try {
      return state;
    } catch (_) {
      return null;
    }
  }
}

class ManagementDashboardLayoutCustomizationNotifier
    extends DashboardLayoutCustomizationNotifierBase {
  @override
  DashboardLayoutRoleScope get roleScope => DashboardLayoutRoleScope.management;
}

class WorkerDashboardLayoutCustomizationNotifier
    extends DashboardLayoutCustomizationNotifierBase {
  @override
  DashboardLayoutRoleScope get roleScope => DashboardLayoutRoleScope.worker;
}

final managementDashboardLayoutCustomizationProvider = NotifierProvider<
    ManagementDashboardLayoutCustomizationNotifier,
    DashboardLayoutCustomizationState>(
  ManagementDashboardLayoutCustomizationNotifier.new,
);

final workerDashboardLayoutCustomizationProvider = NotifierProvider<
    WorkerDashboardLayoutCustomizationNotifier,
    DashboardLayoutCustomizationState>(
  WorkerDashboardLayoutCustomizationNotifier.new,
);
