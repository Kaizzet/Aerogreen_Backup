import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../theme/cupertino_theme.dart';

class CupertinoProfileEditScreen extends StatefulWidget {
  const CupertinoProfileEditScreen({super.key});

  @override
  State<CupertinoProfileEditScreen> createState() =>
      _CupertinoProfileEditScreenState();
}

class _CupertinoProfileEditScreenState
    extends State<CupertinoProfileEditScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Họ và tên không được để trống.');
      return;
    }

    if (phone.isNotEmpty && !RegExp(r'^[0-9+() -]{8,15}$').hasMatch(phone)) {
      setState(() => _errorMessage = 'Số điện thoại không hợp lệ.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final provider = context.read<AuthProvider>();
    final success = await provider.updateProfile(
      fullName: fullName,
      phoneNumber: phone.isEmpty ? null : phone,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Thành công'),
          content: const Text('Thông tin cá nhân đã được cập nhật.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = provider.errorMessage ?? 'Cập nhật thất bại. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Hồ sơ cá nhân'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const CupertinoActivityIndicator(radius: 8)
              : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AerogreenCupertinoTheme.aerogreenPrimary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  (user?.fullName.isNotEmpty == true)
                      ? user!.fullName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_circle,
                        color: CupertinoColors.systemRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Họ và tên',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: _fullNameController,
              placeholder: 'Nhập họ và tên',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Số điện thoại',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: _phoneController,
              placeholder: 'Nhập số điện thoại',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Email (không thể thay đổi)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user?.email ?? '',
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
