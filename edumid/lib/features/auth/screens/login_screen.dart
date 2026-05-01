import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/auth_session.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolCodeController = TextEditingController();
  final _vendorCodeController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _role;

  static const _roles = ['student', 'teacher', 'principal', 'vendor'];
  bool get _isVendor => _role == 'vendor';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _schoolCodeController.dispose();
    _vendorCodeController.dispose();
    super.dispose();
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'student':
        return '/student';
      case 'teacher':
        return '/teacher';
      case 'principal':
        return '/principal';
      case 'vendor':
        return '/vendor';
      default:
        return '/login';
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null || _role!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role must be selected')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final error = await AuthService.instance.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      schoolCode: _isVendor ? null : _schoolCodeController.text.trim(),
      vendorCode: _isVendor ? _vendorCodeController.text.trim() : null,
      role: _role!,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    AuthSession.setRoleFromString(_role!);
    context.go(_routeForRole(_role!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              Text(
                'Welcome to EDUMID',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Login to continue',
                style: AppTypography.bodyMedium.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
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
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _role = v;
                  if (_role == 'vendor') {
                    _schoolCodeController.clear();
                  } else {
                    _vendorCodeController.clear();
                  }
                }),
                decoration: const InputDecoration(
                  hintText: 'Select role',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Role must be selected' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Phone Number',
                hint: 'Enter phone number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Phone must not be empty'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Password',
                hint: 'Enter password',
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _isPasswordVisible = !_isPasswordVisible,
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Password must not be empty'
                    : null,
              ),
              if (_isVendor) ...[
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Vendor Code',
                  hint: 'Enter vendor code',
                  controller: _vendorCodeController,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vendor code must not be empty'
                      : null,
                ),
              ],
              if (!_isVendor) ...[
                const SizedBox(height: 14),
                AppTextField(
                  label: 'School Code',
                  hint: 'Enter school code',
                  controller: _schoolCodeController,
                  prefixIcon: const Icon(Icons.domain_rounded, size: 20),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'School Code must not be empty'
                      : null,
                ),
              ],
              const SizedBox(height: 24),
              GradientButton(
                label: 'Login',
                onTap: _handleLogin,
                isLoading: _isLoading,
                prefixIcon: Icons.login_rounded,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Don\'t have an account? Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
