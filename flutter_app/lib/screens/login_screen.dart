import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController(text: '1234');

  bool obscure = true;
  bool userFocused = false;
  bool passFocused = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.sizeOf(context);

    final bool isSmallScreen = size.height < 700;
    final double horizontalPadding = size.width < 380 ? 18 : 24;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF24005A),
      body: Stack(
        children: [
          // ============================================================
          // GLOWING BACKGROUND
          // ============================================================
          Positioned.fill(
            child: CustomPaint(
              painter: _LoginBackgroundPainter(),
            ),
          ),

          // Large blurred purple glow - top right
          Positioned(
            top: -150,
            right: -120,
            child: _glowCircle(
              size: 430,
              color: const Color(0xFFB14CFF),
              opacity: 0.18,
              blur: 80,
            ),
          ),

          // Large blurred blue/purple glow - bottom left
          Positioned(
            bottom: -180,
            left: -160,
            child: _glowCircle(
              size: 470,
              color: const Color(0xFF5B20FF),
              opacity: 0.22,
              blur: 90,
            ),
          ),

          // Center glow
          Positioned(
            top: size.height * 0.28,
            left: size.width * 0.15,
            child: _glowCircle(
              size: 260,
              color: const Color(0xFF8A2BE2),
              opacity: 0.10,
              blur: 100,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isSmallScreen ? 18 : 30,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 470,
                      ),
                      child: _buildLoginCard(
                        context,
                        auth,
                        isSmallScreen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // LOGIN CARD
  // ====================================================================

  Widget _buildLoginCard(
    BuildContext context,
    AuthProvider auth,
    bool isSmallScreen,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          // Outer purple glow
          BoxShadow(
            color: const Color(0xFFB13CFF).withOpacity(0.40),
            blurRadius: 45,
            spreadRadius: 4,
          ),

          // Dark shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.42),
            blurRadius: 50,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          color: Colors.white,
          border: Border.all(
            color: Colors.white.withOpacity(0.95),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 24 : 34,
            isSmallScreen ? 28 : 38,
            isSmallScreen ? 24 : 34,
            isSmallScreen ? 24 : 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ========================================================
              // LOGO
              // ========================================================

              _buildLogo(),

              SizedBox(height: isSmallScreen ? 18 : 25),

              // ========================================================
              // TITLE
              // ========================================================

              const Text(
                'Exam Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF17203A),
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),

              const SizedBox(height: 6),

              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFF5521C8),
                      Color(0xFF9A38FF),
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  'Control Panel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 25 : 34),

              // ========================================================
              // USERNAME
              // ========================================================

              _buildLabel('Username'),

              const SizedBox(height: 9),

              Focus(
                onFocusChange: (focused) {
                  if (mounted) {
                    setState(() => userFocused = focused);
                  }
                },
                child: _buildInputField(
                  controller: user,
                  icon: Icons.person_rounded,
                  hint: 'Enter username',
                  focused: userFocused,
                  textInputAction: TextInputAction.next,
                ),
              ),

              const SizedBox(height: 21),

              // ========================================================
              // PASSWORD
              // ========================================================

              _buildLabel('Password'),

              const SizedBox(height: 9),

              Focus(
                onFocusChange: (focused) {
                  if (mounted) {
                    setState(() => passFocused = focused);
                  }
                },
                child: _buildInputField(
                  controller: pass,
                  icon: Icons.lock_rounded,
                  hint: 'Enter password',
                  focused: passFocused,
                  obscure: obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: auth.loading
                      ? null
                      : (_) => auth.login(
                            user.text.trim(),
                            pass.text,
                          ),
                  suffix: IconButton(
                    tooltip: obscure
                        ? 'Show password'
                        : 'Hide password',
                    splashRadius: 24,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: const Color(0xFF6328C8),
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        obscure = !obscure;
                      });
                    },
                  ),
                ),
              ),

              // ========================================================
              // ERROR
              // ========================================================

              if (auth.error != null) ...[
                const SizedBox(height: 16),
                _buildError(auth.error!),
              ],

              const SizedBox(height: 27),

              // ========================================================
              // GLOWING LOGIN BUTTON
              // ========================================================

              _buildLoginButton(auth),

              SizedBox(height: isSmallScreen ? 22 : 30),

              // ========================================================
              // SECURITY DIVIDER
              // ========================================================

              _buildSecurityFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // LOGO
  // ====================================================================

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo icon
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5320C8),
                Color(0xFF8E2BFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C2FFF).withOpacity(0.35),
                blurRadius: 25,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Stylized "i"
              const Text(
                'i',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 62,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),

              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    _logoDot(7),
                    const SizedBox(width: 4),
                    _logoDot(5),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 13),

        // iLOGIC TECH
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'iLOGIC',
                style: TextStyle(
                  color: Color(0xFF3D159B),
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              TextSpan(
                text: ' TECH',
                style: TextStyle(
                  color: Color(0xFF7729D5),
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 3),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _logoLine(),
            const SizedBox(width: 9),
            const Text(
              'SMART SOLUTIONS',
              style: TextStyle(
                color: Color(0xFF5D27BC),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.1,
              ),
            ),
            const SizedBox(width: 9),
            _logoLine(),
          ],
        ),
      ],
    );
  }

  Widget _logoDot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
    );
  }

  Widget _logoLine() {
    return Container(
      width: 32,
      height: 1.5,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5520C6),
            Color(0xFF9A36FF),
          ],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ====================================================================
  // LABEL
  // ====================================================================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF59617B),
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    );
  }

  // ====================================================================
  // INPUT FIELD
  // ====================================================================

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool focused,
    bool obscure = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 68,
      decoration: BoxDecoration(
        color: focused
            ? const Color(0xFFFBF8FF)
            : const Color(0xFFF9F8FC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: focused
              ? const Color(0xFF7A2CDA)
              : const Color(0xFFD9D5E4),
          width: focused ? 1.8 : 1.2,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: const Color(0xFF7A2CDA).withOpacity(0.16),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Icon area
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 67,
            height: double.infinity,
            decoration: BoxDecoration(
              color: focused
                  ? const Color(0xFFEDE2FF)
                  : const Color(0xFFF0EAFE),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6026C6),
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              cursorColor: const Color(0xFF6D29D2),
              style: const TextStyle(
                color: Color(0xFF18213B),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF9295A4),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          if (suffix != null) suffix,

          const SizedBox(width: 7),
        ],
      ),
    );
  }

  // ====================================================================
  // ERROR
  // ====================================================================

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE11D48),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFBE123C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // GLOWING LOGIN BUTTON
  // ====================================================================

  Widget _buildLoginButton(AuthProvider auth) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF7B22E5),
            Color(0xFF5B19C9),
            Color(0xFF4520A8),
          ],
        ),
        boxShadow: [
          // Strong neon glow
          BoxShadow(
            color: const Color(0xFFA52BFF).withOpacity(0.48),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          ),

          // Deep shadow
          BoxShadow(
            color: const Color(0xFF4C16A5).withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          splashColor: Colors.white.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.07),
          onTap: auth.loading
              ? null
              : () {
                  FocusScope.of(context).unfocus();

                  auth.login(
                    user.text.trim(),
                    pass.text,
                  );
                },
          child: Center(
            child: auth.loading
                ? const SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: Colors.white.withOpacity(0.13),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // SECURITY FOOTER
  // ====================================================================

  Widget _buildSecurityFooter() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1.3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFB18CEB).withOpacity(0.55),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2E9FF),
                border: Border.all(
                  color: const Color(0xFFD9C3FF),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C2BD3).withOpacity(0.12),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF7530C7),
                size: 25,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Container(
                height: 1.3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFB18CEB).withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        const Text(
          'Secure access for authorized staff',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF68708A),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),

        const SizedBox(height: 5),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF7A31D0),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Protected Control Panel',
              style: TextStyle(
                color: Color(0xFF9B9EAD),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // GLOW CIRCLE
  // ====================================================================

  Widget _glowCircle({
    required double size,
    required Color color,
    required double opacity,
    required double blur,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(opacity),
              blurRadius: blur,
              spreadRadius: blur * 0.15,
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================
// CUSTOM BACKGROUND PAINTER
// ========================================================================

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ------------------------------------------------------------
    // Base gradient
    // ------------------------------------------------------------

    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF25005C),
          Color(0xFF4A0BA4),
          Color(0xFF6C19C9),
          Color(0xFF2A056A),
        ],
        stops: [
          0.0,
          0.35,
          0.65,
          1.0,
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      );

    canvas.drawRect(
      Offset.zero & size,
      backgroundPaint,
    );

    // ------------------------------------------------------------
    // Soft radial glows
    // ------------------------------------------------------------

    final glowPaint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC54BFF).withOpacity(0.34),
          const Color(0xFFC54BFF).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.13),
          radius: size.width * 0.48,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.13),
      size.width * 0.48,
      glowPaint1,
    );

    final glowPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF762DFF).withOpacity(0.34),
          const Color(0xFF762DFF).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.08, size.height * 0.83),
          radius: size.width * 0.55,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.83),
      size.width * 0.55,
      glowPaint2,
    );

    // ------------------------------------------------------------
    // Decorative dots - top left
    // ------------------------------------------------------------

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.fill;

    const double dotSpacing = 32;
    const double dotRadius = 2.1;

    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 6; col++) {
        final x = 22 + (col * dotSpacing);
        final y = 30 + (row * dotSpacing);

        final distance = math.sqrt(
          math.pow(x - 110, 2) +
              math.pow(y - 110, 2),
        );

        final opacity = math.max(
          0.08,
          0.42 - distance / 450,
        );

        final paint = Paint()
          ..color = Colors.white.withOpacity(opacity);

        canvas.drawCircle(
          Offset(x, y),
          dotRadius,
          paint,
        );
      }
    }

    // ------------------------------------------------------------
    // Decorative dots - right middle
    // ------------------------------------------------------------

    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 4; col++) {
        final x = size.width - 35 - (col * dotSpacing);
        final y = size.height * 0.45 + (row * dotSpacing);

        final paint = Paint()
          ..color = Colors.white.withOpacity(
            0.10 + (row % 3) * 0.04,
          );

        canvas.drawCircle(
          Offset(x, y),
          1.8,
          paint,
        );
      }
    }

    // ------------------------------------------------------------
    // Decorative circles - top right
    // ------------------------------------------------------------

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.15);

    final topRightCenter = Offset(
      size.width + 30,
      -30,
    );

    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        topRightCenter,
        90 + i * 38,
        ringPaint,
      );
    }

    // ------------------------------------------------------------
    // Decorative circles - bottom left
    // ------------------------------------------------------------

    final bottomLeftCenter = Offset(
      -40,
      size.height + 30,
    );

    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        bottomLeftCenter,
        100 + i * 45,
        ringPaint,
      );
    }

    // ------------------------------------------------------------
    // Decorative circles - bottom right
    // ------------------------------------------------------------

    final bottomRightCenter = Offset(
      size.width + 30,
      size.height - 60,
    );

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        bottomRightCenter,
        90 + i * 40,
        ringPaint,
      );
    }

    // ------------------------------------------------------------
    // Glowing diagonal curves
    // ------------------------------------------------------------

    final curvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFD98AFF).withOpacity(0.18);

    final path = Path();

    path.moveTo(
      size.width * 0.60,
      0,
    );

    path.cubicTo(
      size.width * 0.82,
      size.height * 0.12,
      size.width * 0.78,
      size.height * 0.28,
      size.width,
      size.height * 0.38,
    );

    canvas.drawPath(
      path,
      curvePaint,
    );

    final path2 = Path();

    path2.moveTo(
      0,
      size.height * 0.58,
    );

    path2.cubicTo(
      size.width * 0.16,
      size.height * 0.68,
      size.width * 0.05,
      size.height * 0.80,
      size.width * 0.24,
      size.height,
    );

    canvas.drawPath(
      path2,
      curvePaint,
    );

    // ------------------------------------------------------------
    // Small glowing stars
    // ------------------------------------------------------------

    _drawStar(
      canvas,
      Offset(size.width * 0.16, size.height * 0.24),
      4,
    );

    _drawStar(
      canvas,
      Offset(size.width * 0.86, size.height * 0.18),
      4.5,
    );

    _drawStar(
      canvas,
      Offset(size.width * 0.72, size.height * 0.84),
      3.5,
    );

    _drawStar(
      canvas,
      Offset(size.width * 0.10, size.height * 0.78),
      3,
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final glowPaint = Paint()
      ..color = const Color(0xFFE39AFF).withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        8,
      );

    canvas.drawCircle(
      center,
      radius * 1.8,
      glowPaint,
    );

    final paint = Paint()
      ..color = const Color(0xFFF0C4FF)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(
      center.dx,
      center.dy - radius,
    );

    path.lineTo(
      center.dx + radius * 0.30,
      center.dy - radius * 0.30,
    );

    path.lineTo(
      center.dx + radius,
      center.dy,
    );

    path.lineTo(
      center.dx + radius * 0.30,
      center.dy + radius * 0.30,
    );

    path.lineTo(
      center.dx,
      center.dy + radius,
    );

    path.lineTo(
      center.dx - radius * 0.30,
      center.dy + radius * 0.30,
    );

    path.lineTo(
      center.dx - radius,
      center.dy,
    );

    path.lineTo(
      center.dx - radius * 0.30,
      center.dy - radius * 0.30,
    );

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}