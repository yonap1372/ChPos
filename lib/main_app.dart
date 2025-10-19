import 'package:flutter/material.dart';
import 'screens/splash_page.dart';
import 'theme.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chilascas POS',
      theme: chilascasTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashPage(),
    );
  }
}
