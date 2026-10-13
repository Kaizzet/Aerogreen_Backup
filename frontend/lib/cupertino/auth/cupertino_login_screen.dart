import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';


import '../../providers/auth_provider.dart';
import 'cupertino_register_screen.dart';
import 'cupertino_admin_login_screen.dart';

class CupertinoLoginScreen extends StatefulWidget {
  const CupertinoLoginScreen({super.key});

  @override
  State<CupertinoLoginScreen> createState() => _CupertinoLoginScreenState();
}

class _CupertinoLoginScreenState extends State<CupertinoLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _loginError;

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

    final success = await context.read<AuthProvider>().login(email, password);
    if (!success && mounted) {
      setState(() {
        _loginError = context.read<AuthProvider>().errorMessage ?? 'Email hoặc mật khẩu không đúng.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 520
                ? 420.0
                : double.infinity;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandMark(color: colors.primaryColor),
                      const SizedBox(height: 24),
                      Text(
                        'Chào mừng đến\nAerogreen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.label.resolveFrom(context),
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nông trại khỏe mạnh bắt đầu từ dữ liệu rõ ràng.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _FieldLabel(
                        label: 'Email',
                        child: CupertinoTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          placeholder: 'you@example.com',
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
                          autofillHints: const [AutofillHints.password],
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
                          return CupertinoButton.filled(
                            minimumSize: const Size(52, 52),
                            borderRadius: BorderRadius.circular(16),
                            onPressed: authProvider.isLoading ? null : _submit,
                            child: authProvider.isLoading
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                : const Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      CupertinoButton(
                        minimumSize: const Size(44, 44),
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const CupertinoRegisterScreen(),
                            ),
                          );
                        },
                        child: const Text('Tạo tài khoản mới'),
                      ),
                      const SizedBox(height: 8),
                      // === Nút Đăng nhập Admin (MỚI) ===
                      // === Nút Đăng nhập Admin (MỚI) ===
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: CupertinoColors.separator
                                  .resolveFrom(context),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'hoặc',
                              style: TextStyle(
                                color: CupertinoColors.tertiaryLabel
                                    .resolveFrom(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: CupertinoColors.separator
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CupertinoButton(
                        minimumSize: const Size(44, 44),
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) =>
                              const CupertinoAdminLoginScreen(),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.shield_lefthalf_fill,
                              size: 17,
                              color: CupertinoColors.systemIndigo,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Đăng nhập Admin',
                              style: TextStyle(
                                color: CupertinoColors.systemIndigo,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Aerogreen bảo vệ nhịp vận hành của nông trại bằng những tín hiệu nhỏ, đúng lúc.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.tertiaryLabel.resolveFrom(
                            context,
                          ),
                          fontSize: 13,
                          height: 1.4,
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
      style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 12),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  final Color color;

  const _BrandMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          CupertinoIcons.leaf_arrow_circlepath,
          color: color,
          size: 38,
        ),
      ),
    );
  }
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
