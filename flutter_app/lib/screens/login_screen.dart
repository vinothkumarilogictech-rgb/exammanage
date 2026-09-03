import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  bool adminMode = true;
  bool userFocused = false;
  bool passFocused = false;
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    _animation.dispose();
    super.dispose();
  }

  Future<void> _login(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    await auth.login(
      user.text.trim(),
      pass.text,
      adminMode: adminMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final compact = h < 700;
          final veryCompact = h < 610;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _LoginBackground(),
              SafeArea(
                child: Center(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animation,
                      curve: Curves.easeOut,
                    ),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .035),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 420 ? 18 : 28,
                          vertical: compact ? 10 : 22,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: _buildCard(
                            auth,
                            compact: compact,
                            veryCompact: veryCompact,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(
    AuthProvider auth, {
    required bool compact,
    required bool veryCompact,
  }) {
    final side = veryCompact ? 22.0 : compact ? 25.0 : 34.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x667A2B00),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x4DFF9B45),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(side, side, side, compact ? 20 : 27),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrand(compact: compact),
              SizedBox(height: veryCompact ? 12 : compact ? 17 : 23),
              Text(
                'Exam Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF351C00),
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'CONTROL PANEL',
                style: TextStyle(
                  color: Color(0xFFD6690C),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              SizedBox(height: veryCompact ? 12 : compact ? 15 : 20),
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEEDF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _loginTypeButton(
                        label: 'Admin',
                        icon: Icons.admin_panel_settings_rounded,
                        selected: adminMode,
                        onTap: () {
                          if (!adminMode) {
                            setState(() {
                              adminMode = true;
                              auth.error = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _loginTypeButton(
                        label: 'User',
                        icon: Icons.person_rounded,
                        selected: !adminMode,
                        onTap: () {
                          if (adminMode) {
                            setState(() {
                              adminMode = false;
                              auth.error = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: veryCompact ? 15 : compact ? 20 : 28),
              _label(adminMode ? 'Admin Username' : 'Username'),
              const SizedBox(height: 7),
              _input(
                controller: user,
                icon: Icons.person_rounded,
                hint: 'Enter username',
                focused: userFocused,
                onFocus: (v) => setState(() => userFocused = v),
                action: TextInputAction.next,
              ),
              SizedBox(height: veryCompact ? 12 : compact ? 15 : 19),
              _label('Password'),
              const SizedBox(height: 7),
              _input(
                controller: pass,
                icon: Icons.lock_rounded,
                hint: 'Enter password',
                focused: passFocused,
                obscure: obscure,
                onFocus: (v) => setState(() => passFocused = v),
                action: TextInputAction.done,
                onSubmitted: (_) {
                  if (!auth.loading) _login(auth);
                },
                suffix: IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: const Color(0xFFD6690C),
                    size: 22,
                  ),
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                _error(auth.error!),
              ],
              SizedBox(height: veryCompact ? 15 : compact ? 18 : 24),
              _loginButton(auth, compact: compact),
              SizedBox(height: compact ? 17 : 23),
              Row(
                children: [
                  Expanded(child: _line()),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFFE07A17),
                      size: 20,
                    ),
                  ),
                  Expanded(child: _line()),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Secure access for authorized staff',
                style: TextStyle(
                  color: const Color(0xFF6E6458),
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'iLOGIC TECH  |  SMART SOLUTIONS',
                style: TextStyle(
                  color: const Color(0xFFB8A88F),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginTypeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFE07A17) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF806E58),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF806E58),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand({required bool compact}) {
    final size = compact ? 67.0 : 78.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BrandMark(size: size),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'iLOGIC',
                    style: TextStyle(
                      color: Color(0xFF9B3D00),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: ' TECH',
                    style: TextStyle(
                      color: Color(0xFFE0742C),
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(width: 21, height: 1.2, color: const Color(0xFFE28A3A)),
                const SizedBox(width: 6),
                const Text(
                  'SMART SOLUTIONS',
                  style: TextStyle(
                    color: Color(0xFFC9691D),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B5E4E),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _input({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool focused,
    required ValueChanged<bool> onFocus,
    bool obscure = false,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 57,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: focused ? const Color(0xFFDC7A1F) : const Color(0xFFEBDDCA),
          width: focused ? 1.7 : 1.1,
        ),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: Color(0x25DC7A1F),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 57,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDDA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            child: Icon(icon, color: const Color(0xFFC96A15), size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Focus(
              onFocusChange: onFocus,
              child: TextField(
                controller: controller,
                obscureText: obscure,
                textInputAction: action,
                onSubmitted: onSubmitted,
                cursorColor: const Color(0xFFC96A15),
                style: const TextStyle(
                  color: Color(0xFF33291D),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: Color(0xFFAEA18C),
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          if (suffix != null) suffix,
          const SizedBox(width: 5),
        ],
      ),
    );
  }

  Widget _loginButton(AuthProvider auth, {required bool compact}) {
    return Container(
      height: compact ? 56 : 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9A2E), Color(0xFFE0630C)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4DE07A17),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: auth.loading ? null : () => _login(auth),
          child: Center(
            child: auth.loading
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 23),
                      SizedBox(width: 11),
                      Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _error(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F4),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFFFCDD5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFE11D48), size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFBE123C),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _line() => Container(height: 1, color: const Color(0xFFF0E4D2));
}

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
          colors: [Color(0xFFFFA84D), Color(0xFFD65A18)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52E2821A),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'i',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * .70,
              height: .9,
              fontWeight: FontWeight.w900,
            ),
          ),
          Positioned(
            top: size * .20,
            right: size * .20,
            child: Row(
              children: [
                _dot(size * .075),
                SizedBox(width: size * .035),
                _dot(size * .055),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double value) => Container(
        width: value,
        height: value,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      );
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BackgroundPainter());
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B1600), Color(0xFF7F3B00), Color(0xFFC66A1B), Color(0xFF481A00)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final centers = [
      Offset(size.width * .90, size.height * .08),
      Offset(size.width * .04, size.height * .88),
    ];
    for (final center in centers) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFB25E).withOpacity(.30), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * .58));
      canvas.drawCircle(center, size.width * .58, glow);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.065);
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width + 20, -20),
        100 + i * 42,
        ring,
      );
      canvas.drawCircle(
        Offset(-20, size.height + 20),
        110 + i * 45,
        ring,
      );
    }

    final dot = Paint()..color = Colors.white.withOpacity(.11);
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 5; col++) {
        canvas.drawCircle(Offset(18 + col * 34, 20 + row * 34), 1.4, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
