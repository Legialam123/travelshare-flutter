import 'package:flutter/material.dart';
import 'package:travel_share/screens/home/home_screen.dart';
import 'package:travel_share/screens/profile/profile_screen.dart';
import 'package:travel_share/screens/payment/payment_screen.dart';
import 'package:travel_share/screens/notification/notification_screen.dart';
import '../widgets/popup_notification.dart';
import '../models/notification.dart';
import 'dart:async';
import '../services/stomp_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> 
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isNavigating = false;

  // Thêm GlobalKey cho NotificationScreen
  final GlobalKey<NotificationScreenState> _notificationKey =
      GlobalKey<NotificationScreenState>();
  final GlobalKey<HomeScreenState> _homeScreenKey = HomeScreen.globalKey;

  late final List<Widget> _screens;
  
  // Thêm subscription cho notification
  StreamSubscription<NotificationModel>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      HomeScreen(key: _homeScreenKey, onGroupDetailPop: _handleGroupDetailPop),
      PaymentScreen(key: const ValueKey('payment_screen')),
      NotificationScreen(key: _notificationKey),
      ProfileScreen(key: const ValueKey('profile_screen')),
    ];
    _initStomp();
  }

  void _initStomp() async {
    await StompService().connect();
    _notificationSubscription = StompService().notificationStream.listen(
      (notification) {
        if (!mounted) return;
        // Hiển thị popup notification
        PopupNotification.show(
          context,
          notification,
          onTap: () {
            setState(() => _selectedIndex = 2);
            _notificationKey.currentState?.reloadNotifications();
          },
        );
        // Reload notification screen ở background
        _notificationKey.currentState?.reloadNotifications();
      },
      onError: (e) {
        print('Lỗi nhận notification realtime: $e');
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    StompService().disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      StompService().connect();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      StompService().disconnect();
    }
  }

  // Hàm callback khi pop từ GroupDetailScreen
  void _handleGroupDetailPop() {
    // Chỉ reload notification ở background, không chuyển tab
    _notificationKey.currentState?.reloadNotifications();
  }
  
  // Đã xóa toàn bộ các đoạn code liên quan đến WebSocketService để chuẩn bị tích hợp lại STOMP.

  void _onItemTapped(int index) {
    if (_isNavigating || index == _selectedIndex) return;

    _isNavigating = true;
    setState(() => _selectedIndex = index);

    if (index == 0) {
      _homeScreenKey.currentState?.loadGroupsByCategory();
    }

    // Debounce navigation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isNavigating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Container(
            key: ValueKey(_selectedIndex),
            child: _screens[_selectedIndex],
          ),
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
                      _selectedIndex == 1 ? Icons.payment : Icons.payment_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  label: 'Thanh toán',
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
