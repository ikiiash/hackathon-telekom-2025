import 'package:flutter/material.dart';
import 'package:namer_app/auth/auth_service.dart';
import 'package:namer_app/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // * get auth service
  final authService = AuthService();

  // * text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  //* login button pressed
  void login() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    try {
      await authService.signInWithEmailPassword(email, password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  // * BUILD UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),

            // ===== Input Card =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMinimalInput(
                    controller: _emailController,
                    label: "Email",
                  ),
                  _divider(),
                  _buildMinimalInput(
                    controller: _passwordController,
                    label: "Password",
                    obscure: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ===== Login Button =====
            ElevatedButton(
              onPressed: login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Login",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 20),

            // ===== Link to Register =====
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegisterPage(),
                ),
              ),
              child: const Center(
                child: Text(
                  "Don't have an account? Sign up here.",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ========== Minimal Input Field ==========
  Widget _buildMinimalInput({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: InputBorder.none,
        labelStyle: const TextStyle(
          fontSize: 15,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 0,
        thickness: 0.6,
        color: Colors.black12,
      );

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Center(
  //         child: Text('Login')),
  //     ),
  //     body: ListView(
  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 100),
  //       children: [
  //         TextField(
  //           controller: _emailController,
  //           decoration: const InputDecoration(
  //             labelText: 'Email',
  //           ),
  //         ),
  //         TextField(
  //           controller: _passwordController,
  //           decoration: const InputDecoration(
  //             labelText: 'Password',
  //           ),
  //           obscureText: true,
  //         ),
  //         const SizedBox(height: 12),

  //         ElevatedButton(
  //           onPressed: login,
  //           child: const Text('Login'),
  //         ),

  //         const SizedBox(height: 12),

  //         // * go to register page to sign up
  //         GestureDetector(
  //           onTap: () => Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (context) => const RegisterPage(),
  //               )),
  //           child: const Center(
  //               child: Text('Don\'t have an account? Sign up here.')),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
