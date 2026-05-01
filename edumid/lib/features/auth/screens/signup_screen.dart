import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _schoolCodeCtrl = TextEditingController();
  final _vendorCodeCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController();
  String? _role;
  bool _loading = false;
  bool _showPassword = false;

  static const _roles = ['student', 'teacher', 'principal', 'vendor'];

  bool get _isPrincipal => _role == 'principal';
  bool get _isVendor => _role == 'vendor';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _schoolCodeCtrl.dispose();
    _vendorCodeCtrl.dispose();
    _schoolNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }

    setState(() => _loading = true);
    final error = await AuthService.instance.register(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
      schoolCode: _isVendor ? null : _schoolCodeCtrl.text.trim(),
      vendorCode: _isVendor ? _vendorCodeCtrl.text.trim() : null,
      role: _role!,
      schoolName: _isPrincipal ? _schoolNameCtrl.text.trim() : '',
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signup successful. Please login.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Account', style: AppTypography.headlineSmall),
              const SizedBox(height: 18),
              Text(
                'Role',
                style: AppTypography.labelMedium.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _role,
                items: _roles
                    .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r[0].toUpperCase() + r.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _role = v;
                  if (_role == 'vendor') {
                    _schoolCodeCtrl.clear();
                    _schoolNameCtrl.clear();
                  } else {
                    _vendorCodeCtrl.clear();
                  }
                }),
                decoration: const InputDecoration(hintText: 'Select role'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Role is required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Name',
                controller: _nameCtrl,
                hint: 'Enter your name',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                hint: 'Enter phone number',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Password',
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                hint: 'Enter password',
                suffixIcon: IconButton(
                  icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
              ),
              if (_isVendor) ...[
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Vendor Code',
                  controller: _vendorCodeCtrl,
                  hint: 'Enter your vendor code',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vendor code is required'
                      : null,
                ),
              ],
              if (!_isVendor) ...[
                const SizedBox(height: 12),
                AppTextField(
                  label: _isPrincipal
                      ? 'School Code (create a unique code)'
                      : 'School Code',
                  controller: _schoolCodeCtrl,
                  hint:
                      _isPrincipal ? 'E.g. DPS2025' : 'Enter your school code',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'School code is required'
                      : null,
                ),
              ],
              // School Name — only for principal
              if (_isPrincipal) ...[
                const SizedBox(height: 12),
                AppTextField(
                  label: 'School Name',
                  controller: _schoolNameCtrl,
                  hint: 'E.g. Delhi Public School',
                  validator: (v) =>
                      _isPrincipal && (v == null || v.trim().isEmpty)
                          ? 'School name is required for principal'
                          : null,
                ),
              ],
              const SizedBox(height: 22),
              GradientButton(
                label: 'Sign Up',
                onTap: _register,
                isLoading: _loading,
                prefixIcon: Icons.app_registration_rounded,
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
