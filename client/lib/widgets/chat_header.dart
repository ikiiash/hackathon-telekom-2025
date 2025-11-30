import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback onNewChatPressed;

  const ChatHeader({
    super.key,
    required this.onMenuPressed,
    required this.onProfilePressed,
    required this.onNewChatPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Menu button (hamburger)
            IconButton(
              icon: const Icon(Icons.menu_outlined),
              onPressed: onMenuPressed,
              tooltip: 'Menu',
            ),
            
            const SizedBox(width: 8),
            
            // App title
            const Text(
              'TrustAI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const Spacer(),
            
            // Profile button
            InkWell(
              onTap: onProfilePressed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
