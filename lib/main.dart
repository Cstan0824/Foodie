import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';
import 'package:taste_spot/features/collection/screens/collection_screen.dart';
import 'package:taste_spot/features/feed/screens/home_screen.dart';
import 'package:taste_spot/features/post/screens/add_post_screen.dart';
import 'package:taste_spot/features/profile/screens/profile_screen.dart';
import 'package:taste_spot/features/restaurant/screens/blind_box_screen.dart';
import 'package:app_links/app_links.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:taste_spot/core/services/account_service.dart';

// Global key for navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file.');
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    runApp(const FoodiApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class FoodiApp extends StatefulWidget {
  const FoodiApp({super.key});

  @override
  State<FoodiApp> createState() => _FoodiAppState();
}

class _FoodiAppState extends State<FoodiApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _requestNotificationPermissions();
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        try {
          final response = await Supabase.instance.client
              .from('User')
              .select('name, username, role, UserImage(image_url)')
              .eq('user_Id', session.user.id)
              .maybeSingle();
          
          if (response != null) {
            String? imageUrl;
            final userImages = response['UserImage'];
            if (userImages != null && userImages is List && userImages.isNotEmpty) {
              imageUrl = userImages[0]['image_url'];
            }

            await AccountService.saveAccount(
              userId: session.user.id,
              name: response['name'],
              username: response['username'],
              avatarUrl: imageUrl,
              role: response['role'] ?? 'user',
              sessionJson: jsonEncode(session.toJson()),
            );
          }
        } catch (e) {
          debugPrint('Error syncing session to AccountService: $e');
        }
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('Deep Link (Initial): $uri');
        _scheduleDeepLinkHandling(uri);
      }
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep Link (Stream): $uri');
      _handleDeepLink(uri);
    });
  }

  void _scheduleDeepLinkHandling(Uri uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'io.supabase.tastespot' || uri.scheme == 'tastespot') {
      String? userId;
      if (uri.queryParameters.containsKey('id')) {
        userId = uri.queryParameters['id'];
      }
      if (userId == null || userId.isEmpty) {
        final segments = uri.pathSegments;
        if (segments.contains('profile')) {
          final idx = segments.indexOf('profile');
          if (idx + 1 < segments.length) userId = segments[idx + 1];
        }
      }

      if (userId != null && userId.isNotEmpty) {
        _navigateToProfile(userId);
      }
    }
  }

  void _navigateToProfile(String userId) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      navigatorKey.currentState?.push(
        CupertinoPageRoute(builder: (_) => ProfileScreen(userId: userId)),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      navigatorKey: navigatorKey,
      title: 'Taste Spot',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const LoginScreen(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<HomeScreenState> homeKey = GlobalKey();
  final GlobalKey<ProfileScreenState> profileKey = GlobalKey();
  final GlobalKey<CollectionScreenState> collectionKey = GlobalKey();

  late final CupertinoTabController _tabController;
  int _lastNonAddTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddPost({required int returnToIndex}) async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => const AddPostScreen(),
      ),
    );

    if (!mounted) return;

    _tabController.index = returnToIndex;
    _lastNonAddTabIndex = returnToIndex;

    if (result == true) {
      homeKey.currentState?.loadPosts();
      profileKey.currentState?.loadUserPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white,
        activeColor: AppColors.primary,
        inactiveColor: AppColors.textLight,
        border: const Border(top: BorderSide(color: AppColors.tabBarBorder, width: 0.5)),
        onTap: (index) {
          if (index == 2) {
            final returnToIndex = _lastNonAddTabIndex;
            _tabController.index = returnToIndex;
            _showAddPost(returnToIndex: returnToIndex);
            return;
          }

          if (index != 2) {
            _lastNonAddTabIndex = index;
          }

          if (index == _tabController.index) {
            final key = _getNavigatorKey(index);
            key?.currentState?.popUntil((r) => r.isFirst);
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), activeIcon: Icon(CupertinoIcons.house_fill), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.bookmark), activeIcon: Icon(CupertinoIcons.bookmark_fill), label: 'Collection'),
          BottomNavigationBarItem(
            icon: Container(
              width: 46,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 22),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.gift), activeIcon: Icon(CupertinoIcons.gift_fill), label: 'Blind Box'),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), activeIcon: Icon(CupertinoIcons.person_fill), label: 'Profile'),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          navigatorKey: _getNavigatorKey(index),
          builder: (context) {
            switch (index) {
              case 0:
                return HomeScreen(key: homeKey);
              case 1:
                return CollectionScreen(key: collectionKey);
              case 2:
                return const CupertinoPageScaffold(
                  child: SizedBox.shrink(),
                );
              case 3:
                return const BlindBoxScreen();
              case 4:
                return ProfileScreen(key: profileKey);
              default:
                return const CupertinoPageScaffold(
                  child: SizedBox.shrink(),
                );
            }
          },
        );
      },
    );
  }

  final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  GlobalKey<NavigatorState>? _getNavigatorKey(int index) {
    if (index < 0 || index >= _navKeys.length) return null;
    return _navKeys[index];
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Error')),
        child: Center(child: Text(error)),
      ),
    );
  }
}
