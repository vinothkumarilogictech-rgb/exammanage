import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.checkSession();
  runApp(ChangeNotifierProvider.value(value: auth, child: const OfficeApp()));
}

class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Exam Management',
    theme: appTheme(),
    home: const RootScreen(),
  );
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.authenticated ? const AppShell() : const LoginScreen();
  }
}
