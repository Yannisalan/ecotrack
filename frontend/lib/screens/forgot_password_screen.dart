import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/eco_widgets.dart';

/// Two-step password reset:
/// 1. request a reset token for an email,
/// 2. set a new password with that token.
///
/// When the backend has no email delivery configured (debug/demo), it echoes
/// the token in the response and we pre-fill it for convenience.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();

  bool _requesting = false;
  bool _resetting = false;
  bool _sent = false;
  bool _obscure = true;
  String? _requestError;
  String? _resetError;
  String? _done;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _requesting = true;
      _requestError = null;
    });
    final (error, token) = await context.read<AuthProvider>().forgotPassword(
      _email.text.trim().toLowerCase(),
    );
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _requestError = error;
      if (error == null) {
        _sent = true;
        if (token != null && token.isNotEmpty) _token.text = token;
      }
    });
  }

  Future<void> _reset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() {
      _resetting = true;
      _resetError = null;
    });
    final error = await context
        .read<AuthProvider>()
        .resetPassword(_token.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _resetting = false;
      _resetError = error;
    });
    if (error == null) {
      Navigator.of(context).pop();
      ecoSnack(context, 'Password reset. Log in with your new password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _sent
                      ? 'Enter the reset token and choose a new password.'
                      : 'Enter your email and we will start a password reset.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Form(
                  key: _emailFormKey,
                  child: TextFormField(
                    controller: _email,
                    enabled: !_sent,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Enter your email';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                if (_requestError != null) ...[
                  const SizedBox(height: 12),
                  Text(_requestError!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 16),
                if (!_sent)
                  FilledButton(
                    onPressed: _requesting ? null : _request,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _requesting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send reset token'),
                    ),
                  )
                else
                  Form(
                    key: _resetFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _token,
                          decoration: const InputDecoration(
                            labelText: 'Reset token',
                            prefixIcon: Icon(Icons.key_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                              ? 'Paste your reset token'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) => _reset(),
                          decoration: InputDecoration(
                            labelText: 'New password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Enter a new password';
                            }
                            if (v.length < 8) {
                              return 'Use at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        if (_resetError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _resetError!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _resetting ? null : _reset,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: _resetting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Set new password'),
                          ),
                        ),
                        TextButton(
                          onPressed: _resetting
                              ? null
                              : () => setState(() {
                                  _sent = false;
                                  _resetError = null;
                                  _requestError = null;
                                }),
                          child: const Text('Use a different email'),
                        ),
                      ],
                    ),
                  ),
                if (_done != null) ...[
                  const SizedBox(height: 12),
                  Text(_done!, style: TextStyle(color: scheme.primary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
