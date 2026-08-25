// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _textOpacity;
  late Animation<Offset>   _textSlide;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale   = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textSlide   = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: const Offset(0, 0.3), end: Offset.zero));
    _logoCtrl.forward().then((_) => _textCtrl.forward());
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.init();
    if (auth.isLoggedIn && auth.userId > 0) {
      await Future.wait([
        context.read<ProductProvider>().load(auth.userId),
        context.read<SalesProvider>().load(auth.userId),
        context.read<DashboardProvider>().load(auth.userId),
      ]);
      _go(const HomeScreen());
    } else {
      _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, a, __) => screen,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF008B72)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -60, right: -60,
              child: Container(width: 220, height: 220,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
            Positioned(bottom: -80, left: -80,
              child: Container(width: 280, height: 280,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)))),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              ScaleTransition(scale: _logoScale,
                child: FadeTransition(opacity: _logoOpacity,
                  child: Container(width: 100, height: 100,
                    decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                          blurRadius: 30, offset: const Offset(0, 10))]),
                    child: const Center(child: Text('SM',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                            color: AppColors.primary)))))),
              const SizedBox(height: 28),
              SlideTransition(position: _textSlide,
                child: FadeTransition(opacity: _textOpacity,
                  child: Column(children: [
                    const Text('StockMate Pro',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Smart FMCG Stock Management',
                        style: TextStyle(fontSize: 15,
                            color: Colors.white.withOpacity(0.75))),
                  ]))),
            ])),
            Positioned(bottom: 60, left: 0, right: 0,
              child: FadeTransition(opacity: _textOpacity,
                child: Column(children: [
                  SizedBox(width: 40,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 16),
                  Text('Loading your inventory...',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ]))),
          ],
        ),
      ),
    );
  }
}
