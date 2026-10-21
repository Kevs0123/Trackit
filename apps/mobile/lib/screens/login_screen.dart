import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../utils.dart';

class LoginScreen extends StatefulWidget {
  final bool startAsRegister;
  const LoginScreen({super.key, this.startAsRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.startAsRegister;
  bool _busy = false;
  bool _hide = true;
  bool _forgotPassword = false;
  bool _resetSent = false;
  String? _notice;
  String? _resetUrl;
  String? _error;

  final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      if (_register) {
        await auth.register(
          _name.text.trim(),
          _email.text.trim(),
          _phone.text.trim(),
          _password.text,
        );
      } else if (_forgotPassword) {
        final resetUrl = await auth.requestPasswordReset(_email.text.trim());
        if (mounted) {
          setState(() {
            _resetSent = true;
            _resetUrl = resetUrl;
            _notice = resetUrl == null
                ? 'If an account exists for this email, a password reset link has been sent.'
                : 'Local development reset link is ready.';
          });
        }
        return;
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (text.length < 2) return 'Enter at least 2 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (!_emailRegex.hasMatch(text)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length < 8) return 'At least 8 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length < 7) return 'Enter a valid phone number';
    return null;
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _register = !_register;
      _forgotPassword = false;
      _resetSent = false;
      _notice = null;
      _resetUrl = null;
      _error = null;
      _password.clear();
      if (!_register) {
        _name.clear();
        _phone.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_forgotPassword
            ? 'Reset password'
            : _register
                ? 'Create customer account'
                : 'Sign in'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    if (!_forgotPassword)
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hide ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: _forgotPassword ? null : _validatePassword,
                      ),
                    if (_resetSent && _notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_notice!, textAlign: TextAlign.center),
                      ),
                    if (_resetUrl != null)
                      TextButton(
                        onPressed: () {
                          final route = Uri.parse(_resetUrl!).fragment;
                          Navigator.of(context).pushNamed(route);
                        },
                        child: const Text('Open password reset page'),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _forgotPassword
                                      ? 'Send reset link'
                                      : _register
                                          ? 'Create account'
                                          : 'Sign in',
                                ),
                        ),
                      ),
                    ),
                    if (!_forgotPassword)
                      TextButton(
                        onPressed: _busy ? null : _toggleMode,
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'New customer? Create an account',
                        ),
                      ),
                    if (!_register && !_forgotPassword)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _forgotPassword = true;
                                  _resetSent = false;
                                  _error = null;
                                  _notice = null;
                                  _resetUrl = null;
                                }),
                        child: const Text('Forgot password?'),
                      ),
                    if (_forgotPassword)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _forgotPassword = false;
                                  _resetSent = false;
                                  _error = null;
                                  _notice = null;
                                }),
                        child: const Text('Back to sign in'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
