import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../app/toast.dart';
import '../state/account_store.dart';
import '../widgets/back_bar.dart';
import '../widgets/controls.dart';

enum _Mode { register, signIn }

bool _emailOk(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.register;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go(
    Future<void> Function(AccountStore account) work,
    String done, {
    bool stay = false,
  }) async {
    if (_busy) return;
    final account = context.read<AccountStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work(account);
      if (!mounted) return;
      Toast.show(context, done);
      if (!stay) Navigator.of(context).pop();
    } on AccountError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    final problem = !_emailOk(email)
        ? 'Email không hợp lệ.'
        : password.length < 6
        ? 'Mật khẩu cần ít nhất 6 ký tự.'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_mode == _Mode.register) {
      _go((a) => a.register(email, password), 'Đã tạo tài khoản $email');
    } else {
      _go((a) => a.signIn(email, password), 'Đã đăng nhập $email');
    }
  }

  void _forgot() {
    final email = _email.text.trim();
    if (!_emailOk(email)) {
      setState(() => _error = 'Nhập email ở trên rồi bấm lại "Quên mật khẩu".');
      return;
    }
    _go((a) => a.resetPassword(email), 'Đã gửi email đặt lại mật khẩu tới $email', stay: true);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountStore>();
    final insets = MediaQuery.paddingOf(context);
    return ScrolledPast(
      threshold: 40,
      builder: (context, scrolled, controller) => Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(V.pad, insets.top + 64, V.pad, insets.bottom + 32),
              child: account.isGuest ? _guest() : _signedIn(account),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BackBar(title: 'Tài khoản', solid: scrolled),
          ),
        ],
      ),
    );
  }

  Widget _guest() {
    final register = _mode == _Mode.register;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Bạn đang dùng tài khoản khách', style: VT.display(26, height: 1.2)),
        const SizedBox(height: 10),
        Text(
          register
              ? 'Tạo tài khoản để giữ nhật ký khi đổi máy hoặc cài lại app. Những gì bạn đã ghi '
                    'được giữ nguyên.'
              : 'Vào tài khoản đã tạo trước đó. Nhật ký của tài khoản khách trên máy này không '
                    'chuyển sang tài khoản đó.',
          style: VT.ui(15, color: V.muted),
        ),
        const SizedBox(height: 22),
        Segmented<_Mode>(
          options: const [(_Mode.register, 'Tạo tài khoản'), (_Mode.signIn, 'Đăng nhập')],
          value: _mode,
          onChanged: (m) => setState(() {
            _mode = m;
            _error = null;
          }),
        ),
        const SizedBox(height: 18),
        _Field(
          controller: _email,
          hint: 'Email',
          keyboard: TextInputType.emailAddress,
          autofill: AutofillHints.email,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: _password,
          hint: register ? 'Mật khẩu (ít nhất 6 ký tự)' : 'Mật khẩu',
          obscure: true,
          autofill: register ? AutofillHints.newPassword : AutofillHints.password,
          onSubmitted: _submit,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: VT.ui(14, color: V.danger)),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: _busy ? 'Đang xử lý…' : (register ? 'Tạo tài khoản' : 'Đăng nhập'),
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: GhostButton(
            label: 'Tiếp tục với Google',
            expand: true,
            onPressed: _busy
                ? null
                : () => _go((a) => a.continueWithGoogle(), 'Đã đăng nhập bằng Google'),
          ),
        ),
        if (!register) ...[
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _forgot,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Quên mật khẩu?', style: VT.ui(14, color: V.muted)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _signedIn(AccountStore account) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Đã đăng nhập', style: VT.display(26, height: 1.2)),
      const SizedBox(height: 10),
      Text(account.email ?? '', style: VT.ui(16)),
      const SizedBox(height: 10),
      Text(
        'Hồ sơ và nhật ký được lưu theo tài khoản này: đăng nhập trên máy khác vẫn thấy.',
        style: VT.ui(15, color: V.muted),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: 12),
        Text(error, style: VT.ui(14, color: V.danger)),
      ],
      const SizedBox(height: 22),
      SizedBox(
        height: 50,
        child: GhostButton(
          label: 'Đăng xuất',
          danger: true,
          expand: true,
          onPressed: _busy ? null : () => _go((a) => a.signOut(), 'Đã đăng xuất'),
        ),
      ),
    ],
  );
}

/// One text box, styled like the name editor on the profile.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.autofill,
    this.obscure = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final String? autofill;
  final bool obscure;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = VT.ui(17, weight: FontWeight.w500, height: 1);
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(V.rControl),
      borderSide: BorderSide(color: color, width: width),
      gapPadding: 0,
    );
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: [?autofill],
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: text.copyWith(color: V.faint),
        filled: true,
        fillColor: V.bg3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18.5),
        enabledBorder: ring(V.lineStrong, 1),
        focusedBorder: ring(V.accent, 1.5),
      ),
    );
  }
}
