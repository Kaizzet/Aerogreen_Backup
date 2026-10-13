import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class CupertinoAdminLoginScreen extends StatefulWidget {
  const CupertinoAdminLoginScreen({super.key});

  @override
  State<CupertinoAdminLoginScreen> createState() =>
      _CupertinoAdminLoginScreenState();
}

class _CupertinoAdminLoginScreenState
    extends State<CupertinoAdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    // Pre-fill email admin để tiện test
    _emailController.text = 'admin@aerogreen.com';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Vui lòng nhập email.'
          : RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
          ? null
          : 'Email không hợp lệ.';
      _passwordError = password.isEmpty
          ? 'Vui lòng nhập mật khẩu.'
          : password.length < 8
          ? 'Mật khẩu phải có ít nhất 8 ký tự.'
          : null;
      _loginError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(email, password);

    if (!mounted) return;

    // Nếu login thành công nhưng role không phải admin → báo lỗi
    if (success && !authProvider.user!.isAdmin) {
      await authProvider.logout();
      if (!mounted) return;
      setState(() {
        _loginError = 'Tài khoản này không có quyền quản trị. Vui lòng dùng tài khoản admin.';
      });
      return;
    }

    if (!success && mounted) {
      setState(() {
        _loginError = authProvider.errorMessage ?? 'Email hoặc mật khẩu không đúng.';
      });
      return;
    }

    // Nếu login thành công và là admin → pop về root để AuthWrapper rebuild
    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: () => Navigator.of(context).pop(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.back, size: 22),
              Text('Quay lại', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        middle: const Text('Đăng nhập Admin'),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 520
                ? 420.0
                : double.infinity;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // === Badge Admin (khác biệt so với login user) ===
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF34C759)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                CupertinoIcons.shield_lefthalf_fill,
                                size: 16,
                                color: Color(0xFF34C759),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'KHU VỰC QUẢN TRỊ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Icon(
                        CupertinoIcons.person_crop_circle_fill_badge_checkmark,
                        size: 72,
                        color: Color(0xFF34C759),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Đăng nhập\nQuản trị viên',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Chỉ dành cho tài khoản có quyền admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _FieldLabel(
                        label: 'Email Admin',
                        child: CupertinoTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          placeholder: 'admin@aerogreen.com',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 14),
                            child: Icon(CupertinoIcons.mail, size: 19),
                          ),
                          padding: const EdgeInsets.all(16),
                          onChanged: (_) {
                            if (_emailError != null || _loginError != null) {
                              setState(() {
                                _emailError = null;
                                _loginError = null;
                              });
                            }
                          },
                          decoration: _fieldDecoration(
                            context,
                            hasError: _emailError != null,
                          ),
                        ),
                      ),
                      if (_emailError != null) _FieldError(_emailError!),
                      const SizedBox(height: 18),
                      _FieldLabel(
                        label: 'Mật khẩu',
                        child: CupertinoTextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          placeholder: 'Tối thiểu 8 ký tự',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 14),
                            child: Icon(CupertinoIcons.lock, size: 19),
                          ),
                          suffix: CupertinoButton(
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(44, 44),
                            onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? CupertinoIcons.eye
                                  : CupertinoIcons.eye_slash,
                              size: 19,
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 16, 4, 16),
                          onChanged: (_) {
                            if (_passwordError != null || _loginError != null) {
                              setState(() {
                                _passwordError = null;
                                _loginError = null;
                              });
                            }
                          },
                          decoration: _fieldDecoration(
                            context,
                            hasError: _passwordError != null,
                          ),
                        ),
                      ),
                      if (_passwordError != null) _FieldError(_passwordError!),
                      if (_loginError != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 8),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 16,
                                color: CupertinoColors.systemRed,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _loginError!,
                                  style: const TextStyle(
                                    color: CupertinoColors.systemRed,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 28),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          return CupertinoButton(
                            minimumSize: const Size(52, 52),
                            color: Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(16),
                            onPressed:
                            authProvider.isLoading ? null : _submit,
                            child: authProvider.isLoading
                                ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                                : const Text(
                              'Đăng nhập Admin',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Nếu bạn là người dùng thông thường,\nvui lòng quay lại màn hình đăng nhập chính.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.tertiaryLabel
                              .resolveFrom(context),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _fieldDecoration(
      BuildContext context, {
        bool hasError = false,
      }) {
    return BoxDecoration(
      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: hasError
            ? CupertinoColors.systemRed.resolveFrom(context)
            : CupertinoColors.separator.resolveFrom(context),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  final String message;

  const _FieldError(this.message);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 6),
    child: Text(
      message,
      style:
      const TextStyle(color: CupertinoColors.systemRed, fontSize: 12),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldLabel({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}