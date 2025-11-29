import 'package:flutter/material.dart';
import 'package:namer_app/config/supabase_config.dart';
import 'package:namer_app/pages/chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file BEFORE accessing SupabaseConfig
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustAI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      // Temporarily bypass auth - go directly to chat
      home: const ChatPage(),
      // Uncomment this line when you want to re-enable auth:
      // home: AuthGate(),
    );
  }
}

