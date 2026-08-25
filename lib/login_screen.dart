// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth  = context.read<AuthProvider>();
    final error = await auth.login(
        _emailCtrl.text.trim(), _passCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error), backgroundColor: AppColors.danger));
      return;
    }

    await Future.wait([
      context.read<ProductProvider>().load(auth.userId),
      context.read<SalesProvider>().load(auth.userId),
      context.read<DashboardProvider>().load(auth.userId),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
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
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Logo & Title
                    Container(width: 56, height: 56,
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
                                blurRadius: 12, offset: const Offset(0, 4))]),
                        child: const Center(
                            child: Text('SM', style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.w900, color: AppColors.primary)))),
                    const SizedBox(height: 16),
                    const Text('Welcome back!',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Sign in to manage your inventory & sales',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 24),

                    // Card form
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
                          Text('Sign In', style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 20),

                          TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary)),
                              validator: (v) => v!.contains('@') ? null : 'Enter valid email'),
                          const SizedBox(height: 16),

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
                          const SizedBox(height: 24),

                          SizedBox(height: 50,
                              child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  child: _loading
                                      ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5))
                                      : const Text('Sign In'))),
                          const SizedBox(height: 20),

                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text("Don't have an account? ",
                                style: Theme.of(context).textTheme.bodyMedium),
                            GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                                child: const Text('Sign Up',
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