
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/budget/presentation/pages/budget_page.dart';
import '../../features/goals/presentation/pages/goals_page.dart';
import '../../features/more/presentation/pages/more_page.dart';
import '../../features/monthly_overview/presentation/pages/monthly_overview_page.dart';
import '../../features/people/presentation/pages/people_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/wishlist/presentation/pages/wishlist_page.dart';
import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/accounts/presentation/pages/account_detail_page.dart';
import '../../features/transactions/presentation/pages/transaction_detail_page.dart';
import '../../features/goals/presentation/pages/savings_page.dart';
import '../shell/app_shell.dart';

/// Key del Navigator interno del ShellRoute — usado por AppShell para cerrar modales
final shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budget',
                builder: (context, state) => const BudgetPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MorePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/monthly_overview',
        builder: (context, state) => const MonthlyOverviewPage(standalone: true),
      ),
      GoRoute(
        path: '/people',
        builder: (context, state) => const PeoplePage(standalone: true),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountsPage(),
      ),
      GoRoute(
        path: '/accounts/:accountId',
        builder: (context, state) => AccountDetailPage(
          accountId: state.pathParameters['accountId']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/savings',
        builder: (context, state) => const SavingsPage(),
      ),
      GoRoute(
        path: '/transactions/:txId',
        builder: (context, state) => TransactionDetailPage(
          txId: state.pathParameters['txId']!,
        ),
      ),
    ],
  );
});
