import 'package:flutter/material.dart';
import 'package:namer_app/auth/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // * get auth service
  final authService = AuthService();

  // * text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // * signUp button pressed
  void signUp() async {
    // * get email
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // * check if passwords match
    if (password != confirmPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
      }
      return;
    }
    // * attempt to sign up

    try {
      await authService.signUpWithEmailPassword(email, password);
      // * pop this register page
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Sign Up'),
        elevation: 0,
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
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
                  _divider(),
                  _buildMinimalInput(
                    controller: _confirmPasswordController,
                    label: "Confirm Password",
                    obscure: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ===== Sign Up button (minimalist) =====
            ElevatedButton(
              onPressed: signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Sign Up",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ========== Minimalist TextField ==========
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
  //       title: const Text('Sign Up'),
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
  //         TextField(
  //           controller: _confirmPasswordController,
  //           decoration: const InputDecoration(
  //             labelText: 'Confirm Password',
  //           ),
  //           obscureText: true,
  //         ),
  //         const SizedBox(height: 12),

  //         ElevatedButton(
  //           onPressed: signUp,
  //           child: const Text('Sign Up'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
