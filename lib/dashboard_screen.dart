import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sidebar_widget.dart';
import 'upload_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const UploadScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          SidebarWidget(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
                _pageController.jumpToPage(index);
              });
            },
          ),
          // Main Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}