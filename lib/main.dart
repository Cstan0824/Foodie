import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/collection_screen.dart';
import 'views/screens/blind_box_screen.dart';
import 'views/screens/profile_screen.dart';
import 'views/screens/add_post_screen.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const FoodiApp());
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

  void _showAddPost() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => const AddPostScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Screen content ──
        Expanded(
          child: IndexedStack(
            index: _screenIndex,
            children: const [
              HomeScreen(),
              CollectionScreen(),
              BlindBoxScreen(),
              ProfileScreen(),
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
        onTap: () => setState(() => _selectedTab = tab),
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
