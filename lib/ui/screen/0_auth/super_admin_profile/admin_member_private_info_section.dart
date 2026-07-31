import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_private_info_form_body.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/copyable_display.dart';
import 'package:w0001/util/human_contact_display.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 회원·비회원 공통 세무·정산 정보 (보기/수정 분리, 작업자 설정 UI).
class AdminMemberPrivateInfoSection extends ConsumerStatefulWidget {
  AdminMemberPrivateInfoSection({
    super.key,
    this.workerUid,
    this.human,
  }) : assert(
          workerUid != null || (human?.hid != null && human!.hid! > 0),
          'workerUid 또는 human(hid) 중 하나는 필요합니다.',
        );

  final String? workerUid;
  final HumanModel? human;

  @override
  ConsumerState<AdminMemberPrivateInfoSection> createState() =>
      _AdminMemberPrivateInfoSectionState();
}

class _AdminMemberPrivateInfoSectionState
    extends ConsumerState<AdminMemberPrivateInfoSection> {
  UserPrivateRead? _workerPrivate;
  HumanPrivateRead? _humanPrivate;
  Object? _loadError;
  var _loading = false;
  var _revealingRrn = false;
  var _revealingBank = false;
  var _revealingHphone = false;
  var _revealingLinkedPhone = false;
  String? _revealedRrn;
  String? _revealedBank;
  String? _revealedHphone;
  String? _revealedLinkedPhone;
  var _isEditMode = false;
  var _saving = false;
  var _initialized = false;

  final _rrnFrontController = TextEditingController();
  final _rrnBackController = TextEditingController();
  final _rrnFrontFocusNode = FocusNode();
  final _rrnBackFocusNode = FocusNode();
  final _bankAccountController = TextEditingController();
  final _bankOwnerController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _hphoneController = TextEditingController();
  final _linkedPhoneController = TextEditingController();

  int? get _hid {
    final id = widget.human?.hid;
    return id != null && id > 0 ? id : null;
  }

  String? get _linkedUid {
    final uid = widget.human?.uid?.trim();
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  bool get _usesWorkerApi => widget.workerUid?.trim().isNotEmpty == true;

  bool get _canReveal =>
      ref
          .read(authSessionProvider)
          .asData
          ?.value
          ?.role
          .canRevealWorkerPrivateInfo ==
      true;

  String get _currentRrn => joinResidentRegistrationParts(
        _rrnFrontController.text,
        _rrnBackController.text,
      );

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _rrnFrontController.dispose();
    _rrnBackController.dispose();
    _rrnFrontFocusNode.dispose();
    _rrnBackFocusNode.dispose();
    _bankAccountController.dispose();
    _bankOwnerController.dispose();
    _bankNameController.dispose();
    _hphoneController.dispose();
    _linkedPhoneController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdminMemberPrivateInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workerUid != widget.workerUid ||
        oldWidget.human?.hid != widget.human?.hid) {
      _workerPrivate = null;
      _humanPrivate = null;
      _revealedRrn = null;
      _revealedBank = null;
      _revealedHphone = null;
      _revealedLinkedPhone = null;
      _loadError = null;
      _initialized = false;
      _isEditMode = false;
      Future.microtask(_load);
    }
  }

  UserPrivateRead _displayPrivate() {
    if (_usesWorkerApi && _workerPrivate != null) return _workerPrivate!;
    if (_humanPrivate != null) return _humanToUserPrivate(_humanPrivate!);
    return const UserPrivateRead();
  }

  UserPrivateRead _humanToUserPrivate(HumanPrivateRead h) => UserPrivateRead(
        rrnMasked: h.rrnMasked,
        bankAccountMasked: h.bankAccountMasked,
        bankOwner: h.bankOwner,
        bankName: h.bankName,
        hasRrn: h.hasRrn,
        hasBankAccount: h.hasBankAccount,
      );

  void _setRrnDisplay(String display) {
    final (front, back) = splitResidentRegistrationDisplay(display);
    _rrnFrontController.text = front;
    _rrnBackController.text = back;
  }

  void _initializeForm() {
    final private = _displayPrivate();
    _bankOwnerController.text = private.bankOwner ?? '';
    _bankNameController.text = private.bankName ?? '';

    final rrnDisplay = _revealedRrn ?? private.rrnMasked ?? '';
    _setRrnDisplay(rrnDisplay);

    _bankAccountController.text =
        _revealedBank ?? private.bankAccountMasked ?? '';

    final humanPrivate = _humanPrivate;
    _hphoneController.text = _revealedHphone ??
        humanPrivate?.hphoneMasked ??
        widget.human?.hphone ??
        '';
    _linkedPhoneController.text = _revealedLinkedPhone ??
        humanPrivate?.linkedPhoneMasked ??
        widget.human?.linkedPhone ??
        '';

    _initialized = true;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      UserPrivateRead? workerPrivate;
      HumanPrivateRead? humanPrivate;

      if (_usesWorkerApi) {
        workerPrivate = await ref
            .read(userPrivateUseCaseProvider)
            .getWorkerPrivate(widget.workerUid!.trim());
      }

      final hid = _hid;
      if (hid != null) {
        try {
          humanPrivate =
              await ref.read(humanUseCaseProvider).getHumanPrivate(hid);
        } catch (_) {
          final h = widget.human;
          if (h != null) {
            humanPrivate = HumanPrivateRead.fromHumanFields(
              hnumber: h.hnumber,
              hphone: h.hphone,
              linkedPhone: h.linkedPhone,
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _workerPrivate = workerPrivate;
        _humanPrivate = humanPrivate;
        _loading = false;
        _initialized = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _revealRrn() async {
    if (!_canReveal || _revealingRrn) return;
    setState(() => _revealingRrn = true);
    try {
      String value;
      if (_usesWorkerApi) {
        value = await ref.read(userPrivateUseCaseProvider).revealWorkerRrn(
              uid: widget.workerUid!.trim(),
              reason: '관리자 조회',
            );
      } else {
        final hid = _hid!;
        value = await ref.read(humanUseCaseProvider).revealHumanRrn(
              hid: hid,
              reason: '관리자 조회',
            );
      }
      if (!mounted) return;
      setState(() {
        _revealedRrn = formatResidentRegistrationDisplay(value);
        _setRrnDisplay(_revealedRrn!);
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '주민등록번호 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingRrn = false);
    }
  }

  Future<void> _revealBank() async {
    if (!_canReveal || _revealingBank) return;
    setState(() => _revealingBank = true);
    try {
      String value;
      if (_usesWorkerApi) {
        value =
            await ref.read(userPrivateUseCaseProvider).revealWorkerBankAccount(
                  uid: widget.workerUid!.trim(),
                  reason: '관리자 조회',
                );
      } else {
        value = await ref.read(humanUseCaseProvider).revealHumanBankAccount(
              hid: _hid!,
              reason: '관리자 조회',
            );
      }
      if (!mounted) return;
      setState(() {
        _revealedBank = value;
        _bankAccountController.text = value;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '계좌번호 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingBank = false);
    }
  }

  Future<void> _revealHphone() async {
    final hid = _hid;
    if (hid == null || !_canReveal || _revealingHphone) return;
    setState(() => _revealingHphone = true);
    try {
      final value = await ref.read(humanUseCaseProvider).revealHumanHphone(
            hid: hid,
            reason: '관리자 조회',
          );
      if (!mounted) return;
      final formatted = formatKoreanMobilePhoneDisplay(value);
      setState(() {
        _revealedHphone = formatted;
        _hphoneController.text = formatted;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '연락처 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingHphone = false);
    }
  }

  Future<void> _revealLinkedPhone() async {
    final hid = _hid;
    if (hid == null || !_canReveal || _revealingLinkedPhone) return;
    setState(() => _revealingLinkedPhone = true);
    try {
      String value;
      final uid = _linkedUid;
      if (uid != null) {
        try {
          value = await ref.read(userPrivateUseCaseProvider).revealWorkerPhone(
                uid: uid,
                reason: '관리자 조회',
              );
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
          value = await ref
              .read(humanUseCaseProvider)
              .revealHumanLinkedPhone(hid: hid, reason: '관리자 조회');
        }
      } else {
        value = await ref.read(humanUseCaseProvider).revealHumanLinkedPhone(
              hid: hid,
              reason: '관리자 조회',
            );
      }
      if (!mounted) return;
      final formatted =
          isMaskedPhone(value) ? value : formatKoreanMobilePhoneDisplay(value);
      setState(() {
        _revealedLinkedPhone = formatted;
        _linkedPhoneController.text = formatted;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '인증 연락처 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingLinkedPhone = false);
    }
  }

  void _startEdit() => setState(() => _isEditMode = true);

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _initialized = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final rrn = _currentRrn.trim();
      final account = _bankAccountController.text.trim();
      final owner = _bankOwnerController.text.trim();
      final bank = _bankNameController.text.trim();
      final hphone = _hphoneController.text.trim();

      if (_usesWorkerApi) {
        final updated =
            await ref.read(userPrivateUseCaseProvider).saveWorkerPrivate(
                  uid: widget.workerUid!.trim(),
                  rrn: rrn.contains('*') ? null : (rrn.isEmpty ? null : rrn),
                  bankAccount: account.contains('*')
                      ? null
                      : (account.isEmpty ? null : account),
                  bankOwner: owner.isEmpty ? null : owner,
                  bankName: bank.isEmpty ? null : bank,
                );
        _workerPrivate = updated;
      }

      final hid = _hid;
      if (hid != null) {
        if (!_usesWorkerApi) {
          final humanUpdated =
              await ref.read(humanUseCaseProvider).saveHumanPrivate(
                    hid: hid,
                    rrn: rrn.contains('*') ? null : (rrn.isEmpty ? null : rrn),
                    bankAccount: account.contains('*')
                        ? null
                        : (account.isEmpty ? null : account),
                    bankOwner: owner.isEmpty ? null : owner,
                    bankName: bank.isEmpty ? null : bank,
                    hphone: hphone.contains('*')
                        ? null
                        : (hphone.isEmpty ? null : hphone),
                  );
          _humanPrivate = humanUpdated;
        } else if (!hphone.contains('*')) {
          final humanUpdated =
              await ref.read(humanUseCaseProvider).saveHumanPrivate(
                    hid: hid,
                    hphone: hphone.isEmpty ? null : hphone,
                  );
          _humanPrivate = humanUpdated;
        }
      }

      if (!mounted) return;
      setState(() {
        _revealedRrn = null;
        _revealedBank = null;
        _revealedHphone = null;
        _revealedLinkedPhone = null;
        _isEditMode = false;
        _initialized = false;
        _saving = false;
      });
      _toast('세무·정산 정보를 저장했습니다.');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '저장에 실패했습니다.');
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
      setState(() => _saving = false);
    }
  }

  Widget? _revealButton({
    required bool canRevealField,
    required bool revealing,
    required bool isRevealed,
    required VoidCallback onReveal,
    String? revealedValue,
    required String label,
  }) {
    if (!_canReveal || !canRevealField || isRevealed) {
      if (isRevealed &&
          revealedValue != null &&
          isCopyableDisplayValue(revealedValue)) {
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          tooltip: '복사',
          onPressed: () => copyDisplayValue(
            context,
            label: label,
            value: revealedValue,
          ),
          icon: Icon(Icons.copy_rounded, size: context.rs(18)),
        );
      }
      return null;
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      tooltip: '전체 보기',
      onPressed: revealing ? null : onReveal,
      icon: revealing
          ? SizedBox(
              width: context.rs(18),
              height: context.rs(18),
              child: const HammerLoadingIndicator(size: 24),
            )
          : Icon(Icons.visibility_outlined, size: context.rs(20)),
    );
  }

  bool get _showPhoneFields {
    if (_hid == null) return false;
    if (_isEditMode) return true;
    final hp = _humanPrivate;
    return _isEditMode ||
        hp?.hasHphone == true ||
        hp?.hasLinkedPhone == true ||
        _hphoneController.text.trim().isNotEmpty ||
        _linkedPhoneController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fieldHeight = context.rsi(54);

    if (_loading) {
      return Skeletonizer(
        enabled: true,
        child: ProfileInsetPanel(
          padding: EdgeInsets.all(context.rsi(12)),
          child: WorkerPrivateInfoFormBody(
            isEditMode: false,
            private: const UserPrivateRead(
              rrnMasked: '******-*******',
              bankAccountMasked: '****1234',
              bankOwner: '홍길동',
              bankName: '국민은행',
              hasRrn: true,
              hasBankAccount: true,
            ),
            rrnFrontController: _rrnFrontController,
            rrnBackController: _rrnBackController,
            bankAccountController: _bankAccountController,
            bankOwnerController: _bankOwnerController,
            bankNameController: _bankNameController,
            onChanged: (_) {},
            showTaxTerms: false,
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Material(
        color: cs.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(context.rsi(14)),
        child: Padding(
          padding: EdgeInsets.all(context.rsi(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '세무·정산 정보를 불러오지 못했습니다.',
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
              SizedBox(height: context.rsi(8)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      _initializeForm();
    }

    final private = _displayPrivate();
    final humanPrivate = _humanPrivate;
    final anyRevealed = _revealedRrn != null ||
        _revealedBank != null ||
        _revealedHphone != null ||
        _revealedLinkedPhone != null;

    return ProfileInsetPanel(
      padding: EdgeInsets.all(context.rsi(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (anyRevealed && !_isEditMode)
            Padding(
              padding: EdgeInsets.only(bottom: context.rsi(8)),
              child: Text(
                '전체 조회됨 · 화면을 닫으면 다시 마스킹됩니다.',
                style: tt.labelSmall?.copyWith(color: cs.error),
              ),
            ),
          WorkerPrivateInfoFormBody(
            isEditMode: _isEditMode,
            private: private,
            rrnFrontController: _rrnFrontController,
            rrnBackController: _rrnBackController,
            rrnFrontFocusNode: _rrnFrontFocusNode,
            rrnBackFocusNode: _rrnBackFocusNode,
            bankAccountController: _bankAccountController,
            bankOwnerController: _bankOwnerController,
            bankNameController: _bankNameController,
            onChanged: (_) => setState(() {}),
            showTaxTerms: false,
            rrnViewTrailing: !_isEditMode
                ? _revealButton(
                    canRevealField: private.hasRrn,
                    revealing: _revealingRrn,
                    isRevealed: _revealedRrn != null,
                    onReveal: _revealRrn,
                    revealedValue: _revealedRrn,
                    label: '주민등록번호',
                  )
                : null,
            bankViewTrailing: !_isEditMode
                ? _revealButton(
                    canRevealField: private.hasBankAccount,
                    revealing: _revealingBank,
                    isRevealed: _revealedBank != null,
                    onReveal: _revealBank,
                    revealedValue: _revealedBank,
                    label: '계좌번호',
                  )
                : null,
          ),
          if (_showPhoneFields) ...[
            SizedBox(height: context.rsi(16)),
            RoundTextField(
              controller: _hphoneController,
              keyboardType: TextInputType.phone,
              labelText: kHumanManualPhoneLabel,
              height: fieldHeight,
              showClearButton: _isEditMode,
              enabled: _isEditMode,
              suffixIcon: !_isEditMode
                  ? _revealButton(
                      canRevealField: humanPrivate?.hasHphone == true,
                      revealing: _revealingHphone,
                      isRevealed: _revealedHphone != null,
                      onReveal: _revealHphone,
                      revealedValue: _revealedHphone,
                      label: kHumanManualPhoneLabel,
                    )
                  : null,
              suffixTrailingWidth: context.rsi(36),
              inputFormatters:
                  _isEditMode ? [FilteringTextInputFormatter.digitsOnly] : null,
              onChanged: (_) => setState(() {}),
            ),
            if (humanPrivate?.hasLinkedPhone == true ||
                _linkedPhoneController.text.trim().isNotEmpty) ...[
              SizedBox(height: context.rsi(16)),
              RoundTextField(
                controller: _linkedPhoneController,
                labelText: '인증 연락처',
                height: fieldHeight,
                enabled: false,
                suffixIcon: !_isEditMode
                    ? _revealButton(
                        canRevealField: true,
                        revealing: _revealingLinkedPhone,
                        isRevealed: _revealedLinkedPhone != null,
                        onReveal: _revealLinkedPhone,
                        revealedValue: _revealedLinkedPhone,
                        label: '인증 연락처',
                      )
                    : null,
                suffixTrailingWidth: context.rsi(36),
                onChanged: (_) {},
              ),
            ],
          ],
          SizedBox(height: context.rsi(12)),
          if (_isEditMode)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _cancelEdit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rsi(44)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rsi(12)),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rsi(44)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rsi(12)),
                      ),
                    ),
                    child: Text(_saving ? '저장 중…' : '저장'),
                  ),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: _startEdit,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(context.rsi(44)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rsi(12)),
                ),
              ),
              child: const Text('수정하기'),
            ),
        ],
      ),
    );
  }
}
