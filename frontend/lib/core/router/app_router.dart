import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

// Screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/sos/presentation/screens/sos_screen.dart';
import '../../features/weather/presentation/screens/weather_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_detail_screen.dart';

class AppRouter {
  static const String loginPath = '/login';
  static const String registerPath = '/register';
  static const String dashboardPath = '/dashboard';
  static const String mapPath = '/map';
  static const String sosPath = '/sos';
  static const String weatherPath = '/weather';
  static const String profilePath = '/profile';

  static final GoRouter router = GoRouter(
    initialLocation: mapPath,
    redirect: (BuildContext context, GoRouterState state) async {
      final authBox = await Hive.openBox('auth_box');
      final token = authBox.get('jwt_token');
      final isAuthenticated = token != null;

      final loggingIn = state.matchedLocation == loginPath || state.matchedLocation == registerPath;

      if (!isAuthenticated && !loggingIn) {
        return loginPath;
      }
      if (isAuthenticated && loggingIn) {
        return mapPath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: loginPath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: registerPath,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: mapPath,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: sosPath,
        builder: (context, state) => const SosScreen(),
      ),
      GoRoute(
        path: weatherPath,
        builder: (context, state) => const WeatherScreen(),
      ),
      GoRoute(
        path: profilePath,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: dashboardPath,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:recipientId',
        builder: (context, state) {
          final idStr = state.pathParameters['recipientId'] ?? '0';
          final name = state.uri.queryParameters['name'] ?? 'Chat';
          return ChatDetailScreen(
            recipientId: int.parse(idStr),
            recipientName: name,
          );
        },
      ),
    ],
  );
}
