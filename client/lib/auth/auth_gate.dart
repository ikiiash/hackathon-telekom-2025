/*
 * AUTH GATE - this will continuosly listen to auth state changes.

 * unauthenticated -> Login Page
 * authenticated -> Chat Page
 */

import 'package:flutter/material.dart';
import 'package:namer_app/pages/login_page.dart';
import 'package:namer_app/pages/chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      //* Listen to auth state changes
      stream: Supabase.instance.client.auth.onAuthStateChange,
      // * Build appropriate page based on auth state
      builder: (context, snapshot) {
        // *loadding
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(
            child: CircularProgressIndicator(),
          ));
        }

        // * Check if there is a valid session curretly
        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session != null) {
          // * User is authenticated
          return const ChatPage();
        } else {
          // * User is not authenticated
          return const LoginPage();
        }
      },
    );
  }
}
