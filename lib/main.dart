import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:namer_app/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cmeubftrgoajnnouvmfd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtZXViZnRyZ29ham5ub3V2bWZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyNTk4MzQsImV4cCI6MjA3OTgzNTgzNH0.G-nSY36nK1B1y2d2TaQQpKbqj_hIU2i4DWayUUby7fg',
  );

  runApp(DevicePreview(builder: (context) => MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(),
    );
  }
}
