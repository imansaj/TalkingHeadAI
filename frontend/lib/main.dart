import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/admin_screen.dart';

void main() {
  runApp(const TalkingHeadApp());
}

class TalkingHeadApp extends StatelessWidget {
  const TalkingHeadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ChatProvider())],
      child: MaterialApp(
        title: 'TalkingHeadAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            brightness: Brightness.dark,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const ChatScreen(),
          '/admin': (_) => const AdminScreen(),
        },
      ),
    );
  }
}
