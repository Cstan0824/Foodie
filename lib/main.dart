import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // 1. Handle initial link if app was closed
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('Deep Link (Initial): $uri');
        _scheduleDeepLinkHandling(uri);
      }
    });

    // 2. Listen for links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep Link (Stream): $uri');
      _handleDeepLink(uri);
    });
  }

  void _scheduleDeepLinkHandling(Uri uri) {
    // Wait for the navigator to be built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('--- Deep Link Received ---');
    debugPrint('Full URI: $uri');
    
    if (uri.scheme == 'io.supabase.tastespot' || uri.scheme == 'tastespot') {
      String? userId;
      
      // 1. Try to find 'id' in query parameters (Safe for both Safari & Chrome)
      if (uri.queryParameters.containsKey('id')) {
        userId = uri.queryParameters['id'];
      }
      
      // 2. Fallback: Check path segments for ID (Look for uuid-like pattern or segment after 'profile')
      if (userId == null || userId.isEmpty) {
        final segments = uri.pathSegments;
        if (segments.contains('profile')) {
          final idx = segments.indexOf('profile');
          if (idx + 1 < segments.length) {
            userId = segments[idx + 1];
          }
        } else if (segments.isNotEmpty) {
          // Check if first segment looks like a UUID
          final first = segments.first;
          if (first.length > 20) userId = first; 
        }
      }

      if (userId != null && userId.isNotEmpty) {
        debugPrint('Navigating to Profile: $userId');
        _navigateToProfile(userId);
      }
    }
  }

  void _navigateToProfile(String userId) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Not signed in -> Redirect to login
      navigatorKey.currentState?.pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      // Signed in -> Navigate to the specific profile
      navigatorKey.currentState?.push(
        CupertinoPageRoute(
          builder: (_) => ProfileScreen(userId: userId),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
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
      supportedLocales: const [
        Locale('en', 'US'),
      ],
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

  int _selectedTab = 0;

  int get _screenIndex {
    switch (_selectedTab) {
      case 1:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return 0;
    }
  }

  void _showAddPost() async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => const AddPostScreen(),
      ),
    );
    if (result == true && mounted) {
      setState(() => _selectedTab = 0);
      homeKey.currentState?.loadPosts();
      profileKey.currentState?.loadUserPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _screenIndex,
              children: [
                HomeScreen(key: homeKey),
                CollectionScreen(key: collectionKey),
                const BlindBoxScreen(),
                ProfileScreen(key: profileKey),
              ],
            ),
          ),
          _buildTabBar(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(top: BorderSide(color: AppColors.tabBarBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 49,
          child: Row(
            children: [
              _navItem(0, CupertinoIcons.house, CupertinoIcons.house_fill, 'Home'),
              _navItem(1, CupertinoIcons.bookmark, CupertinoIcons.bookmark_fill, 'Collection'),
              _addButton(),
              _navItem(3, CupertinoIcons.gift, CupertinoIcons.gift_fill, 'Blind Box'),
              _navItem(4, CupertinoIcons.person, CupertinoIcons.person_fill, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int tab, IconData icon, IconData activeIcon, String label) {
    final isActive = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selectedTab = tab);
          if (tab == 0) homeKey.currentState?.loadPosts(silent: true);
          if (tab == 1) collectionKey.currentState?.refreshCollections();
          if (tab == 4) profileKey.currentState?.loadUserPosts(silent: true);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showAddPost,
        child: Center(
          child: Container(
            width: 46,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 22),
          ),
        ),
      ),
    );
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
