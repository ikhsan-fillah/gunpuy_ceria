import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'screens/home/home_page.dart';
import 'screens/warga/warga_page.dart';
import 'screens/sppt/sppt_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    WargaPage(),
    SpptPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) =>
            setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySurface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded,
                color: AppColors.primary),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded,
                color: AppColors.primary),
            label: 'Warga',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon:
                Icon(Icons.map_rounded, color: AppColors.primary),
            label: 'SPPT',
          ),
        ],
      ),
    );
  }
}
