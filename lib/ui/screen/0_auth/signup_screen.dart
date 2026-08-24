import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_signup_phone_mo_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_signup_terms_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_signup_wizard_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_rank_career_fields.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_skills_editor.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/ui/widget/responsive_page_shell.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/ui/widget/shake_widget.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/util/fcm/fcm_bootstrap.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/login_preferences.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 가입 아이디: 영문·숫자 4~20자.
final RegExp _signupUidPattern = RegExp(r'^[a-zA-Z0-9]{4,20}$');

/// 비밀번호 검증: 최소 8자, 대문자 1개, 특수문자 1개
/// (특수문자: !@#$%^&*()_+-=[]{}|;:,.<>?)
final RegExp _passwordUppercasePattern = RegExp(r'[A-Z]');
final RegExp _passwordSpecialCharPattern =
    RegExp(r'[!@#$%^&*()_+=\[\]{}|;:,.<>?-]');

const _signupStepLabels = [
  '기본 정보',
  '휴대폰 인증',
  '작업 프로필',
  '약관 동의',
];

final _uidInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
  LengthLimitingTextInputFormatter(20),
];

String? signupUidFormatMessage(String uid) {
  final t = uid.trim();
  if (t.isEmpty) return '아이디를 입력해 주세요.';
  if (!_signupUidPattern.hasMatch(t)) {
    return '영문·숫자 4~20자만 사용할 수 있습니다.';
  }
  return null;
}

/// 비밀번호 형식 검증.
/// 규칙: 8자 이상 + 대문자 1개 + 특수문자 1개
String? signupPasswordFormatMessage(String password) {
  if (password.isEmpty) return null; // 빈 값은 별도 처리

  // 최소 길이 체크
  if (password.length < 8) {
    return '비밀번호는 최소 8자 이상이어야 합니다.';
  }

  // 대문자 포함 체크
  if (!_passwordUppercasePattern.hasMatch(password)) {
    return '비밀번호에 대문자가 최소 1개 포함되어야 합니다.';
  }

  // 특수문자 포함 체크
  if (!_passwordSpecialCharPattern.hasMatch(password)) {
    return '비밀번호에 특수문자가 최소 1개 포함되어야 합니다. (예: !@#\$%^&*)';
  }

  return null;
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _uidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _unameController = TextEditingController();
  final _skillsEditorKey = GlobalKey<WorkerSkillsEditorState>();
  final _rankCareerKey = GlobalKey<WorkerRankCareerFieldsState>();
  var _obscurePassword = true;
  var _obscurePasswordConfirm = true;
  var _submitting = false;
  var _uidChecking = false;

  /// 중복 확인에 통과한 아이디. 입력이 바뀌면 null 로 초기화한다.
  String? _uidVerifiedFor;

  String? _verifiedPhone;
  String? _phoneVerificationToken;
  List<TermAgreementInput> _termsAgreements = const [];
  var _termsRequiredOk = false;
  var _skillsComplete = false;
  var _basicStepComplete = false;

  /// 완료된 단계를 다시 편집할 때 사용.
  int? _editingStep;

  /// 기본 정보 단계 — [다음] 탭 후 미충족 항목 강조.
  var _basicValidationVisible = false;
  var _uidCheckShakeTrigger = 0;

  String get _currentUid => _uidController.text.trim();

  bool get _uidFormatOk => signupUidFormatMessage(_currentUid) == null;

  bool get _uidDuplicateChecked =>
      _uidVerifiedFor != null && _uidVerifiedFor == _currentUid;

  bool get _phoneVerified =>
      _verifiedPhone != null && _phoneVerificationToken != null;

  bool get _basicComplete {
    final upw = _passwordController.text;
    final upwConfirm = _passwordConfirmController.text;
    return _uidFormatOk &&
        _uidDuplicateChecked &&
        upw.isNotEmpty &&
        upwConfirm.isNotEmpty &&
        upw == upwConfirm &&
        signupPasswordFormatMessage(upw) == null &&
        _unameValidationMessage(_unameController.text) == null;
  }

  int get _completedThrough {
    if (!_basicStepComplete) return 0;
    if (!_phoneVerified) return 1;
    if (!_skillsComplete) return 2;
    if (!_termsRequiredOk) return 3;
    return 4;
  }

  int get _activeStep {
    if (_editingStep != null) return _editingStep!;
    if (_completedThrough >= 4) return 3;
    return _completedThrough.clamp(0, 3);
  }

  int get _visibleLastStep => _completedThrough.clamp(0, 3);

  bool get _canSubmit =>
      !_submitting && _completedThrough >= 4 && _editingStep == null;

  bool get _canTapUidCheck => !_uidChecking && _currentUid.isNotEmpty;

  bool get _allBasicInputsFilled {
    return _currentUid.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _passwordConfirmController.text.isNotEmpty &&
        _unameController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [
      _uidController,
      _passwordController,
      _passwordConfirmController,
      _unameController,
    ]) {
      c.addListener(_onAnyFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _uidController,
      _passwordController,
      _passwordConfirmController,
      _unameController,
    ]) {
      c.removeListener(_onAnyFieldChanged);
    }
    _uidController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _unameController.dispose();
    super.dispose();
  }

  void _onAnyFieldChanged() {
    if (!mounted) return;
    setState(() {
      if (_basicStepComplete) {
        _basicStepComplete = false;
      }
      if (_basicValidationVisible && _basicComplete) {
        _basicValidationVisible = false;
      }
    });
  }

  void _onUidChanged(String _) {
    final uid = _currentUid;
    if (_uidVerifiedFor != null && _uidVerifiedFor != uid) {
      setState(() => _uidVerifiedFor = null);
    }
    if (_basicStepComplete && mounted) {
      setState(() => _basicStepComplete = false);
    }
  }

  void _onBasicStepContinue() {
    if (_basicStepComplete) {
      if (_editingStep == 0) {
        setState(() => _editingStep = null);
      }
      return;
    }

    final uidMsg = signupUidFormatMessage(_currentUid);
    final upw = _passwordController.text;
    final upwConfirm = _passwordConfirmController.text;
    final uname = _unameController.text.trim();
    var shakeUid = false;

    if (uidMsg == null && !_uidDuplicateChecked && _currentUid.isNotEmpty) {
      shakeUid = true;
    }

    setState(() {
      _basicValidationVisible = true;
      if (shakeUid) _uidCheckShakeTrigger++;
    });

    if (_basicComplete) {
      setState(() {
        _basicStepComplete = true;
        _basicValidationVisible = false;
        if (_editingStep == 0) {
          _editingStep = null;
        }
      });
      return;
    }

    if (uidMsg != null) {
      _toast(uidMsg);
      return;
    }
    final unameValidationMsg = _unameValidationMessage(uname);
    if (unameValidationMsg != null) {
      _toast(unameValidationMsg);
      return;
    }
    if (upw.isEmpty) {
      _toast('비밀번호를 입력해 주세요.');
      return;
    }
    final passwordFormatMsg = signupPasswordFormatMessage(upw);
    if (passwordFormatMsg != null) {
      _toast(passwordFormatMsg);
      return;
    }
    if (upwConfirm.isEmpty) {
      _toast('비밀번호 확인을 입력해 주세요.');
      return;
    }
    if (upw != upwConfirm) {
      _toast('비밀번호가 일치하지 않습니다.');
      return;
    }
    if (!_uidDuplicateChecked) {
      _toast('아이디 중복 확인을 먼저 해 주세요.');
      return;
    }
  }

  String? _uidFieldError() {
    if (!_basicValidationVisible) return null;
    final uidMsg = signupUidFormatMessage(_currentUid);
    if (uidMsg != null) return uidMsg;
    if (_currentUid.isNotEmpty && !_uidDuplicateChecked) {
      return '중복 확인을 먼저 해 주세요.';
    }
    return null;
  }

  String? _passwordFieldError() {
    if (!_basicValidationVisible) return null;
    final upw = _passwordController.text;
    if (upw.isEmpty) return '비밀번호를 입력해 주세요.';
    final formatMsg = signupPasswordFormatMessage(upw);
    if (formatMsg != null) return formatMsg;
    return null;
  }

  String? _passwordConfirmFieldError() {
    if (!_basicValidationVisible) return null;
    final upw = _passwordController.text;
    final upwConfirm = _passwordConfirmController.text;
    if (upwConfirm.isEmpty) return '비밀번호 확인을 입력해 주세요.';
    if (upw.isNotEmpty && upwConfirm.isNotEmpty && upw != upwConfirm) {
      return '비밀번호가 일치하지 않습니다.';
    }
    return null;
  }

  String? _unameValidationMessage(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '성명을 입력해 주세요.';
    if (trimmed.length < 2) return '성명은 최소 2자 이상 입력해 주세요.';
    return null;
  }

  String? _unameFieldError() {
    if (!_basicValidationVisible) return null;
    return _unameValidationMessage(_unameController.text);
  }

  void _onPhoneVerifiedChanged(String? phone, String? token) {
    setState(() {
      _verifiedPhone = phone;
      _phoneVerificationToken = token;
      if (_phoneVerified && _editingStep == 1) _editingStep = null;
    });
  }

  void _onSkillsChanged() {
    if (!mounted) return;
    final has = _skillsEditorKey.currentState?.hasPrimary ?? false;
    setState(() {
      if (!has) {
        _skillsComplete = false;
      }
    });
  }

  void _onSkillsStepContinue() {
    final has = _skillsEditorKey.currentState?.hasPrimary ?? false;
    if (!has) {
      _toast('대표 주특기를 선택하거나 입력해 주세요.');
      return;
    }
    setState(() {
      _skillsComplete = true;
      if (_editingStep == 2) {
        _editingStep = null;
      }
    });
  }

  void _onTermsAgreementsChanged(
    List<TermAgreementInput> agreements,
    bool allRequiredOk,
  ) {
    setState(() {
      _termsAgreements = agreements;
      _termsRequiredOk = allRequiredOk;
      if (allRequiredOk && _editingStep == 3) _editingStep = null;
    });
  }

  bool _canEditStep(int step) {
    if (step == 1 && _phoneVerified) return false;
    return true;
  }

  void _startEditingStep(int step) {
    if (!_canEditStep(step)) return;
    setState(() => _editingStep = step);
  }

  Future<void> _onCheckUidDuplicate() async {
    if (_uidChecking || !_canTapUidCheck) return;
    final uid = _currentUid;
    final formatMsg = signupUidFormatMessage(uid);
    if (formatMsg != null) {
      _toast(formatMsg);
      return;
    }

    setState(() => _uidChecking = true);
    try {
      final available =
          await ref.read(authUseCaseProvider).checkUidAvailable(uid: uid);
      if (!mounted) return;
      if (_currentUid != uid) return;

      if (available) {
        setState(() {
          _uidVerifiedFor = uid;
          if (_basicValidationVisible && _basicComplete) {
            _basicValidationVisible = false;
          }
          if (_basicComplete && _editingStep == 0) {
            _editingStep = null;
          }
        });
        _toast('사용 가능한 아이디입니다.');
      } else {
        setState(() => _uidVerifiedFor = null);
        _toast('이미 사용 중인 아이디입니다.');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _uidVerifiedFor = null);
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '아이디 중복 확인에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uidVerifiedFor = null);
      _toast('아이디 중복 확인에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _uidChecking = false);
    }
  }

  Future<void> _onSignup() async {
    if (_submitting) return;
    final uid = _currentUid;
    final upw = _passwordController.text;
    final upwConfirm = _passwordConfirmController.text;
    final uname = _unameController.text.trim();
    final skillsState = _skillsEditorKey.currentState;

    final formatMsg = signupUidFormatMessage(uid);
    if (formatMsg != null) {
      _toast(formatMsg);
      return;
    }
    if (!_uidDuplicateChecked) {
      _toast('아이디 중복 확인을 먼저 해 주세요.');
      return;
    }
    final unameValidationMsg = _unameValidationMessage(uname);
    if (unameValidationMsg != null) {
      _toast(unameValidationMsg);
      return;
    }
    if (!_phoneVerified) {
      _toast('휴대폰 인증을 완료해 주세요.');
      return;
    }
    if (!_termsRequiredOk) {
      _toast('필수 약관에 동의해 주세요.');
      return;
    }
    if (upw.isEmpty) {
      _toast('비밀번호를 입력해 주세요.');
      return;
    }
    final passwordFormatMsg = signupPasswordFormatMessage(upw);
    if (passwordFormatMsg != null) {
      _toast(passwordFormatMsg);
      return;
    }
    if (upwConfirm.isEmpty) {
      _toast('비밀번호 확인을 입력해 주세요.');
      return;
    }
    if (upw != upwConfirm) {
      _toast('비밀번호가 일치하지 않습니다.');
      return;
    }
    if (skillsState == null || !skillsState.hasPrimary) {
      _toast('대표 주특기를 선택하거나 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final signupResult = await ref.read(authUseCaseProvider).signup(
            uid: uid,
            upw: upw,
            uname: uname,
            phone: _verifiedPhone,
            phoneVerificationToken: _phoneVerificationToken,
            termsAgreements: _termsAgreements,
            workerProfile: skillsState.toProfile(
              workerRank: _rankCareerKey.currentState?.workerRank ?? '',
              career: _rankCareerKey.currentState?.career ?? '',
            ),
          );
      await LoginPreferences.applyAfterSuccess(
        autoLogin: true,
        saveId: true,
        currentUid: uid,
      );
      if (!mounted) return;
      clearAllUserProvidersWithRef(ref);
      ref
          .read(authSessionProvider.notifier)
          .adoptAuthenticatedUser(signupResult.user);
      final root = rootProviderContainer;
      if (root != null) {
        final fcmOk = await registerFcmTokenForLoggedInUser(root, force: true);
        if (kDebugMode && !fcmOk) {
          debugPrint('FCM registration failed after signup uid=$uid');
        }
      }
      if (!mounted) return;
      context.go('/pending-approval');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      if (msg.trim().isNotEmpty) _toast(msg);
      setState(() => _uidVerifiedFor = null);
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _passwordSuffix({
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return IconButton(
      tooltip: obscure ? '비밀번호 표시' : '비밀번호 숨기기',
      onPressed: onToggleObscure,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }

  Widget _uidCheckAction(BuildContext context, ColorScheme cs) {
    final textTheme = Theme.of(context).textTheme;
    final label = _uidDuplicateChecked ? '확인됨' : '중복확인';
    final needsCheck = _basicValidationVisible &&
        !_uidDuplicateChecked &&
        signupUidFormatMessage(_currentUid) == null &&
        _currentUid.isNotEmpty;

    return ShakeWidget(
      trigger: _uidCheckShakeTrigger,
      child: TextButton(
        onPressed: _canTapUidCheck ? _onCheckUidDuplicate : null,
        style: TextButton.styleFrom(
          padding: ResponsiveLayout.symmetric(context, horizontal: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: needsCheck
              ? cs.error
              : (_canTapUidCheck
                  ? (_uidDuplicateChecked ? cs.primary : cs.onSurface)
                  : cs.onSurface.withValues(alpha: 0.38)),
          backgroundColor:
              needsCheck ? cs.errorContainer.withValues(alpha: 0.35) : null,
        ),
        child: _uidChecking
            ? SizedBox(
                width: context.rs(18),
                height: context.rs(18),
                child: const HammerLoadingIndicator(size: 18),
              )
            : Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  String? _stepSummary(int step) {
    switch (step) {
      case 0:
        final name = _unameController.text.trim();
        final uid = _currentUid;
        if (name.isEmpty || uid.isEmpty) return null;
        return '$name · $uid';
      case 1:
        if (!_phoneVerified || _verifiedPhone == null) return null;
        return '${formatKoreanMobilePhoneDisplay(_verifiedPhone!)} 인증 완료';
      case 2:
        final primary = _skillsEditorKey.currentState?.primaryTrimmed ?? '';
        if (primary.isEmpty) return null;
        final rank = _rankCareerKey.currentState?.workerRank ?? '';
        final career = _rankCareerKey.currentState?.career ?? '';
        final rankPart = rank.isNotEmpty ? ' · $rank' : '';
        final careerPart = career.isNotEmpty ? ' · $career' : '';
        return '$primary (대표 주특기)$rankPart$careerPart';
      case 3:
        return _termsRequiredOk ? '필수 약관 동의 완료' : null;
      default:
        return null;
    }
  }

  bool _stepComplete(int step) =>
      step < _completedThrough && _editingStep != step;

  bool _stepActive(int step) => step == _activeStep;

  Widget _basicStepForm(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoundTextField(
          controller: _uidController,
          keyboardType: TextInputType.text,
          autofillHints: const [AutofillHints.username],
          hintText: '영문·숫자 4~20자',
          labelText: '아이디',
          showClearButton: true,
          suffixIcon: _uidCheckAction(context, cs),
          suffixTrailingWidth: context.rs(84),
          inputFormatters: _uidInputFormatters,
          errorText: _uidFieldError(),
          onChanged: _onUidChanged,
        ),
        rsV(context, 12),
        RoundTextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          showClearButton: true,
          hintText: '8자 이상, 대문자·특수문자 포함',
          errorText: _passwordFieldError() ??
              (_passwordConfirmFieldError() != null &&
                      _passwordController.text.isNotEmpty &&
                      _passwordConfirmController.text.isNotEmpty
                  ? '비밀번호가 일치하지 않습니다.'
                  : null),
          onChanged: (_) => _onAnyFieldChanged(),
          labelText: '비밀번호',
          suffixIcon: _passwordSuffix(
            obscure: _obscurePassword,
            onToggleObscure: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
        ),
        rsV(context, 12),
        RoundTextField(
          controller: _passwordConfirmController,
          obscureText: _obscurePasswordConfirm,
          autofillHints: const [AutofillHints.newPassword],
          showClearButton: true,
          errorText: _passwordConfirmFieldError(),
          onChanged: (_) => _onAnyFieldChanged(),
          labelText: '비밀번호 확인',
          suffixIcon: _passwordSuffix(
            obscure: _obscurePasswordConfirm,
            onToggleObscure: () {
              setState(
                () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
              );
            },
          ),
        ),
        rsV(context, 12),
        RoundTextField(
          controller: _unameController,
          keyboardType: TextInputType.name,
          autofillHints: const [AutofillHints.name],
          showClearButton: true,
          errorText: _unameFieldError(),
          onChanged: (_) => _onAnyFieldChanged(),
          labelText: '성명',
        ),
        if (!_basicStepComplete || _editingStep == 0) ...[
          rsV(context, 16),
          FilledButton.tonal(
            onPressed: _onBasicStepContinue,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(context.rs(48)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
            ),
            child: Text(
              _basicStepComplete && _editingStep == 0 ? '완료' : '다음',
            ),
          ),
          if (_basicValidationVisible && _allBasicInputsFilled) ...[
            rsV(context, 10),
            Text(
              '아래 표시된 항목을 확인해 주세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStep(int step, BuildContext context, ColorScheme cs) {
    final complete = _stepComplete(step);
    final active = _stepActive(step);

    return WorkerSignupStepCard(
      key: ValueKey<int>(step),
      stepNumber: step + 1,
      title: _signupStepLabels[step],
      isComplete: complete,
      isActive: active,
      summary: _stepSummary(step),
      onEdit:
          complete && _canEditStep(step) ? () => _startEditingStep(step) : null,
      child: switch (step) {
        0 => _basicStepForm(context, cs),
        1 => WorkerSignupPhoneMoSection(
            showHeader: false,
            onVerifiedChanged: _onPhoneVerifiedChanged,
          ),
        2 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkerSkillsEditor(
                key: _skillsEditorKey,
                onChanged: _onSkillsChanged,
              ),
              rsV(context, 16),
              WorkerRankCareerFields(
                key: _rankCareerKey,
                onChanged: () => setState(() {}),
              ),
              if (!_skillsComplete || _editingStep == 2) ...[
                rsV(context, 16),
                FilledButton.tonal(
                  onPressed: _onSkillsStepContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(context.rs(48)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rs(12)),
                    ),
                  ),
                  child: Text(
                    _skillsComplete && _editingStep == 2 ? '완료' : '다음',
                  ),
                ),
              ],
            ],
          ),
        3 => WorkerSignupTermsSection(
            showTitle: false,
            onAgreementsChanged: _onTermsAgreementsChanged,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: KeyboardAwareScrollView(
          scrollFocusedAlignment: 0.22,
          child: ResponsivePageShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkerSignupProgressHeader(
                  stepLabels: _signupStepLabels,
                  activeIndex: _activeStep,
                  completedThrough: _completedThrough,
                ),
                rsV(context, 16),
                Text(
                  '관리자 승인 후 서비스를 이용할 수 있습니다.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: context.rs(12),
                  ),
                ),
                rsV(context, 18),
                for (var step = 0; step <= _visibleLastStep; step++)
                  _buildStep(step, context, cs),
                if (_canSubmit) ...[
                  rsV(context, 8),
                  FilledButton(
                    onPressed: _onSignup,
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rs(52)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rs(12)),
                      ),
                    ),
                    child: Skeletonizer(
                      enabled: _submitting,
                      child: Text(
                        '가입 요청',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
