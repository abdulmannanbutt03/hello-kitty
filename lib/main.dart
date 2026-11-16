import 'package:flutter/material.dart';

void main() {
  runApp(const HelloKittyApp());
}

const Color kPink = Color(0xFFFF8FB8);
const Color kDeepPink = Color(0xFFE91E78);
const Color kLightPink = Color(0xFFFFE4EE);

class HelloKittyApp extends StatelessWidget {
  const HelloKittyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Kitty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPink,
          primary: kDeepPink,
          secondary: kPink,
        ),
        scaffoldBackgroundColor: kLightPink,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPink,
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kDeepPink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hello Kitty 🎀')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎀', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 12),
            const Text(
              'Hello Kitty Chat',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: kDeepPink,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () {}, child: const Text('Shuru karein')),
          ],
        ),
      ),
    );
  }
}
