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
    _scale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

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
                          colors: [Color(0xFFFFB74D), Color(0xFFFF6D00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFF9800),
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
    return auth.authenticated ? const AppShell() : const LoginScreen();
  }
}

/// Brand mark: the same swoosh "i" used on the login screen (angled flag
/// top, curved stem, hook tail, offset dot), drawn with CustomPaint and
/// filled white on top of the orange gradient disc.
class _BrandMark extends StatelessWidget {
  final double size;

  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB300), Color(0xFFE65100)],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(.24),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80FF9800),
            blurRadius: 34,
            spreadRadius: 6,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .17),
      child: CustomPaint(
        size: Size(size, size),
        painter: _SwooshIPainter(),
      ),
    );
  }
}

/// Hand-traced swoosh "i" path (angled flag top, curved stem, hook tail,
/// offset dot) - same shape used on the login screen's logo badge.
class _SwooshIPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxW = 44.0;
    const boxH = 92.0;
    final scale = (size.width / boxW) < (size.height / boxH)
        ? size.width / boxW
        : size.height / boxH;
    final dx = (size.width - boxW * scale) / 2;
    final dy = (size.height - boxH * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final paint = Paint()..color = Colors.white;

    // Dot of the "i"
    canvas.drawCircle(const Offset(25, 10), 8, paint);

    // Stem + curled hook tail, traced as one continuous outline
    final path = Path()
      ..moveTo(28, 24)
      ..lineTo(13, 32)
      ..cubicTo(9, 40, 7, 55, 7, 68)
      ..cubicTo(7, 81, 12, 91, 23, 91)
      ..cubicTo(33, 91, 41, 85, 38, 75)
      ..cubicTo(36, 81, 29, 84, 22, 80)
      ..cubicTo(29, 78, 32, 68, 32, 55)
      ..cubicTo(32, 44, 30, 32, 28, 24)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          Color(0xFF3A1600),
          Color(0xFF7A2F00),
          Color(0xFFE65C00),
          Color(0xFF2A0E00),
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
            const Color(0xFFFF9800).withOpacity(.24),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: glow.$1, radius: glow.$2),
        );
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
        canvas.drawCircle(
          Offset(24 + col * 34, 30 + row * 34),
          1.5,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
