import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../views/auth/login_page.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _redirigir();
  }

  void _redirigir() async {
    await Future.delayed(const Duration(seconds: 1));
    final user = Supabase.instance.client.auth.currentUser;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => user == null ? const LoginPage() : const HomePage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
