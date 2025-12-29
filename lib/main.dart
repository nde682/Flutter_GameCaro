import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Khai báo Provider duy nhất ở đây
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Caro Online',
      theme: ThemeData.dark(),
      home: const LoginScreen(), // Màn hình đầu tiên là Login
    );
  }
}