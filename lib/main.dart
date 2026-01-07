import 'package:caro_online/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(),
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
      // Màn hình khởi động để kiểm tra xem đã login chưa
      home: const SplashScreen(), 
    );
  }
}

// Màn hình chờ kiểm tra đăng nhập
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() async {
    // Giả lập chờ 1.5 giây để hiện logo cho đẹp
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Gọi hàm tryAutoLogin từ GameProvider
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    bool isLoggedIn = await gameProvider.tryAutoLogin();

    if (!mounted) return;

    if (isLoggedIn) {
      // Đã đăng nhập -> Vào sảnh
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } else {
      // Chưa đăng nhập -> Vào Login
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videogame_asset, size: 80, color: Colors.pinkAccent),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.pinkAccent),
            SizedBox(height: 10),
            Text("Đang tải dữ liệu...", style: TextStyle(color: Colors.white54))
          ],
        ),
      ),
    );
  }
}