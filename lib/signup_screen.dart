// lib/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _storeCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth  = context.read<AuthProvider>();
    final error = await auth.signup(
        _nameCtrl.text.trim(), _emailCtrl.text.trim(),
        _passCtrl.text.trim(), _storeCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error), backgroundColor: AppColors.danger));
      return;
    }

    // Navigate immediately — load data in background after navigation
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);

    // Load data after navigation (non-blocking)
    final userId = auth.userId;
    Future.wait([
      context.read<ProductProvider>().load(userId),
      context.read<SalesProvider>().load(userId),
      context.read<DashboardProvider>().load(userId),
    ]).catchError((_) {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _storeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(width: 38, height: 38,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 16))),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Create Account',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('Set up your store in minutes',
                            style: TextStyle(fontSize: 12,
                                color: Colors.white.withOpacity(0.8))),
                      ]),
                    ]),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12),
                              blurRadius: 20, offset: const Offset(0, 8))]),
                      child: Form(
                        key: _formKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Your Details', style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 18),

                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outline, color: AppColors.primary)),
                            validator: (v) => v!.isEmpty ? 'Enter your name' : null),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _storeCtrl,
                            decoration: const InputDecoration(labelText: 'Store Name',
                                prefixIcon: Icon(Icons.store_outlined, color: AppColors.primary)),
                            validator: (v) => v!.isEmpty ? 'Enter store name' : null),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary)),
                            validator: (v) => v!.contains('@') ? null : 'Enter valid email'),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                    color: AppColors.textSecondary),
                                onPressed: () => setState(() => _obscure = !_obscure))),
                            validator: (v) => v!.length >= 6 ? null : 'Min 6 characters'),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Confirm Password',
                                prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary)),
                            validator: (v) =>
                                v == _passCtrl.text ? null : 'Passwords do not match'),
                          const SizedBox(height: 24),

                          SizedBox(height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signup,
                              child: _loading
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Create Account'))),
                          const SizedBox(height: 18),

                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Already have an account? ',
                                style: Theme.of(context).textTheme.bodyMedium),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text('Sign In',
                                  style: TextStyle(color: AppColors.primary,
                                      fontWeight: FontWeight.w700))),
                          ]),
                        ]),
                      ),
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