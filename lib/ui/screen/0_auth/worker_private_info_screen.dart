import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_tax_terms_agreement.dart';
import 'package:w0001/ui/widget/responsive_page_shell.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/responsive_layout.dart';

const _kBankNames = <String>[
  '국민은행',
  '신한은행',
  '우리은행',
  '하나은행',
  '기업은행',
  'NH농협은행',
  '카카오뱅크',
  '케이뱅크',
  'SC제일은행',
  '부산은행',
  '대구은행',
  '경남은행',
  '광주은행',
  '제주은행',
];

/// 작업자 본인 세무·정산 고위험 정보 (`PATCH /users/me/private`).
class WorkerPrivateInfoScreen extends ConsumerStatefulWidget {
  const WorkerPrivateInfoScreen({super.key});

  @override
  ConsumerState<WorkerPrivateInfoScreen> createState() =>
      _WorkerPrivateInfoScreenState();
}

class _WorkerPrivateInfoScreenState extends ConsumerState<WorkerPrivateInfoScreen> {
  final _rrnFrontController = TextEditingController();
  final _rrnBackController = TextEditingController();
  final _rrnFrontFocusNode = FocusNode();
  final _rrnBackFocusNode = FocusNode();
  final _bankAccountController = TextEditingController();
  final _bankOwnerController = TextEditingController();
  final _bankNameController = TextEditingController();
  var _obscureRrnBack = true;
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
    final serverTaxAgreed =
        ref.read(workerPrivateInfoProvider).asData?.value?.workerTaxTermAgreed ==
            true;
    // 약관 동의 이력도 확인
    final taxAgreements = ref.read(workerTaxAgreementsProvider).asData?.value ?? [];
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
            workerTaxTermId: (serverTaxAgreed || hasTaxAgreement) ? null : _taxTerm?.id,
            workerTaxTermVersion: (serverTaxAgreed || hasTaxAgreement) ? null : _taxTerm?.version,
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

  void _initializeForm(UserPrivateRead private) {
    _bankOwnerController.text = private.bankOwner ?? '';
    _bankNameController.text = private.bankName ?? '';

    if (private.rrnMasked != null) {
      final parsed = _parseMaskedResidentRegistration(private.rrnMasked!);
      _rrnFrontController.text = parsed.front;
      // 뒷자리는 마스킹된 상태 그대로 표시 (*, 숫자 포함)
      _rrnBackController.text = parsed.backRaw;
    }

    // 계좌번호도 마스킹된 상태 그대로 표시
    if (private.bankAccountMasked != null) {
      _bankAccountController.text = private.bankAccountMasked!;
    }

    // 데이터가 있으면 편집 모드를 꺼둠 (읽기 전용)
    _isEditMode = !private.hasRrn && !private.hasBankAccount;
    
    _initialized = true;
  }

  String get _currentRrn => '${_rrnFrontController.text}${_rrnBackController.text}';


  _MaskedResidentRegistration _parseMaskedResidentRegistration(String masked) {
    // 하이픈 기준으로 분리
    final parts = masked.split('-');
    
    if (parts.length >= 2) {
      final front = parts[0].trim();
      final backRaw = parts[1].trim();
      
      // 마스킹된 * 도 그대로 유지 (6자리로 제한)
      final finalFront = front.length <= 6 ? front : front.substring(0, 6);
      
      return _MaskedResidentRegistration(
        front: finalFront,
        backRaw: backRaw,
      );
    }
    
    // 하이픈이 없는 경우 - 숫자와 * 만 남김
    final cleaned = masked.replaceAll(RegExp(r'[^0-9*]'), '');
    
    if (cleaned.length >= 13) {
      return _MaskedResidentRegistration(
        front: cleaned.substring(0, 6),
        backRaw: cleaned.substring(6),
      );
    }
    
    if (cleaned.length >= 6) {
      return _MaskedResidentRegistration(
        front: cleaned.substring(0, 6),
        backRaw: cleaned.length > 6 ? cleaned.substring(6) : '',
      );
    }

    return const _MaskedResidentRegistration(front: '', backRaw: '');
  }

  String? get _rrnErrorText {
    if (_currentRrn.isEmpty) return null;
    // 마스킹된 데이터는 오류를 표시하지 않음 (읽기/편집 모드 모두)
    if (_currentRrn.contains('*')) return null;
    // 마스킹되지 않은 경우에만 유효성 검사
    return residentRegistrationFormatMessage(_currentRrn);
  }

  String _formatAgreementDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$y년 $m월 $d일 $h시 $mi분 $s초';
  }

  void _onRrnFrontChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    _rrnFrontController.text = cleaned.length > 6 ? cleaned.substring(0, 6) : cleaned;
    if (_rrnFrontController.text.length == 6) {
      _rrnBackFocusNode.requestFocus();
    }
    _rrnFrontController.selection =
        TextSelection.collapsed(offset: _rrnFrontController.text.length);
    setState(() {});
  }

  void _onRrnBackChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    _rrnBackController.text = cleaned.length > 7 ? cleaned.substring(0, 7) : cleaned;
    _rrnBackController.selection =
        TextSelection.collapsed(offset: _rrnBackController.text.length);
    setState(() {});
  }

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
    final taxAgreements = ref.read(workerTaxAgreementsProvider).asData?.value ?? [];
    final hasTaxAgreement = taxAgreements.isNotEmpty;
    if (!_taxTermOk && !serverTaxAgreed && !hasTaxAgreement) return false;
    return true;
  }

  void _setBankName(String value) {
    _bankNameController.text = value;
    _bankNameController.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncPrivate = ref.watch(workerPrivateInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('세무·정산 정보'),
        actions: [
          if (!asyncPrivate.isLoading && asyncPrivate.hasValue)
            IconButton(
              icon: Icon(_isEditMode ? Icons.visibility_outlined : Icons.edit_outlined),
              tooltip: _isEditMode ? '보기 모드' : '수정 모드',
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                  if (!_isEditMode) {
                    // 보기 모드로 전환 시 원래 데이터로 복원
                    _initialized = false;
                    if (asyncPrivate.asData?.value != null) {
                      _initializeForm(asyncPrivate.asData!.value!);
                    }
                  }
                });
              },
            ),
        ],
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
      bottomNavigationBar: _isEditMode
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  context.rsi(6),
                  context.rsi(16),
                  context.rsi(10),
                ),
                child: FilledButton(
                  onPressed: _saving || asyncPrivate.isLoading ||
                          !_isFormValid(asyncPrivate.asData?.value)
                      ? null
                      : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(context.rsi(48)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rsi(12)),
                    ),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: context.rsi(20),
                          height: context.rsi(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text('저장', style: TextStyle(fontSize: context.rsi(15))),
                ),
              ),
            )
          : null,
    );
  }

  Widget _taxConsentHistory(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(workerTaxAgreementsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (agreements) {
        if (agreements.isEmpty) return const SizedBox.shrink();
        final latest = agreements.first;
        final at = latest.agreedAt?.trim() ?? '';
        final agreedAt = at.isNotEmpty ? _formatAgreementDate(at) : '';
        return Padding(
          padding: EdgeInsets.only(top: context.rsi(12)),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.rsi(12)),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(context.rs(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '세무 동의 이력',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: context.rsi(4)),
                Text(
                  '버전 ${latest.version}'
                  '${agreedAt.isNotEmpty ? '\n동의일 $agreedAt' : ''}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _form(BuildContext context, {required UserPrivateRead? private}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasRrn = private?.hasRrn == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (_isEditMode && hasRrn) ? '주민등록번호 변경' : '주민등록번호',
              style: tt.labelLarge?.copyWith(fontSize: context.rsi(14)),
            ),
            SizedBox(height: context.rsi(8)),
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: RoundTextField(
                    controller: _rrnFrontController,
                    focusNode: _rrnFrontFocusNode,
                    keyboardType: TextInputType.number,
                    labelText: '앞자리',
                    hintText: '000000',
                    height: context.rsi(66),
                    maxLength: 6,
                    showClearButton: _isEditMode,
                    enabled: _isEditMode,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: _onRrnFrontChanged,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.rsi(8)),
                  child: Text('-', style: tt.titleLarge),
                ),
                Expanded(
                  flex: 7,
                  child: RoundTextField(
                    controller: _rrnBackController,
                    focusNode: _rrnBackFocusNode,
                    keyboardType: TextInputType.number,
                    labelText: hasRrn ? '뒷자리 (변경 시 입력)' : '뒷자리',
                    hintText: '0000000',
                    height: context.rsi(66),
                    maxLength: 7,
                    obscureText: _obscureRrnBack,
                    showClearButton: _isEditMode,
                    enabled: _isEditMode,
                    suffixIcon: _isEditMode
                        ? IconButton(
                            onPressed: () => setState(() => _obscureRrnBack = !_obscureRrnBack),
                            icon: Icon(
                              _obscureRrnBack
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          )
                        : null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onChanged: _onRrnBackChanged,
                  ),
                ),
              ],
            ),
            if (_rrnErrorText != null) ...[
              SizedBox(height: context.rsi(6)),
              Text(
                _rrnErrorText!,
                style: tt.bodySmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                  fontSize: context.rsi(12),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: context.rsi(16)),
        RoundTextField(
          controller: _bankAccountController,
          keyboardType: TextInputType.number,
          labelText: '계좌번호',
          hintText: '하이픈(-) 없이 입력하세요.',
          height: context.rsi(66),
          showClearButton: _isEditMode,
          enabled: _isEditMode,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(20),
          ],
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: context.rsi(16)),
        RoundTextField(
          controller: _bankOwnerController,
          keyboardType: TextInputType.name,
          labelText: '예금주',
          height: context.rsi(66),
          showClearButton: _isEditMode,
          enabled: _isEditMode,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: context.rsi(16)),
        if (_isEditMode)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RoundTextField(
                  controller: _bankNameController,
                  labelText: '은행명',
                  // hintText: '직접 입력하거나 목록에서 선택',
                  height: context.rsi(66),
                  showClearButton: true,
                  enabled: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: context.rsi(8)),
              SizedBox(
                height: context.rsi(48),
                width: context.rsi(72),
                child: Material(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rs(10)),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(context.rs(10)),
                    onTap: () {},
                    child: PopupMenuButton<String>(
                      tooltip: '은행 선택',
                      padding: EdgeInsets.zero,
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_outlined,
                            size: context.rsi(18),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: context.rsi(16),
                          ),
                        ],
                      ),
                      itemBuilder: (_) => _kBankNames
                          .map((bank) => PopupMenuItem(
                                value: bank,
                                child: Text(bank),
                              ))
                          .toList(),
                      onSelected: _setBankName,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          RoundTextField(
            controller: _bankNameController,
            labelText: '은행명',
            height: context.rsi(66),
            enabled: false,
            onChanged: (_) {},
          ),
        SizedBox(height: context.rsi(24)),
        Text(
          '약관 동의',
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: context.rsi(14),
          ),
        ),
        SizedBox(height: context.rsi(12)),
        Builder(
          builder: (context) {
            final taxAgreements = ref.watch(workerTaxAgreementsProvider).asData?.value ?? [];
            final hasTaxAgreement = taxAgreements.isNotEmpty;
            final agreedToTax = private?.workerTaxTermAgreed == true || hasTaxAgreement;
            
            if (_isEditMode) {
              return WorkerTaxTermsAgreement(
                alreadyAgreed: agreedToTax,
                onChanged: _onTaxTermChanged,
              );
            } else if (agreedToTax) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: context.rsi(8)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outlined, color: cs.primary, size: context.rs(20)),
                    SizedBox(width: context.rsi(8)),
                    Text(
                      '세무정보 수집·이용 동의 완료',
                      style: tt.bodyMedium?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        _taxConsentHistory(context),
        SizedBox(height: context.rsi(16)),
      ],
    );
  }
}

class _MaskedResidentRegistration {
  const _MaskedResidentRegistration({required this.front, required this.backRaw});

  final String front;
  final String backRaw;
}
