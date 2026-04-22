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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load .env file
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file.');
    }

    // Initialise Supabase
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    runApp(const FoodiApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Configuration Error'),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 64, color: CupertinoColors.systemRed),
                const SizedBox(height: 24),
                const Text(
                  'Failed to initialize app',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please ensure your .env file exists in the project root and contains valid SUPABASE_URL and SUPABASE_ANON_KEY.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FoodiApp extends StatelessWidget {
  const FoodiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Foodi',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en', 'US'),
      ],
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: LoginScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Main shell — custom bottom tab bar + screens
// ─────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<HomeScreenState> homeKey = GlobalKey();
  final GlobalKey<ProfileScreenState> profileKey = GlobalKey();

  // Active tab: 0=Home, 1=Collection, 3=BlindBox, 4=Profile (2=Add, never stored)
  int _selectedTab = 0;

  // Maps nav tab index to IndexedStack screen index
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
    return Column(
      children: [
        // ── Screen content ──
        Expanded(
          child: IndexedStack(
            index: _screenIndex,
            children: [
              HomeScreen(key: homeKey),
              const CollectionScreen(),
              const BlindBoxScreen(),
              ProfileScreen(key: profileKey),
            ],
          ),
        ),
        // ── Custom bottom tab bar ──
        _buildTabBar(),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(
          top: BorderSide(color: AppColors.tabBarBorder, width: 0.5),
        ),
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
                  color: AppColors.primary.withValues(alpha: 0.38),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.add,
              color: CupertinoColors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
