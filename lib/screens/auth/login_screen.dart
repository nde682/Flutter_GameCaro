import 'package:caro_online/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
// import '../lobby/lobby_screen.dart';
import 'register_screen.dart'; // Đừng quên import màn hình đăng ký

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    final provider = Provider.of<GameProvider>(context, listen: false);
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMsg("Vui lòng nhập đầy đủ thông tin!");
      return;
    }

    // Gọi hàm login từ Provider
    bool success = await provider.login(username, password);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else if (mounted) {
      _showMsg("Đăng nhập thất bại! Kiểm tra lại tài khoản/mật khẩu.");
    }
  }
  
  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: SingleChildScrollView( // Thêm Scroll để không bị che khi bàn phím hiện
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset, size: 100, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text("CARO MASTER", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Đăng nhập để chiến ngay", style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 50),
              
              // Username Input
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent),
                  hintText: "Tên đăng nhập",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F3460),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              
              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
                  hintText: "Mật khẩu",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F3460),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 30),
              
              // Button Login
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: provider.isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ĐĂNG NHẬP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),

              // Chuyển sang Register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Chưa có tài khoản? ", style: TextStyle(color: Colors.white60)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text("Đăng ký ngay", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}