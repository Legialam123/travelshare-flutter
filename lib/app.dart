import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settlement/suggested_settlements_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'screens/expense/edit_expense_screen.dart';

class TravelShareApp extends StatelessWidget {
  final bool isLoggedIn;
  final GlobalKey<NavigatorState> navigatorKey;

  const TravelShareApp({
    Key? key,
    required this.isLoggedIn,
    required this.navigatorKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider()..checkLoginStatus(),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'TravelShare',
            theme: ThemeData(primarySwatch: Colors.blue),
            home: isLoggedIn ? const MainNavigation() : const LoginScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
              '/home': (_) => const HomeScreen(),
              '/main-navigation': (_) => const MainNavigation(),
              '/edit-expense': (context) {
                final expenseId =
                    ModalRoute.of(context)!.settings.arguments as int;
                return EditExpenseScreen(expenseId: expenseId);
              },
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/suggested-settlements') {
                final args = settings.arguments as Map<String, dynamic>;
                final groupId = args['groupId'] as int;
                final userOnly = args['userOnly'] as bool? ?? false;

                return MaterialPageRoute(
                  builder: (_) => SuggestedSettlementsScreen(
                    groupId: groupId,
                    userOnly: userOnly,
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
