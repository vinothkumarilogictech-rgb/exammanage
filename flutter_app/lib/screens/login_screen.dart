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
      duration: const Duration(milliseconds: 900),
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
      backgroundColor: const Color(0xFFF7F5FD),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final compact = h < 760;
          final veryCompact = h < 660;
          final headerHeight = veryCompact ? 190.0 : compact ? 225.0 : 265.0;

          return Stack(
            children: [
              // ---- Curved gradient header ----
              _CurvedHeader(height: headerHeight),

              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animation,
                      curve: Curves.easeOut,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: headerHeight - (veryCompact ? 78 : 92)),

                        // ---- Floating logo card ----
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .25),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: _LogoBadge(size: veryCompact ? 78 : 92),
                        ),

                        SizedBox(height: veryCompact ? 14 : 18),
                        Text(
                          'Exam Management',
                          style: TextStyle(
                            color: const Color(0xFF1F1533),
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _dash(),
                            const SizedBox(width: 8),
                            const Text(
                              'CONTROL PANEL',
                              style: TextStyle(
                                color: Color(0xFF7B14B5),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _dash(),
                          ],
                        ),

                        SizedBox(height: veryCompact ? 22 : 30),

                        // ---- Form card ----
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth < 420 ? 20 : 32,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _buildForm(auth, compact: compact, veryCompact: veryCompact),
                          ),
                        ),

                        SizedBox(height: veryCompact ? 18 : 26),
                        Text(
                          'iLOGIC TECH  |  Logic Group of Companies',
                          style: TextStyle(
                            color: const Color(0xFFA79BC4),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                        SizedBox(height: veryCompact ? 14 : 22),
                      ],
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

  Widget _dash() => Container(width: 24, height: 1.4, color: const Color(0xFFD9C7F0));

  Widget _buildForm(AuthProvider auth, {required bool compact, required bool veryCompact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        veryCompact ? 20 : 26,
        veryCompact ? 22 : 28,
        veryCompact ? 20 : 26,
        veryCompact ? 20 : 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9DDF7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F9A22C7),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Segmented mode switch ----
          Container(
            height: 50,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2ECFA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _modeTab(
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
                  child: _modeTab(
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

          SizedBox(height: veryCompact ? 20 : 26),

          _label(adminMode ? 'Admin Username' : 'Username'),
          const SizedBox(height: 8),
          _input(
            controller: user,
            icon: Icons.person_rounded,
            hint: 'Enter username',
            focused: userFocused,
            onFocus: (v) => setState(() => userFocused = v),
            action: TextInputAction.next,
          ),

          SizedBox(height: veryCompact ? 14 : 18),

          _label('Password'),
          const SizedBox(height: 8),
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
                obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: const Color(0xFF7B14B5),
                size: 21,
              ),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: Color(0xFF7B14B5),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          if (auth.error != null) ...[
            const SizedBox(height: 4),
            _error(auth.error!),
          ],

          SizedBox(height: veryCompact ? 10 : 14),
          _loginButton(auth, compact: compact),

          SizedBox(height: veryCompact ? 16 : 20),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: const Color(0xFFEBE2F7))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.verified_user_rounded, color: const Color(0xFF7B14B5), size: 18),
              ),
              Expanded(child: Container(height: 1, color: const Color(0xFFEBE2F7))),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Secure access for authorized staff only',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B6280),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: selected
            ? const LinearGradient(colors: [Color(0xFFB23BD6), Color(0xFF5A17B5)])
            : null,
        boxShadow: selected
            ? const [
                BoxShadow(color: Color(0x409A22C7), blurRadius: 10, offset: Offset(0, 4)),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? Colors.white : const Color(0xFF6B6280)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF6B6280),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4A3F66),
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
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
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? const Color(0xFF7B14B5) : const Color(0xFFE3D7F5),
          width: focused ? 1.6 : 1.1,
        ),
        boxShadow: focused
            ? const [BoxShadow(color: Color(0x229A22C7), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: Focus(
        onFocusChange: onFocus,
        child: TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: action,
          onSubmitted: onSubmitted,
          cursorColor: const Color(0xFF7B14B5),
          style: const TextStyle(
            color: Color(0xFF241B3D),
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF7B14B5), size: 21),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9C93B5), fontSize: 13.5),
            suffixIcon: suffix,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
          ),
        ),
      ),
    );
  }

  Widget _loginButton(AuthProvider auth, {required bool compact}) {
    return Container(
      height: compact ? 54 : 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(colors: [Color(0xFFB23BD6), Color(0xFF5A17B5)]),
        boxShadow: const [
          BoxShadow(color: Color(0x4D9A22C7), blurRadius: 18, offset: Offset(0, 8)),
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
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 21),
                      SizedBox(width: 10),
                      Text(
                        'Login',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
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
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFFBE123C), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// The real iLOGIC TECH "i" logo (assets/ilogictech_icon.png) on a white
/// disc, so the logo's own blue-to-magenta gradient renders exactly as
/// designed rather than an approximated redraw.
class _LogoBadge extends StatelessWidget {
  final double size;
  const _LogoBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x4D9A22C7), blurRadius: 30, spreadRadius: 1),
        ],
      ),
      padding: EdgeInsets.all(size * .2),
      child: Image.asset(
        'assets/ilogictech_icon.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Full-width curved gradient header behind the logo/card.
class _CurvedHeader extends StatelessWidget {
  final double height;
  const _CurvedHeader({required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8E3FD1), Color(0xFF5A17B5), Color(0xFF3D0F8C)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _blob(150, Colors.white.withOpacity(.10)),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _blob(180, Colors.white.withOpacity(.08)),
            ),
            Positioned(
              top: 30,
              left: 20,
              child: _blob(46, Colors.white.withOpacity(.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width * .5,
      size.height,
      size.width,
      size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
