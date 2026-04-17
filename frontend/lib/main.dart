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
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF09090B),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            onPrimary: Color(0xFFFAFAFA),
            secondary: Color(0xFF3B82F6),
            onSecondary: Color(0xFFFAFAFA),
            surface: Color(0xFF18181B),
            onSurface: Color(0xFFFAFAFA),
            error: Color(0xFFEF4444),
            onError: Color(0xFFFAFAFA),
            outline: Color(0xFF27272A),
            surfaceContainerHighest: Color(0xFF27272A),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF09090B),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Color(0xFFFAFAFA),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF18181B),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
          ),
          dividerColor: const Color(0xFF27272A),
          dialogBackgroundColor: const Color(0xFF18181B),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF27272A),
            contentTextStyle: TextStyle(color: Color(0xFFFAFAFA)),
          ),
          tabBarTheme: const TabBarThemeData(
            indicatorColor: Color(0xFF3B82F6),
            labelColor: Color(0xFFFAFAFA),
            unselectedLabelColor: Color(0xFF71717A),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFFFAFAFA)),
            bodyMedium: TextStyle(color: Color(0xFFA1A1AA)),
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
