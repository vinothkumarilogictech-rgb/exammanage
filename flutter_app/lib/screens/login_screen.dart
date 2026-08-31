import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController(text: '1234');
  bool obscure = true;
  bool userFocused = false;
  bool passFocused = false;
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF8E4FC9), Color(0xFFB37FE0)],
              ),
            ),
          ),
          // Decorative blurred circles
          Positioned(
            top: -80, left: -60,
            child: _blob(220, Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -100, right: -70,
            child: _blob(280, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            top: 120, right: -40,
            child: _blob(120, Colors.white.withOpacity(0.07)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.97),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF9B59D9)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.45),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.school_rounded, size: 42, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Exam Management',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Control Panel',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, letterSpacing: 0.4),
                            ),
                            const SizedBox(height: 30),
                            _label('Username'),
                            const SizedBox(height: 6),
                            Focus(
                              onFocusChange: (f) => setState(() => userFocused = f),
                              child: _field(
                                controller: user,
                                icon: Icons.person_outline_rounded,
                                focused: userFocused,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _label('Password'),
                            const SizedBox(height: 6),
                            Focus(
                              onFocusChange: (f) => setState(() => passFocused = f),
                              child: _field(
                                controller: pass,
                                icon: Icons.lock_outline_rounded,
                                focused: passFocused,
                                obscure: obscure,
                                suffix: IconButton(
                                  icon: Icon(
                                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Colors.grey.shade500,
                                  ),
                                  onPressed: () => setState(() => obscure = !obscure),
                                ),
                              ),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.red.withOpacity(0.25)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(auth.error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                                  ),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 26),
                            SizedBox(
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF9B59D9)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: auth.loading ? null : () async => auth.login(user.text, pass.text),
                                    child: Center(
                                      child: auth.loading
                                          ? const SizedBox(
                                              width: 22, height: 22,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                                            )
                                          : const Text(
                                              'Login',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Secure access for authorized staff only',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
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

  Widget _label(String text) => Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.3),
      );

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _field({
    required TextEditingController controller,
    required IconData icon,
    required bool focused,
    bool obscure = false,
    Widget? suffix,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF6F5FA),
        border: Border.all(
          color: focused ? AppColors.primary : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: Icon(icon, size: 20, color: focused ? AppColors.primary : Colors.grey.shade500),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}