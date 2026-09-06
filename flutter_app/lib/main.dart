import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/branch_context.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/dio_client.dart';


// ============================================================
// FCM TOKEN STATE
// ============================================================

String? _latestFcmToken;

bool _isRegisteringFcmToken = false;

String? _lastRegisteredFcmToken;


// ============================================================
// FIREBASE FCM BACKGROUND MESSAGE HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('==============================================');
    debugPrint('BACKGROUND NOTIFICATION RECEIVED');
    debugPrint('Message ID: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
    debugPrint('==============================================');
  } catch (e) {
    debugPrint('Background Firebase error: $e');
  }
}


// ============================================================
// REGISTER FCM TOKEN WITH BACKEND
// ============================================================

Future<void> registerFcmTokenWithBackend(
    String token) async {
  try {
    // --------------------------------------------------------
    // Prevent duplicate simultaneous registration
    // --------------------------------------------------------

    if (_isRegisteringFcmToken) {
      debugPrint(
        'FCM REGISTRATION ALREADY IN PROGRESS',
      );
      return;
    }

    // --------------------------------------------------------
    // If same token was already registered
    // --------------------------------------------------------

    if (_lastRegisteredFcmToken == token) {
      debugPrint(
        'FCM TOKEN ALREADY REGISTERED',
      );
      return;
    }

    _isRegisteringFcmToken = true;

    final dioClient = DioClient();

    // --------------------------------------------------------
    // Check access token
    // --------------------------------------------------------

    final accessToken =
        await dioClient.readAccessToken();

    if (accessToken == null ||
        accessToken.isEmpty) {
      debugPrint(
        'FCM TOKEN NOT REGISTERED - USER NOT LOGGED IN',
      );

      _isRegisteringFcmToken = false;
      return;
    }

    // --------------------------------------------------------
    // Register FCM token with Flask backend
    // --------------------------------------------------------

    debugPrint('==============================================');
    debugPrint(
      'REGISTERING FCM TOKEN WITH BACKEND...',
    );
    debugPrint('Token: $token');
    debugPrint('==============================================');

    final response =
        await dioClient.registerDeviceToken(
      token: token,
      platform: 'android',
    );

    // --------------------------------------------------------
    // Success
    // --------------------------------------------------------

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      _lastRegisteredFcmToken = token;

      debugPrint('==============================================');
      debugPrint(
        'FCM TOKEN REGISTERED IN BACKEND',
      );
      debugPrint(
        'Status: ${response.statusCode}',
      );
      debugPrint(
        'Response: ${response.data}',
      );
      debugPrint('==============================================');
    } else {
      debugPrint('==============================================');
      debugPrint(
        'FCM TOKEN REGISTRATION FAILED',
      );
      debugPrint(
        'Status: ${response.statusCode}',
      );
      debugPrint(
        'Response: ${response.data}',
      );
      debugPrint('==============================================');
    }
  } catch (e) {
    debugPrint('==============================================');
    debugPrint(
      'FCM TOKEN REGISTER FAILED',
    );
    debugPrint('$e');
    debugPrint('==============================================');
  } finally {
    _isRegisteringFcmToken = false;
  }
}


// ============================================================
// REGISTER TOKEN ONLY WHEN USER IS LOGGED IN
// ============================================================

Future<void> registerFcmTokenIfLoggedIn(
    AuthProvider auth) async {
  try {
    if (!auth.authenticated) {
      debugPrint(
        'FCM REGISTRATION WAITING - USER NOT LOGGED IN',
      );
      return;
    }

    if (_latestFcmToken == null ||
        _latestFcmToken!.isEmpty) {
      debugPrint(
        'FCM REGISTRATION WAITING - TOKEN NOT AVAILABLE',
      );
      return;
    }

    debugPrint('==============================================');
    debugPrint(
      'USER LOGGED IN - REGISTERING FCM TOKEN',
    );
    debugPrint('==============================================');

    await registerFcmTokenWithBackend(
      _latestFcmToken!,
    );
  } catch (e) {
    debugPrint(
      'FCM login registration error: $e',
    );
  }
}


// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // ----------------------------------------------------------
  // Initialize Firebase
  // ----------------------------------------------------------

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('==============================================');
    debugPrint('FIREBASE INITIALIZED');
    debugPrint('==============================================');
  } catch (e) {
    debugPrint(
      'Firebase initialization error: $e',
    );
  }


  // ----------------------------------------------------------
  // Local Notification Service
  // ----------------------------------------------------------

  if (!kIsWeb) {
    try {
      await NotificationService.initialize();

      debugPrint('==============================================');
      debugPrint(
        'LOCAL NOTIFICATION SERVICE INITIALIZED',
      );
      debugPrint('==============================================');
    } catch (e) {
      debugPrint(
        'Local notification initialization error: $e',
      );
    }
  }


  // ----------------------------------------------------------
  // FCM SETUP
  // ----------------------------------------------------------

  if (!kIsWeb) {
    try {
      // ------------------------------------------------------
      // Background handler
      // ------------------------------------------------------

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );


      final messaging =
          FirebaseMessaging.instance;


      // ------------------------------------------------------
      // Notification permission
      // ------------------------------------------------------

      final permission =
          await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('==============================================');
      debugPrint(
        'FCM PERMISSION STATUS',
      );
      debugPrint(
        '${permission.authorizationStatus}',
      );
      debugPrint('==============================================');


      // ------------------------------------------------------
      // Get FCM device token
      // ------------------------------------------------------

      final token =
          await messaging.getToken();


      if (token != null &&
          token.isNotEmpty) {
        _latestFcmToken = token;

        debugPrint('==============================================');
        debugPrint('FCM DEVICE TOKEN');
        debugPrint(token);
        debugPrint('==============================================');
      } else {
        debugPrint(
          'FCM TOKEN IS NULL OR EMPTY',
        );
      }


      // ------------------------------------------------------
      // Token refresh
      // ------------------------------------------------------

      FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          debugPrint('==============================================');
          debugPrint('FCM TOKEN REFRESHED');
          debugPrint(newToken);
          debugPrint('==============================================');

          // Save latest token
          _latestFcmToken = newToken;

          // --------------------------------------------------
          // Try registering refreshed token
          // If user is logged in, it will register.
          // --------------------------------------------------

          final dioClient = DioClient();

          final accessToken =
              await dioClient.readAccessToken();

          if (accessToken != null &&
              accessToken.isNotEmpty) {
            await registerFcmTokenWithBackend(
              newToken,
            );
          } else {
            debugPrint(
              'REFRESHED TOKEN WAITING FOR LOGIN',
            );
          }
        },
      );


      // ------------------------------------------------------
      // Foreground notification
      // ------------------------------------------------------

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          debugPrint('==============================================');
          debugPrint(
            'FOREGROUND NOTIFICATION RECEIVED',
          );
          debugPrint('==============================================');

          debugPrint(
            'Title: ${message.notification?.title}',
          );

          debugPrint(
            'Body: ${message.notification?.body}',
          );

          debugPrint(
            'Data: ${message.data}',
          );

          debugPrint('==============================================');


          // --------------------------------------------------
          // Show local notification while app is open
          // --------------------------------------------------

          final notification =
              message.notification;

          if (notification != null) {
            try {
              await NotificationService.showNotification(
                title: notification.title ??
                    'Payment Reminder',
                body: notification.body ?? '',
              );

              debugPrint(
                'FOREGROUND LOCAL NOTIFICATION SHOWN',
              );
            } catch (e) {
              debugPrint(
                'Foreground local notification error: $e',
              );
            }
          }
        },
      );


      // ------------------------------------------------------
      // Notification tapped while app is in background
      // ------------------------------------------------------

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint('==============================================');
          debugPrint(
            'NOTIFICATION TAPPED',
          );
          debugPrint('==============================================');

          debugPrint(
            'Title: ${message.notification?.title}',
          );

          debugPrint(
            'Body: ${message.notification?.body}',
          );

          debugPrint(
            'Data: ${message.data}',
          );

          debugPrint('==============================================');

          // Later:
          // Navigate using:
          //
          // message.data['payment_id']
        },
      );


      // ------------------------------------------------------
      // App opened by tapping notification
      // ------------------------------------------------------

      final initialMessage =
          await FirebaseMessaging.instance
              .getInitialMessage();

      if (initialMessage != null) {
        debugPrint('==============================================');
        debugPrint(
          'APP OPENED FROM NOTIFICATION',
        );
        debugPrint('==============================================');

        debugPrint(
          'Title: ${initialMessage.notification?.title}',
        );

        debugPrint(
          'Body: ${initialMessage.notification?.body}',
        );

        debugPrint(
          'Data: ${initialMessage.data}',
        );

        debugPrint('==============================================');

        // Later:
        // Navigate using:
        //
        // initialMessage.data['payment_id']
      }
    } catch (e) {
      debugPrint(
        'FCM setup error: $e',
      );
    }
  }


  // ----------------------------------------------------------
  // Existing Authentication
  // ----------------------------------------------------------

  final auth = AuthProvider();

  await auth.checkSession();


  // ==========================================================
  // IMPORTANT FCM + LOGIN CONNECTION
  // ==========================================================

  // ----------------------------------------------------------
  // If user is already logged in
  // ----------------------------------------------------------

  if (auth.authenticated) {
    debugPrint('==============================================');
    debugPrint(
      'USER ALREADY LOGGED IN',
    );
    debugPrint(
      'CHECKING FCM TOKEN REGISTRATION...',
    );
    debugPrint('==============================================');

    await registerFcmTokenIfLoggedIn(auth);
  }


  // ----------------------------------------------------------
  // Listen for login/logout changes
  //
  // When LoginScreen successfully logs in and
  // AuthProvider calls notifyListeners(), this listener
  // automatically runs.
  // ----------------------------------------------------------

  auth.addListener(() {
    debugPrint('==============================================');
    debugPrint(
      'AUTH STATE CHANGED',
    );
    debugPrint(
      'Authenticated: ${auth.authenticated}',
    );
    debugPrint('==============================================');

    if (auth.authenticated) {
      unawaited(
        registerFcmTokenIfLoggedIn(auth),
      );
    }
  });


  // ----------------------------------------------------------
  // Run Flutter Application
  // ----------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: auth,
        ),

        ChangeNotifierProvider(
          create: (_) => BranchContext(),
        ),
      ],

      child: const OfficeApp(),
    ),
  );
}


// ============================================================
// OFFICE APP
// ============================================================

class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Exam Management',

      theme: appTheme(),

      home: const StartupSplash(),
    );
  }
}


// ============================================================
// STARTUP SPLASH
// ============================================================

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() =>
      _StartupSplashState();
}


class _StartupSplashState
    extends State<StartupSplash>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  late final Animation<double> _fade;

  late final Animation<double> _scale;


  @override
  void initState() {
    super.initState();


    // --------------------------------------------------------
    // Animation Controller
    // --------------------------------------------------------

    _controller = AnimationController(
      vsync: this,

      duration: const Duration(
        milliseconds: 1700,
      ),
    )..forward();


    // --------------------------------------------------------
    // Fade Animation
    // --------------------------------------------------------

    _fade = CurvedAnimation(
      parent: _controller,

      curve: Curves.easeOut,
    );


    // --------------------------------------------------------
    // Scale Animation
    // --------------------------------------------------------

    _scale = Tween<double>(
      begin: 0.78,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,

        curve: Curves.easeOutBack,
      ),
    );


    // --------------------------------------------------------
    // Move to Root Screen
    // --------------------------------------------------------

    Timer(
      const Duration(
        milliseconds: 2200,
      ),
      () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (
                _,
                __,
                ___,
              ) =>
                  const RootScreen(),

              transitionDuration: const Duration(
                milliseconds: 500,
              ),

              transitionsBuilder: (
                _,
                animation,
                __,
                child,
              ) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,

                    curve: Curves.easeOut,
                  ),

                  child: child,
                );
              },
            ),
          );
        }
      },
    );
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
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [

                    const _BrandMark(
                      size: 112,
                    ),


                    const SizedBox(
                      height: 24,
                    ),


                    const Text(
                      'iLOGIC TECH',

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 32,

                        fontWeight:
                            FontWeight.w900,

                        letterSpacing: 1.4,
                      ),
                    ),


                    const SizedBox(
                      height: 8,
                    ),


                    Row(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [

                        Container(
                          width: 32,

                          height: 1,

                          color: Colors.white
                              .withOpacity(.45),
                        ),


                        const SizedBox(
                          width: 12,
                        ),


                        Text(
                          'SMART SOLUTIONS',

                          style: TextStyle(
                            color: Colors.white
                                .withOpacity(.78),

                            fontSize: 10,

                            fontWeight:
                                FontWeight.w700,

                            letterSpacing: 3.0,
                          ),
                        ),


                        const SizedBox(
                          width: 12,
                        ),


                        Container(
                          width: 32,

                          height: 1,

                          color: Colors.white
                              .withOpacity(.45),
                        ),
                      ],
                    ),


                    const SizedBox(
                      height: 44,
                    ),


                    Container(
                      width: 72,

                      height: 4,

                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),

                        gradient:
                            const LinearGradient(
                          colors: [
                            Color(0xFFC77DF0),
                            Color(0xFF7B14B5),
                          ],
                        ),

                        boxShadow:
                            const [
                          BoxShadow(
                            color:
                                Color(0xFF9A22C7),

                            blurRadius: 16,

                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(
                      height: 18,
                    ),


                    Text(
                      'EXAM MANAGEMENT',

                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(.58),

                        fontSize: 11,

                        fontWeight:
                            FontWeight.w700,

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

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                color: Colors.white
                    .withOpacity(.42),

                fontSize: 11,

                fontWeight:
                    FontWeight.w500,

                letterSpacing: .4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// ROOT SCREEN
// ============================================================

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});


  @override
  Widget build(BuildContext context) {

    final auth =
        context.watch<AuthProvider>();


    return auth.authenticated
        ? const AppShell()
        : const LoginScreen();
  }
}


// ============================================================
// BRAND MARK
// ============================================================

class _BrandMark
    extends StatelessWidget {

  final double size;


  const _BrandMark({
    required this.size,
  });


  @override
  Widget build(BuildContext context) {

    return Container(
      width: size,

      height: size,

      decoration: BoxDecoration(
        color: Colors.white,

        shape: BoxShape.circle,

        border: Border.all(
          color: Colors.white
              .withOpacity(.24),

          width: 1.5,
        ),

        boxShadow: const [
          BoxShadow(
            color: Color(0x805A17B5),

            blurRadius: 34,

            spreadRadius: 6,
          ),
        ],
      ),

      padding: EdgeInsets.all(
        size * .2,
      ),

      child: Image.asset(
        'assets/ilogictech_icon.png',

        fit: BoxFit.contain,
      ),
    );
  }
}


// ============================================================
// SPLASH BACKGROUND
// ============================================================

class _SplashBackground
    extends StatelessWidget {

  const _SplashBackground();


  @override
  Widget build(BuildContext context) {

    return CustomPaint(
      painter: _SplashPainter(),
    );
  }
}


// ============================================================
// SPLASH PAINTER
// ============================================================

class _SplashPainter
    extends CustomPainter {

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {

    final rect =
        Offset.zero & size;


    // --------------------------------------------------------
    // Base Gradient
    // --------------------------------------------------------

    final base = Paint()
      ..shader =
          const LinearGradient(

        begin:
            Alignment.topLeft,

        end:
            Alignment.bottomRight,

        colors: [
          Color(0xFF120B4A),
          Color(0xFF2A1470),
          Color(0xFF7B14B5),
          Color(0xFF1A0A3D),
        ],
      ).createShader(rect);


    canvas.drawRect(
      rect,
      base,
    );


    // --------------------------------------------------------
    // Glow Effects
    // --------------------------------------------------------

    final glows = [
      (
        Offset(
          size.width * .12,
          size.height * .12,
        ),

        size.width * .48,
      ),

      (
        Offset(
          size.width * .88,
          size.height * .82,
        ),

        size.width * .58,
      ),

      (
        Offset(
          size.width * .50,
          size.height * .48,
        ),

        size.width * .42,
      ),
    ];


    for (final glow in glows) {

      final paint = Paint()
        ..shader =
            RadialGradient(

          colors: [
            const Color(0xFF9A22C7)
                .withOpacity(.24),

            Colors.transparent,
          ],

        ).createShader(
          Rect.fromCircle(
            center: glow.$1,

            radius: glow.$2,
          ),
        );


      canvas.drawCircle(
        glow.$1,

        glow.$2,

        paint,
      );
    }


    // --------------------------------------------------------
    // Curved Lines
    // --------------------------------------------------------

    final linePaint = Paint()
      ..color =
          Colors.white.withOpacity(.055)

      ..style =
          PaintingStyle.stroke

      ..strokeWidth = 1;


    for (int i = -2; i < 7; i++) {

      final path = Path()

        ..moveTo(
          i * 90,
          size.height,
        )

        ..quadraticBezierTo(

          size.width * .45,

          size.height * .52,

          size.width + i * 90,

          0,
        );


      canvas.drawPath(
        path,
        linePaint,
      );
    }


    // --------------------------------------------------------
    // Dots
    // --------------------------------------------------------

    final dotPaint = Paint()
      ..color =
          Colors.white.withOpacity(.13);


    for (int row = 0;
        row < 8;
        row++) {

      for (int col = 0;
          col < 6;
          col++) {

        canvas.drawCircle(

          Offset(
            24 + col * 34,
            30 + row * 34,
          ),

          1.5,

          dotPaint,
        );
      }
    }
  }


  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}