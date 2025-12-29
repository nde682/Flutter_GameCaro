import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;

  // ============================
  // LOGIC VALIDATE (Giữ nguyên)
  // ============================
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập tên đăng nhập';
    if (value.length < 6) return 'Tối thiểu 6 ký tự';
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) return 'Chỉ dùng chữ và số';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Tối thiểu 6 ký tự';
    if (value.contains(' ')) return 'Không được chứa khoảng trắng';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập Email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập tên hiển thị';
    if (value.length < 6) return 'Tối thiểu 6 ký tự';
    return null;
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      final email = _emailController.text.trim();
      final nickname = _displayNameController.text.trim();

      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      bool success = await gameProvider.register(username, password, email, nickname);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đăng ký thành công! Hãy đăng nhập."), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Quay về Login
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đăng ký thất bại (Tên/Email đã tồn tại)."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ============================
  // HÀM HELPER CHO GIAO DIỆN
  // ============================
  // Tạo Style chung cho Input để code gọn hơn
  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.cyanAccent),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF0F3460),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Màu nền giống Login
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar trong suốt
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt_1, size: 80, color: Colors.cyanAccent),
                const SizedBox(height: 10),
                const Text("TẠO TÀI KHOẢN", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Tham gia cộng đồng Caro Master", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 40),

                // 1. Tên đăng nhập
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Tên đăng nhập", Icons.person),
                  validator: _validateUsername,
                ),
                const SizedBox(height: 15),

                // 2. Mật khẩu
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Mật khẩu", Icons.lock),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 15),

                // 3. Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Email", Icons.email),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 15),

                // 4. Tên hiển thị
                TextFormField(
                  controller: _displayNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Tên hiển thị (Nickname)", Icons.badge),
                  validator: _validateDisplayName,
                ),
                const SizedBox(height: 30),

                // Nút Đăng ký (Style giống nút Login)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent, // Màu hồng giống Login
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("ĐĂNG KÝ NGAY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Nút quay lại Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Đã có tài khoản? ", style: TextStyle(color: Colors.white60)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text("Đăng nhập", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}