import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/util/api_endpoint.dart';
import 'package:w0001/util/responsive_layout.dart';

String _onlyDigits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

String _formatKoreanPhone(String raw) {
  final d = _onlyDigits(raw);
  if (d.isEmpty) return '';
  if (d.startsWith('02')) {
    if (d.length <= 2) return d;
    if (d.length <= 5) return '${d.substring(0, 2)}-${d.substring(2)}';
    if (d.length <= 9) {
      return '${d.substring(0, 2)}-${d.substring(2, 5)}-${d.substring(5)}';
    }
    return '${d.substring(0, 2)}-${d.substring(2, 6)}-${d.substring(6, d.length.clamp(6, 10))}';
  }
  if (d.startsWith('0505')) {
    if (d.length <= 4) return d;
    if (d.length <= 7) return '${d.substring(0, 4)}-${d.substring(4)}';
    return '${d.substring(0, 4)}-${d.substring(4, 7)}-${d.substring(7, d.length.clamp(7, 11))}';
  }
  if (d.startsWith('1') && d.length <= 8) {
    if (d.length <= 4) return d;
    return '${d.substring(0, 4)}-${d.substring(4)}';
  }
  if (d.length <= 3) return d;
  if (d.length <= 6) return '${d.substring(0, 3)}-${d.substring(3)}';
  if (d.length == 10) {
    return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
  }
  if (d.length >= 11) {
    final safe = d.substring(0, d.length.clamp(0, 11));
    return '${safe.substring(0, 3)}-${safe.substring(3, 7)}-${safe.substring(7)}';
  }
  return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
}

class KoreanPhoneInputFormatter extends TextInputFormatter {
  const KoreanPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _onlyDigits(newValue.text);
    final formatted = _formatKoreanPhone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class VendorPhoneEntry {
  const VendorPhoneEntry({
    required this.id,
    required this.name,
    required this.phone,
    this.memo = '',
    this.isFavorite,
    required this.updatedAtMs,
  });

  final String id;
  final String name;
  final String phone;
  final String memo;
  final bool? isFavorite;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'phone': phone,
        'memo': memo,
        if (isFavorite != null) 'is_favorite': isFavorite,
        'updated_at_ms': updatedAtMs,
      };

  static VendorPhoneEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    String pick(List<String> keys) {
      for (final key in keys) {
        if (!map.containsKey(key)) continue;
        final value = map[key];
        if (value == null) return '';
        final s = value.toString().trim();
        return s == 'null' ? '' : s;
      }
      return '';
    }

    final id = pick(['id']);
    final name = pick(['name']);
    final phone = pick(['phone_raw', 'phone', 'phone_number', 'contact']);
    final memo = pick(['memo', 'note', 'description']);
    bool? isFavorite;
    final favRaw = map['is_favorite'] ?? map['isFavorite'];
    if (favRaw is bool) {
      isFavorite = favRaw;
    } else if (favRaw is num) {
      isFavorite = favRaw != 0;
    } else if (favRaw is String) {
      final t = favRaw.trim().toLowerCase();
      if (t == 'true' || t == '1') isFavorite = true;
      if (t == 'false' || t == '0') isFavorite = false;
    }
    final updatedAtMs = int.tryParse('${map['updated_at_ms'] ?? ''}') ??
        int.tryParse('${map['updatedAtMs'] ?? ''}') ??
        0;
    if (id.isEmpty || name.isEmpty || phone.isEmpty) return null;
    return VendorPhoneEntry(
      id: id,
      name: name,
      phone: phone,
      memo: memo,
      isFavorite: isFavorite,
      updatedAtMs: updatedAtMs,
    );
  }
}

class VendorPhoneDirectoryStorage {
  static const _prefsKey = 'vendor_phone_directory_v1';
  static const _migrationDoneFlag = 'migration_done_vendor_phone_v1';
  static const _favoritesKeyPrefix = 'vendor_phone_favorites_v1';

  Future<List<VendorPhoneEntry>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const <VendorPhoneEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <VendorPhoneEntry>[];
      final out = <VendorPhoneEntry>[];
      for (final row in decoded) {
        final entry = VendorPhoneEntry.fromJson(row);
        if (entry != null) out.add(entry);
      }
      out.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return out;
    } catch (_) {
      return const <VendorPhoneEntry>[];
    }
  }

  Future<void> clearLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<bool> isMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationDoneFlag) ?? false;
  }

  Future<void> markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationDoneFlag, true);
  }

  Future<Set<String>> readFavorites(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_favoritesKeyPrefix::$uid') ?? const [];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> saveFavorites(String uid, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final list = ids.toList()..sort();
    await prefs.setStringList('$_favoritesKeyPrefix::$uid', list);
  }
}

enum VendorPhoneSortOption {
  nameAsc,
  updatedDesc;

  String get sort =>
      this == VendorPhoneSortOption.nameAsc ? 'name' : 'updated_at';
  String get direction =>
      this == VendorPhoneSortOption.nameAsc ? 'asc' : 'desc';
  String get label => this == VendorPhoneSortOption.nameAsc ? '이름순' : '최신수정순';
}

class VendorPhoneDirectoryScreen extends ConsumerStatefulWidget {
  const VendorPhoneDirectoryScreen({super.key});

  @override
  ConsumerState<VendorPhoneDirectoryScreen> createState() =>
      _VendorPhoneDirectoryScreenState();
}

class _VendorPhoneDirectoryScreenState
    extends ConsumerState<VendorPhoneDirectoryScreen> {
  static const _searchDebounce = Duration(milliseconds: 400);
  static const _pageSize = 30;

  final VendorPhoneDirectoryStorage _storage = VendorPhoneDirectoryStorage();
  final _VendorPhoneContactsRemoteApi _remote =
      _VendorPhoneContactsRemoteApi(AppHttpClient.I);
  final TextEditingController _searchCtrl = TextEditingController();

  Timer? _searchDebounceTimer;
  List<VendorPhoneEntry> _all = const <VendorPhoneEntry>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _saving = false;
  bool _favoritesOnly = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _errorText;
  String _query = '';
  Set<String> _favoriteIds = <String>{};
  VendorPhoneSortOption _sortOption = VendorPhoneSortOption.updatedDesc;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onQueryChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final me = ref.watch(authSessionProvider).asData?.value;
    return me?.role.isAdmin == true;
  }

  Future<void> _bootstrap() async {
    await _loadFavorites();
    await _runLegacyMigrationIfNeeded();
    await _reload(showSpinner: true);
  }

  String get _favoriteScopeUid {
    final uid = ref.read(authSessionProvider).asData?.value?.uid.trim();
    if (uid == null || uid.isEmpty) return 'anonymous';
    return uid;
  }

  Future<void> _loadFavorites() async {
    final ids = await _storage.readFavorites(_favoriteScopeUid);
    if (!mounted) return;
    setState(() => _favoriteIds = ids);
  }

  Future<void> _toggleFavorite(String id) async {
    final wasFavorite = _favoriteIds.contains(id);
    final previous = Set<String>.from(_favoriteIds);
    final optimistic = Set<String>.from(_favoriteIds);
    if (wasFavorite) {
      optimistic.remove(id);
    } else {
      optimistic.add(id);
    }
    setState(() => _favoriteIds = optimistic);
    try {
      await _remote.setFavorite(id: id, isFavorite: !wasFavorite);
      await _storage.saveFavorites(_favoriteScopeUid, optimistic);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favoriteIds = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessageFromException(e))),
      );
    }
  }

  Future<void> _runLegacyMigrationIfNeeded() async {
    if (await _storage.isMigrated()) return;
    final legacy = await _storage.readAll();
    if (legacy.isEmpty) {
      await _storage.markMigrated();
      return;
    }
    try {
      await _remote.list(
        q: '',
        limit: 1,
        cursor: null,
        sort: _sortOption.sort,
        direction: _sortOption.direction,
      );
      await _remote.bulkUpsert(legacy);
      await _storage.clearLegacyData();
      await _storage.markMigrated();
    } catch (_) {
      // 서버가 준비되지 않은 경우 다음 진입 때 재시도.
    }
  }

  void _onQueryChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () async {
      final next = _searchCtrl.text.trim();
      if (_query == next) return;
      _query = next;
      await _reload(showSpinner: false);
    });
  }

  Future<void> _reload({required bool showSpinner}) async {
    await _fetchPage(reset: true, showSpinner: showSpinner);
  }

  Future<void> _fetchPage({
    required bool reset,
    required bool showSpinner,
  }) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        if (showSpinner) _loading = true;
        _errorText = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _errorText = null;
      });
    }

    final cursor = reset ? null : _nextCursor;
    try {
      final page = await _remote.list(
        q: _query,
        limit: _pageSize,
        cursor: cursor,
        sort: _sortOption.sort,
        direction: _sortOption.direction,
      );
      if (!mounted) return;
      final serverFavorite = <String, bool>{};
      for (final row in page.items) {
        if (row.isFavorite != null) {
          serverFavorite[row.id] = row.isFavorite!;
        }
      }
      if (serverFavorite.isNotEmpty) {
        final merged = Set<String>.from(_favoriteIds);
        for (final entry in serverFavorite.entries) {
          if (entry.value) {
            merged.add(entry.key);
          } else {
            merged.remove(entry.key);
          }
        }
        _favoriteIds = merged;
        unawaited(_storage.saveFavorites(_favoriteScopeUid, merged));
      }
      setState(() {
        if (reset) {
          _all = page.items;
        } else {
          final byId = {for (final e in _all) e.id: e};
          for (final row in page.items) {
            byId[row.id] = row;
          }
          _all = byId.values.toList(growable: false);
        }
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!reset && _isCursorSortMismatch(e)) {
        await _fetchPage(reset: true, showSpinner: false);
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorText = '전화번호 목록을 불러오지 못했습니다.\n$e';
      });
    }
  }

  bool _isCursorSortMismatch(Object error) {
    final h = unwrapHttpClientException(error);
    if (h is! HttpStatusException || h.statusCode != 422) return false;
    final body = h.body;
    if (body is! Map) return false;
    final map = Map<String, dynamic>.from(body);
    final detail = map['error'];
    final code = detail is Map
        ? '${detail['code'] ?? ''}'.trim().toUpperCase()
        : '${map['code'] ?? ''}'.trim().toUpperCase();
    return code == 'CURSOR_SORT_MISMATCH';
  }

  Future<void> _changeSort(VendorPhoneSortOption next) async {
    if (_sortOption == next) return;
    setState(() => _sortOption = next);
    await _reload(showSpinner: false);
  }

  Future<_VendorPhoneDraft?> _openEditor({VendorPhoneEntry? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: _formatKoreanPhone(existing?.phone ?? ''));
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    final result = await showModalBottomSheet<_VendorPhoneDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final insets = MediaQuery.viewInsetsOf(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            ctx.rsi(16),
            ctx.rsi(8),
            ctx.rsi(16),
            insets.bottom + ctx.rsi(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? '거래처 추가' : '거래처 수정',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: ctx.rsi(10)),
              AppTextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '거래처명',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: ctx.rsi(8)),
              AppTextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: const [KoreanPhoneInputFormatter()],
                decoration: const InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: ctx.rsi(8)),
              AppTextField(
                controller: memoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: ctx.rsi(12)),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty || phone.isEmpty) return;
                  Navigator.of(ctx).pop(
                    _VendorPhoneDraft(
                      name: name,
                      phone: phone,
                      memo: memoCtrl.text.trim(),
                    ),
                  );
                },
                child: Text(existing == null ? '추가' : '저장'),
              ),
            ],
          ),
        );
      },
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    memoCtrl.dispose();
    return result;
  }

  Future<void> _submitCreate() async {
    final draft = await _openEditor();
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _remote.create(
          name: draft.name, phone: draft.phone, memo: draft.memo);
      await _reload(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessageFromException(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitUpdate(VendorPhoneEntry existing) async {
    final draft = await _openEditor(existing: existing);
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _remote.update(
        id: existing.id,
        name: draft.name,
        phone: draft.phone,
        memo: draft.memo,
      );
      await _reload(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessageFromException(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitDelete(String id) async {
    if (!_canEdit) return;
    setState(() => _saving = true);
    try {
      await _remote.delete(id);
      if (_favoriteIds.contains(id)) {
        final next = Set<String>.from(_favoriteIds)..remove(id);
        _favoriteIds = next;
        await _storage.saveFavorites(_favoriteScopeUid, next);
      }
      await _reload(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessageFromException(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorMessageFromException(Object e) {
    final h = unwrapHttpClientException(e);
    if (h is HttpStatusException && h.body is Map) {
      final body = Map<String, dynamic>.from(h.body as Map);
      final err = body['error'];
      if (err is Map) {
        final msg = '${err['message'] ?? ''}'.trim();
        if (msg.isNotEmpty) return msg;
      }
      final msg = '${body['message'] ?? ''}'.trim();
      if (msg.isNotEmpty) return msg;
    }
    return '요청을 처리하지 못했습니다.\n$e';
  }

  Future<void> _copyPhone(String phoneRaw) async {
    final formatted = _formatKoreanPhone(phoneRaw);
    final text = formatted.isEmpty ? phoneRaw : formatted;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _openDialer(String phoneRaw) async {
    final digits = _onlyDigits(phoneRaw);
    if (digits.isEmpty) return;
    final ok = await launchUrl(
      Uri(scheme: 'tel', path: digits),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화 앱을 열 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = _all.where((e) {
      if (!_favoritesOnly) return true;
      return _favoriteIds.contains(e.id);
    }).toList(growable: false)
      ..sort((a, b) {
        final af = _favoriteIds.contains(a.id);
        final bf = _favoriteIds.contains(b.id);
        if (af != bf) return af ? -1 : 1;
        return 0;
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('공용 거래처 전화번호'),
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: (_loading || _saving) ? null : _submitCreate,
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AppRefreshIndicator(
              onRefresh: () => _reload(showSpinner: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  context.rsi(12),
                  context.rsi(16),
                  context.rsi(90),
                ),
                children: [
                  AppTextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: '거래처명/전화번호 검색',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: context.rsi(10)),
                  Wrap(
                    spacing: context.rsi(8),
                    children: VendorPhoneSortOption.values
                        .map(
                          (e) => ChoiceChip(
                            label: Text(e.label),
                            selected: _sortOption == e,
                            onSelected: (_) => _changeSort(e),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  SizedBox(height: context.rsi(8)),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(context.rsi(14)),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    padding: EdgeInsets.all(context.rsi(4)),
                    child: Row(
                      children: [
                        Expanded(
                          child: _favoriteFilterButton(
                            context,
                            icon: Icons.format_list_bulleted_rounded,
                            label: '전체',
                            countLabel: '${_all.length}',
                            selected: !_favoritesOnly,
                            onTap: () => setState(() => _favoritesOnly = false),
                          ),
                        ),
                        SizedBox(width: context.rsi(6)),
                        Expanded(
                          child: _favoriteFilterButton(
                            context,
                            icon: Icons.star_rounded,
                            label: '즐겨찾기',
                            countLabel: '${_favoriteIds.length}',
                            selected: _favoritesOnly,
                            onTap: () => setState(() => _favoritesOnly = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rsi(10)),
                  if (_errorText != null && rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(context.rsi(16)),
                      child: Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error),
                      ),
                    )
                  else if (rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(context.rsi(16)),
                      child: Text(
                        _favoritesOnly ? '즐겨찾기한 거래처가 없습니다.' : '등록된 거래처가 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  else
                    ...rows.map(
                      (e) => Card(
                        margin: EdgeInsets.only(bottom: context.rsi(8)),
                        child: ListTile(
                          leading: IconButton(
                            tooltip: _favoriteIds.contains(e.id)
                                ? '즐겨찾기 해제'
                                : '즐겨찾기',
                            onPressed: () => _toggleFavorite(e.id),
                            icon: Icon(
                              _favoriteIds.contains(e.id)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: _favoriteIds.contains(e.id)
                                  ? const Color(0xFFFFB300)
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            e.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: context.rsi(2)),
                              Text(_formatKoreanPhone(e.phone)),
                              if (e.memo.isNotEmpty) ...[
                                SizedBox(height: context.rsi(2)),
                                Text(
                                  e.memo,
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'call') {
                                await _openDialer(e.phone);
                                return;
                              }
                              if (v == 'copy') {
                                await _copyPhone(e.phone);
                                return;
                              }
                              if (v == 'edit') {
                                await _submitUpdate(e);
                                return;
                              }
                              if (v == 'delete') {
                                await _submitDelete(e.id);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'call', child: Text('전화 걸기')),
                              const PopupMenuItem(
                                  value: 'copy', child: Text('번호 복사')),
                              if (_canEdit)
                                const PopupMenuItem(
                                    value: 'edit', child: Text('수정')),
                              if (_canEdit)
                                const PopupMenuItem(
                                    value: 'delete', child: Text('삭제')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_hasMore) ...[
                    SizedBox(height: context.rsi(8)),
                    Center(
                      child: FilledButton.tonal(
                        onPressed: _loadingMore || _saving
                            ? null
                            : () => _fetchPage(
                                  reset: false,
                                  showSpinner: false,
                                ),
                        child: _loadingMore
                            ? const Text('불러오는 중...')
                            : const Text('더 불러오기'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _favoriteFilterButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String countLabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedBg = cs.primaryContainer.withValues(alpha: 0.92);
    final selectedFg = cs.onPrimaryContainer;
    final normalBg = cs.surface;
    final normalFg = cs.onSurfaceVariant;
    return Material(
      color: selected ? selectedBg : normalBg,
      borderRadius: BorderRadius.circular(context.rsi(11)),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rsi(11)),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(8),
            vertical: context.rsi(9),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rsi(11)),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.52)
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: context.rsi(16),
                color: selected ? selectedFg : normalFg,
              ),
              SizedBox(width: context.rsi(6)),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? selectedFg : normalFg,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(6),
                  vertical: context.rsi(2),
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? selectedFg.withValues(alpha: 0.16)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countLabel,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? selectedFg : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorPhoneContactsRemoteApi {
  const _VendorPhoneContactsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<_VendorPhonePage> list({
    required String q,
    required int limit,
    required String? cursor,
    required String sort,
    required String direction,
  }) async {
    final qp = <String, dynamic>{
      'q': q.trim(),
      'limit': limit,
      'sort': sort,
      'direction': direction,
    };
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) qp['cursor'] = c;
    final res = await _http.get<dynamic>(
      ApiEndpoint.vendorPhoneContacts,
      queryParameters: qp,
    );
    return _VendorPhonePage.fromResponse(res.data);
  }

  Future<void> create({
    required String name,
    required String phone,
    required String memo,
  }) async {
    final payloads = _writePayloads(name: name, phone: phone, memo: memo);
    await _requestWithFallback(
      () => _http.post<dynamic>(
        ApiEndpoint.vendorPhoneContacts,
        data: payloads.first,
      ),
      onFallback: () => _http.post<dynamic>(
        ApiEndpoint.vendorPhoneContacts,
        data: payloads.last,
      ),
    );
  }

  Future<void> update({
    required String id,
    required String name,
    required String phone,
    required String memo,
  }) async {
    final payloads = _writePayloads(name: name, phone: phone, memo: memo);
    await _requestWithFallback(
      () => _http.patch<dynamic>(
        ApiEndpoint.vendorPhoneContactById(id),
        data: payloads.first,
      ),
      onFallback: () => _http.patch<dynamic>(
        ApiEndpoint.vendorPhoneContactById(id),
        data: payloads.last,
      ),
    );
  }

  Future<void> delete(String id) async {
    await _http.delete<dynamic>(ApiEndpoint.vendorPhoneContactById(id));
  }

  Future<void> setFavorite({
    required String id,
    required bool isFavorite,
  }) async {
    if (isFavorite) {
      await _http.post<dynamic>(ApiEndpoint.vendorPhoneContactFavorite(id));
      return;
    }
    await _http.delete<dynamic>(ApiEndpoint.vendorPhoneContactFavorite(id));
  }

  Future<void> bulkUpsert(List<VendorPhoneEntry> rows) async {
    await _http.post<dynamic>(
      ApiEndpoint.vendorPhoneContactsBulkUpsert,
      data: <String, dynamic>{
        'items': rows
            .map(
              (e) => <String, dynamic>{
                'name': e.name,
                'phone_raw': e.phone.trim(),
                'memo': e.memo.trim(),
              },
            )
            .toList(growable: false),
      },
    );
  }

  List<Map<String, dynamic>> _writePayloads({
    required String name,
    required String phone,
    required String memo,
  }) {
    final raw = phone.trim();
    final digits = _onlyDigits(raw);
    final fallbackPhone = digits.isEmpty ? raw : digits;
    final cleanMemo = memo.trim();
    return [
      {
        'name': name.trim(),
        'phone_raw': raw,
        'memo': cleanMemo,
      },
      {
        'name': name.trim(),
        'phone_raw': fallbackPhone,
        'memo': cleanMemo,
      },
    ];
  }

  Future<void> _requestWithFallback(
    Future<void> Function() request, {
    required Future<void> Function() onFallback,
  }) async {
    try {
      await request();
    } catch (e) {
      final h = unwrapHttpClientException(e);
      if (h is HttpStatusException && h.statusCode == 422) {
        await onFallback();
        return;
      }
      rethrow;
    }
  }
}

class _VendorPhonePage {
  const _VendorPhonePage({
    required this.items,
    required this.nextCursor,
  });

  final List<VendorPhoneEntry> items;
  final String? nextCursor;

  static _VendorPhonePage fromResponse(dynamic data) {
    if (data is Map) {
      final top = Map<String, dynamic>.from(data);
      final one = top['item'];
      if (one is Map) {
        final row = VendorPhoneEntry.fromJson(one);
        return _VendorPhonePage(
          items: row == null ? const [] : <VendorPhoneEntry>[row],
          nextCursor: null,
        );
      }
    }
    if (data is List) {
      final rows = data
          .map(VendorPhoneEntry.fromJson)
          .whereType<VendorPhoneEntry>()
          .toList(growable: false);
      return _VendorPhonePage(items: rows, nextCursor: null);
    }
    if (data is! Map) {
      return const _VendorPhonePage(items: [], nextCursor: null);
    }
    final root = Map<String, dynamic>.from(data);
    final body = _unwrapContainer(root);
    final rawItems = body['items'] ?? body['contacts'] ?? body['data'];
    final rows = rawItems is List
        ? rawItems
            .map(VendorPhoneEntry.fromJson)
            .whereType<VendorPhoneEntry>()
            .toList(growable: false)
        : const <VendorPhoneEntry>[];
    final cursor = _toStr(body['next_cursor'] ?? body['nextCursor']);
    return _VendorPhonePage(items: rows, nextCursor: cursor);
  }

  static Map<String, dynamic> _unwrapContainer(Map<String, dynamic> root) {
    if (root['items'] is List || root['contacts'] is List) return root;
    final data = root['data'];
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      if (m['items'] is List || m['contacts'] is List) return m;
    }
    final result = root['result'];
    if (result is Map) {
      final m = Map<String, dynamic>.from(result);
      if (m['items'] is List || m['contacts'] is List) return m;
    }
    return root;
  }

  static String? _toStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

class _VendorPhoneDraft {
  const _VendorPhoneDraft({
    required this.name,
    required this.phone,
    required this.memo,
  });

  final String name;
  final String phone;
  final String memo;
}
