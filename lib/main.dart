import 'package:ai_interview_app/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vpczododcgvbnoxsbxny.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwY3pvZG9kY2d2Ym5veHNieG55Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4NDQwNzgsImV4cCI6MjA4MjQyMDA3OH0.eobSRkJoUqX7hNQj0M5NCtSj7WogjJgpLAGebpFF7sE',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Ninja',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}
