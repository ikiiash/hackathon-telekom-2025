import 'package:flutter/material.dart';
import 'package:namer_app/auth/auth_service.dart';
import '../widgets/dotted_background.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // * get Auth service
  final authService = AuthService();
  // * logout button pressed
  void logout() async {
    await authService.signOut();
    // Navigate back to root (AuthGate) which will redirect to LoginPage
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = authService.getCurrentUserEmail() ?? 'User';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black87,
      ),
      body: DottedBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
          children: [
            const SizedBox(height: 20),

            // === Minimal Avatar ===
            CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white,
              child: Text(
                userEmail[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // === Email ===
            Text(
              userEmail,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 30),

            // === Card Items (Minimal) ===
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMinimalItem(
                    icon: Icons.person_outline,
                    text: "Account",
                    onTap: () {},
                  ),
                  _divider(),
                  _buildMinimalItem(
                    icon: Icons.settings_outlined,
                    text: "Settings",
                    onTap: () {},
                  ),
                  _divider(),
                  _buildMinimalItem(
                    icon: Icons.info_outline,
                    text: "About",
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // === Minimal Logout Button ===
            TextButton.icon(
              onPressed: logout,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                "Logout",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

// ========== Minimalist item widget ==========
  Widget _buildMinimalItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 18, color: Colors.black26),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(
        height: 0,
        indent: 16,
        endIndent: 16,
        thickness: 0.6,
        color: Colors.black12,
      );

//   @override
//   Widget build(BuildContext context) {
// // * get user email
// final userEmail = authService.getCurrentUserEmail() ?? 'User';

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Profile'),
//         actions: [
//   // * logout button
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: logout,
//           )
//         ],
//       ),

//       body:  Center(
//         child: Text('Welcome to your profile! $userEmail'),
//       )
//     );
}
