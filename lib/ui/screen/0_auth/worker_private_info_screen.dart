import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_private_info_form_body.dart';
import 'package:w0001/ui/widget/responsive_page_shell.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 본인 세무·정산 고위험 정보 (`PATCH /users/me/private`).
class WorkerPrivateInfoScreen extends ConsumerStatefulWidget {
  const WorkerPrivateInfoScreen({super.key});

  @override
  ConsumerState<WorkerPrivateInfoScreen> createState() =>
      _WorkerPrivateInfoScreenState();
}

class _WorkerPrivateInfoScreenState
    extends ConsumerState<WorkerPrivateInfoScreen> {
  final _rrnFrontController = TextEditingController();
  final _rrnBackController = TextEditingController();
  final _rrnFrontFocusNode = FocusNode();
  final _rrnBackFocusNode = FocusNode();
  final _bankAccountController = TextEditingController();
  final _bankOwnerController = TextEditingController();
  final _bankNameController = TextEditingController();
  var _initialized = false;
  var _saving = false;
  var _taxTermOk = false;
  var _isEditMode = false;
  TermSummary? _taxTerm;

  @override
  void dispose() {
    _rrnFrontController.dispose();
    _rrnBackController.dispose();
    _rrnFrontFocusNode.dispose();
    _rrnBackFocusNode.dispose();
    _bankAccountController.dispose();
    _bankOwnerController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  void _onTaxTermChanged(bool agreed, TermSummary? term) {
    setState(() {
      _taxTermOk = agreed;
      _taxTerm = term;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final rrn = _currentRrn.trim();
    final account = _bankAccountController.text.trim();
    final owner = _bankOwnerController.text.trim();
    final bank = _bankNameController.text.trim();

    // 마스킹된 주민번호는 유효성 검사를 건너뜀
    final rrnContainsMask = rrn.contains('*');
    if (!rrnContainsMask && !_isValidRrn(rrn)) {
      _toast('유효한 주민등록번호를 입력해 주세요.');
      return;
    }

    // 마스킹된 계좌번호는 검사 건너뜀
    final accountContainsMask = account.contains('*');
    if (!accountContainsMask && account.isEmpty) {
      _toast('계좌번호를 입력해 주세요.');
      return;
    }

    if (owner.isEmpty || bank.isEmpty) {
      _toast('예금주·은행명을 모두 입력해 주세요.');
      return;
    }
    final serverTaxAgreed = ref
            .read(workerPrivateInfoProvider)
            .asData
            ?.value
            ?.workerTaxTermAgreed ==
        true;
    // 약관 동의 이력도 확인
    final taxAgreements =
        ref.read(workerTaxAgreementsProvider).asData?.value ?? [];
    final hasTaxAgreement = taxAgreements.isNotEmpty;

    if (!_taxTermOk && !serverTaxAgreed && !hasTaxAgreement) {
      _toast('세무정보 수집·이용에 동의해 주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(workerPrivateInfoProvider.notifier).save(
            // 마스킹된 값은 null로 보내서 서버에서 기존 값 유지
            rrn: rrnContainsMask ? null : rrn,
            bankAccount: accountContainsMask ? null : account,
            bankOwner: owner,
            bankName: bank,
            workerTaxTermId:
                (serverTaxAgreed || hasTaxAgreement) ? null : _taxTerm?.id,
            workerTaxTermVersion:
                (serverTaxAgreed || hasTaxAgreement) ? null : _taxTerm?.version,
          );
      if (!mounted) return;
      // 저장 후 최신 데이터를 서버에서 다시 가져옴
      await ref.read(workerPrivateInfoProvider.notifier).reload();
      ref.invalidate(workerTaxAgreementsProvider);
      if (!mounted) return;
      _toast('저장했습니다.');
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '저장에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setRrnDisplay(String display) {
    final (front, back) = splitResidentRegistrationDisplay(display);
    _rrnFrontController.text = front;
    _rrnBackController.text = back;
  }

  void _initializeForm(UserPrivateRead private) {
    _bankOwnerController.text = private.bankOwner ?? '';
    _bankNameController.text = private.bankName ?? '';

    if (private.rrnMasked != null) {
      _setRrnDisplay(private.rrnMasked!);
    } else {
      _setRrnDisplay('');
    }

    if (private.bankAccountMasked != null) {
      _bankAccountController.text = private.bankAccountMasked!;
    }

    _isEditMode = !private.hasRrn && !private.hasBankAccount;
    _initialized = true;
  }

  String get _currentRrn => joinResidentRegistrationParts(
        _rrnFrontController.text,
        _rrnBackController.text,
      );

  void _cancelEdit() {
    final private = ref.read(workerPrivateInfoProvider).asData?.value;
    setState(() {
      _isEditMode = false;
      _initialized = false;
      if (private != null) {
        _initializeForm(private);
      }
    });
  }

  void _startEdit() {
    setState(() => _isEditMode = true);
  }

  String? get _rrnErrorText {
    if (_currentRrn.isEmpty) return null;
    // 마스킹된 데이터는 오류를 표시하지 않음 (읽기/편집 모드 모두)
    if (_currentRrn.contains('*')) return null;
    // 마스킹되지 않은 경우에만 유효성 검사
    return residentRegistrationFormatMessage(_currentRrn);
  }

  void _onRrnChanged(String _) => setState(() {});

  bool _isValidRrn(String value) {
    return residentRegistrationFormatMessage(value) == null;
  }

  bool _isFormValid(UserPrivateRead? private) {
    final rrn = _currentRrn.trim();
    final account = _bankAccountController.text.trim();

    // 마스킹된 주민번호는 유효한 것으로 간주
    final rrnValid = rrn.contains('*') || _isValidRrn(rrn);
    if (!rrnValid) return false;

    // 마스킹된 계좌번호는 유효한 것으로 간주
    final accountValid = account.contains('*') || account.isNotEmpty;
    if (!accountValid) return false;

    if (_bankOwnerController.text.trim().isEmpty ||
        _bankNameController.text.trim().isEmpty) {
      return false;
    }
    final serverTaxAgreed = private?.workerTaxTermAgreed == true;
    final taxAgreements =
        ref.read(workerTaxAgreementsProvider).asData?.value ?? [];
    final hasTaxAgreement = taxAgreements.isNotEmpty;
    if (!_taxTermOk && !serverTaxAgreed && !hasTaxAgreement) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final asyncPrivate = ref.watch(workerPrivateInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('세무·정산 정보'),
      ),
      body: SafeArea(
        child: asyncPrivate.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _form(context, private: null),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(context.rsi(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('정보를 불러오지 못했습니다.', style: tt.bodyLarge),
                  SizedBox(height: context.rsi(12)),
                  FilledButton(
                    onPressed: () =>
                        ref.read(workerPrivateInfoProvider.notifier).reload(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
          data: (private) {
            if (!_initialized && private != null) {
              _initializeForm(private);
            }
            return ResponsivePageShell(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(16),
                  vertical: context.rsi(12),
                ),
                child: _form(context, private: private),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: asyncPrivate.maybeWhen(
        data: (private) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(6),
              context.rsi(16),
              context.rsi(10),
            ),
            child: _isEditMode
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _cancelEdit,
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.fromHeight(context.rsi(48)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(context.rsi(12)),
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      SizedBox(width: context.rsi(10)),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saving ||
                                  asyncPrivate.isLoading ||
                                  !_isFormValid(private)
                              ? null
                              : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: Size.fromHeight(context.rsi(48)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(context.rsi(12)),
                            ),
                          ),
                          child: _saving
                              ? SizedBox(
                                  width: context.rsi(20),
                                  height: context.rsi(20),
                                  child: const HammerLoadingIndicator(size: 20),
                                )
                              : Text(
                                  '저장',
                                  style: TextStyle(fontSize: context.rsi(15)),
                                ),
                        ),
                      ),
                    ],
                  )
                : FilledButton(
                    onPressed: _startEdit,
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rsi(48)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rsi(12)),
                      ),
                    ),
                    child: const Text('수정하기'),
                  ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _form(BuildContext context, {required UserPrivateRead? private}) {
    return WorkerPrivateInfoFormBody(
      isEditMode: _isEditMode,
      private: private,
      rrnFrontController: _rrnFrontController,
      rrnBackController: _rrnBackController,
      rrnFrontFocusNode: _rrnFrontFocusNode,
      rrnBackFocusNode: _rrnBackFocusNode,
      bankAccountController: _bankAccountController,
      bankOwnerController: _bankOwnerController,
      bankNameController: _bankNameController,
      rrnErrorText: _rrnErrorText,
      onChanged: (_) => _onRrnChanged(''),
      onTaxTermChanged: _onTaxTermChanged,
    );
  }
}
