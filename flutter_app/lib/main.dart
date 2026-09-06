import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/branch_context.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.checkSession();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => BranchContext()),
      ],
      child: const OfficeApp(),
    ),
  );
}

class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Exam Management',
    theme: appTheme(),
    home: const StartupSplash(),
  );
}

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.78,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const RootScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashBackground(),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BrandMark(size: 112),
                    const SizedBox(height: 24),
                    const Text(
                      'iLOGIC TECH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 1,
                          color: Colors.white.withOpacity(.45),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'SMART SOLUTIONS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.78),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 32,
                          height: 1,
                          color: Colors.white.withOpacity(.45),
                        ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    Container(
                      width: 72,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC77DF0), Color(0xFF7B14B5)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF9A22C7),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'EXAM MANAGEMENT',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Text(
              'Loading your secure workspace',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.42),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: .4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.authenticated
        ? const AppShell()
        : LoginScreen(initialAdminMode: auth.lastRole != 'Employee');
  }
}

/// Brand mark: the real iLOGIC TECH "i" logo (assets/ilogictech_icon.png),
/// shown on a white disc so the logo's own blue-to-magenta gradient reads
/// exactly as designed, regardless of the background behind it.
class _BrandMark extends StatelessWidget {
  final double size;

  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.24), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x805A17B5), blurRadius: 34, spreadRadius: 6),
        ],
      ),
      padding: EdgeInsets.all(size * .2),
      child: Image.asset('assets/ilogictech_icon.png', fit: BoxFit.contain),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SplashPainter());
  }
}

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF120B4A),
          Color(0xFF2A1470),
          Color(0xFF7B14B5),
          Color(0xFF1A0A3D),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final glows = [
      (Offset(size.width * .12, size.height * .12), size.width * .48),
      (Offset(size.width * .88, size.height * .82), size.width * .58),
      (Offset(size.width * .50, size.height * .48), size.width * .42),
    ];

    for (final glow in glows) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9A22C7).withOpacity(.24),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: glow.$1, radius: glow.$2));
      canvas.drawCircle(glow.$1, glow.$2, paint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = -2; i < 7; i++) {
      final path = Path()
        ..moveTo(i * 90, size.height)
        ..quadraticBezierTo(
          size.width * .45,
          size.height * .52,
          size.width + i * 90,
          0,
        );
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = Colors.white.withOpacity(.13);
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 6; col++) {
        canvas.drawCircle(Offset(24 + col * 34, 30 + row * 34), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
