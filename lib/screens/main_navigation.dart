import 'package:flutter/material.dart';
import 'package:travel_share/screens/home/home_screen.dart';
import 'package:travel_share/screens/profile/profile_screen.dart';
import 'package:travel_share/screens/settlement/settlement_overview_screen.dart';
import 'package:travel_share/screens/request/request_screen.dart';
import 'package:travel_share/screens/notification/notification_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Thêm GlobalKey cho NotificationScreen
  final GlobalKey<NotificationScreenState> _notificationKey = GlobalKey<NotificationScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onGroupDetailPop: _handleGroupDetailPop),
      RequestScreen(),
      NotificationScreen(key: _notificationKey),
      ProfileScreen(),
    ];
  }

  // Hàm callback khi pop từ GroupDetailScreen
  void _handleGroupDetailPop() {
    // Chỉ reload notification ở background, không chuyển tab
    _notificationKey.currentState?.reloadNotifications();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 65, // 🎯 Fixed compact height
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), // 🎯 Smaller border radius
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.6),
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12, // 🎯 Smaller font size
                color: Colors.white,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11, // 🎯 Smaller font size
                color: Colors.white.withOpacity(0.6),
              ),
              selectedFontSize: 12, // 🎯 Explicit font size
              unselectedFontSize: 11, // 🎯 Explicit font size
              iconSize: 22, // 🎯 Smaller icon size
              showUnselectedLabels: true,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: [
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: _selectedIndex == 0
                        ? BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Icon(
                      _selectedIndex == 0
                          ? Icons.card_travel
                          : Icons.card_travel_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  label: 'Nhóm',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: _selectedIndex == 1
                        ? BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Icon(
                      _selectedIndex == 1
                          ? Icons.inbox
                          : Icons.inbox_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  label: 'Yêu cầu',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: _selectedIndex == 2
                        ? BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Icon(
                      _selectedIndex == 2
                          ? Icons.notifications
                          : Icons.notifications_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  label: 'Thông báo',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: _selectedIndex == 3
                        ? BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Icon(
                      _selectedIndex == 3 ? Icons.person : Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  label: 'Tài khoản',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
