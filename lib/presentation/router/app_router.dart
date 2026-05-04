import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/home/main_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/search/filters_screen.dart';
import '../screens/property/property_detail_screen.dart';
import '../screens/property/publish_property_screen.dart';
import '../screens/chat/conversations_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/payment/payment_confirmation_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/alerts/create_alert_screen.dart';

part 'app_router.g.dart';

// Routes nommées
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const home = '/home';
  static const search = '/search';
  static const filters = '/filters';
  static const propertyDetail = '/property/:id';
  static const publishProperty = '/publish-property';
  static const conversations = '/conversations';
  static const chat = '/chat/:conversationId';
  static const payment = '/payment/:leaseId';
  static const paymentConfirmation = '/payment-confirmation';
  static const documents = '/documents';
  static const analytics = '/analytics';
  static const profile = '/profile';
  static const settings = '/settings';
  static const alerts = '/alerts';
  static const createAlert = '/create-alert';
}

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final supabase = Supabase.instance.client;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentUser != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.otp ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && state.matchedLocation == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      // Shell principal avec Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.conversations,
            builder: (_, __) => const ConversationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (_, __) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      // Routes sans bottom nav
      GoRoute(
        path: AppRoutes.filters,
        builder: (_, __) => const FiltersScreen(),
      ),
      GoRoute(
        path: AppRoutes.propertyDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PropertyDetailScreen(propertyId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.publishProperty,
        builder: (_, __) => const PublishPropertyScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ChatScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) {
          final leaseId = state.pathParameters['leaseId']!;
          return PaymentScreen(leaseId: leaseId);
        },
      ),
      GoRoute(
        path: AppRoutes.paymentConfirmation,
        builder: (context, state) {
          final paymentId = state.uri.queryParameters['paymentId'] ?? '';
          return PaymentConfirmationScreen(paymentId: paymentId);
        },
      ),
      GoRoute(
        path: AppRoutes.documents,
        builder: (_, __) => const DocumentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.alerts,
        builder: (_, __) => const AlertsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createAlert,
        builder: (_, __) => const CreateAlertScreen(),
      ),
    ],
  );
}