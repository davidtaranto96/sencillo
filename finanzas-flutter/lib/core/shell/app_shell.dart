import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/database/database_providers.dart';
import '../../core/providers/shell_providers.dart';
import '../../core/providers/tab_config_provider.dart';
import '../../core/widgets/tab_config_sheet.dart';
import '../../core/providers/feedback_provider.dart';
import '../../core/providers/mercado_pago_provider.dart';
import '../../core/providers/friend_requests_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/transactions/presentation/widgets/add_transaction_bottom_sheet.dart';
import '../../features/budget/presentation/pages/budget_page.dart';
import '../../features/budget/presentation/widgets/add_budget_bottom_sheet.dart';
import '../../features/goals/presentation/pages/goals_page.dart';
import '../../features/goals/presentation/widgets/add_goal_bottom_sheet.dart';
import '../../features/more/presentation/pages/more_page.dart';
import '../../features/monthly_overview/presentation/pages/monthly_overview_page.dart';
import '../../features/people/presentation/pages/people_page.dart';
import '../../features/wishlist/presentation/pages/wishlist_page.dart';
import '../../features/wishlist/presentation/widgets/add_wishlist_bottom_sheet.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/goals/presentation/pages/savings_page.dart';
import '../services/notification_service.dart';
import '../logic/recurring_service.dart';
import '../widgets/app_fab.dart';
import '../logic/transaction_service.dart';
import '../widgets/success_overlay.dart';
import '../widgets/ai_assistant_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  List<String> _lastTabConfig = [];

  /// Maps original tab IDs to their GoRouter branch index (only first 5)
  static const _tabToBranch = <String, int>{
    'home': 0,
    'transactions': 1,
    'budget': 2,
    'goals': 3,
    'more': 4,
  };

  static const _branchToTab = <int, String>{
    0: 'home',
    1: 'transactions',
    2: 'budget',
    3: 'goals',
    4: 'more',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);
    // Schedule notifications on app start + check for in-app alerts + MP auto-sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).refreshAll(ref);
      ref.read(recurringServiceProvider).processRecurrings();
      _checkInAppAlerts();
      _tryAutoSyncMercadoPago();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Forzar rebuild de streams al volver del background para evitar pantalla negra
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(accountsStreamProvider);
        ref.invalidate(transactionsStreamProvider);
      });
    }
  }

  /// Check for upcoming card due dates and pending debts, add in-app notifications
  Future<void> _checkInAppAlerts() async {
    final db = ref.read(databaseProvider);
    final notifCenter = ref.read(notificationCenterProvider.notifier);
    final now = DateTime.now();

    // Check credit card closing dates
    final accounts = await db.select(db.accountsTable).get();
    for (final acc in accounts) {
      if (acc.type == 'credit' && acc.closingDay != null) {
        final closingDay = acc.closingDay!;
        final daysUntil = closingDay >= now.day
            ? closingDay - now.day
            : (DateTime(now.year, now.month + 1, 0).day - now.day) + closingDay;

        if (daysUntil <= 5 && daysUntil > 0) {
          notifCenter.add(AppNotification(
            id: 'card_due_${acc.id}_${now.month}',
            title: '💳 ${acc.name}',
            body: 'Cierra en $daysUntil día${daysUntil == 1 ? "" : "s"} (día $closingDay)',
            type: 'card_due',
            createdAt: now,
            relatedId: acc.id,
          ));
        }
      }
    }

    // Check pending debts with people
    final persons = await db.select(db.personsTable).get();
    for (final p in persons) {
      if (p.totalBalance.abs() > 100) {
        final owesMe = p.totalBalance > 0;
        final amount = p.totalBalance.abs().toStringAsFixed(0);
        notifCenter.add(AppNotification(
          id: 'debt_${p.id}_${now.day}',
          title: owesMe ? '🔔 ${p.name} te debe' : '🔔 Le debés a ${p.name}',
          body: '\$$amount pendiente',
          type: 'debt_remind',
          createdAt: now,
          relatedId: p.id,
        ));
      }
    }
  }

  /// Silent MP auto-sync on app open (15-min cooldown, won't interrupt user)
  Future<void> _tryAutoSyncMercadoPago() async {
    try {
      final db = ref.read(databaseProvider);
      await autoSyncMercadoPago(db);
    } catch (_) {
      // Silencioso — no interrumpir al usuario
    }
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync PageView when router navigates externally (deep link)
    final newBranch = widget.navigationShell.currentIndex;
    final oldBranch = oldWidget.navigationShell.currentIndex;
    if (newBranch != oldBranch) {
      final tabId = _branchToTab[newBranch];
      if (tabId != null) {
        final enabledTabs = ref.read(tabConfigProvider);
        final pageIdx = enabledTabs.indexOf(tabId);
        if (pageIdx >= 0 && pageIdx != _currentPage) {
          _pageController.jumpToPage(pageIdx);
        }
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    final enabledTabs = ref.read(tabConfigProvider);
    if (index >= enabledTabs.length) return;

    final tabId = enabledTabs[index];

    // Clear search when leaving transactions
    if (tabId != 'transactions' && ref.read(txSearchActiveProvider)) {
      ref.read(txSearchActiveProvider.notifier).state = false;
      ref.read(txSearchQueryProvider.notifier).state = '';
      _searchController.clear();
    }

    // Marcar alertas como leídas al visitar Más
    if (tabId == 'more') {
      ref.read(notificationCenterProvider.notifier).markAllAsRead();
    }

    // Sync with GoRouter for the 5 original branch tabs
    final branch = _tabToBranch[tabId];
    if (branch != null) {
      widget.navigationShell.goBranch(
        branch,
        initialLocation: branch == widget.navigationShell.currentIndex,
      );
    }
  }

  void _onTap(int pageIndex) {
    appHaptic(ref, type: HapticType.selection);
    appSound(ref, type: SoundType.nav);
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabledTabIds = ref.watch(tabConfigProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final fabBottom = bottomPadding + 90.0;
    final txSearchActive = ref.watch(txSearchActiveProvider);
    // Selector: solo rebuilda cuando isEmpty cambia (no en cada item add/remove)
    final hasBudgets = ref.watch(budgetsStreamProvider.select((v) => (v.valueOrNull?.isNotEmpty) ?? false));
    final hasGoals = ref.watch(goalsStreamProvider.select((v) => (v.valueOrNull?.isNotEmpty) ?? false));
    // Badge counts
    final friendReqCount = ref.watch(friendRequestCountProvider).valueOrNull ?? 0;
    final unreadAlerts = ref.watch(unreadNotificationCountProvider);

    // Handle tab config changes (user modified settings)
    if (!_listEquals(enabledTabIds, _lastTabConfig)) {
      _lastTabConfig = List.from(enabledTabIds);
      if (_currentPage >= enabledTabIds.length) {
        _currentPage = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }
    }

    // Handle external tab navigation requests via listener
    ref.listen<String?>(navigateToTabProvider, (prev, next) {
      if (next == null) return;
      final idx = enabledTabIds.indexOf(next);
      // Reset immediately so we don't re-trigger
      Future.microtask(() => ref.read(navigateToTabProvider.notifier).state = null);
      if (idx >= 0 && idx != _currentPage && _pageController.hasClients) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubicEmphasized,
        );
      } else if (idx < 0) {
        // Tab not in navbar — push standalone page with back button + own FAB
        final Widget standaloneWidget = switch (next) {
          'people' => const PeoplePage(standalone: true),
          _ => _pageForTab(next),
        };
        if (standaloneWidget is! SizedBox) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => standaloneWidget),
          );
        }
      }
    });

    // Build visible tab items for nav bar (con badge counts)
    final visibleTabs = enabledTabIds.map((id) {
      int badge = 0;
      if (id == 'people') {
        badge = friendReqCount;
      } else if (id == 'more') {
        badge = unreadAlerts;
      }
      return _TabItem(
        id: id,
        label: kTabInfo[id]!.label,
        icon: kTabInfo[id]!.icon,
        badgeCount: badge,
      );
    }).toList();

    // Current tab info
    final currentTabId =
        _currentPage < enabledTabIds.length ? enabledTabIds[_currentPage] : 'home';

    // ── FAB configuration based on current tab ──
    IconData? fabIcon;
    VoidCallback? fabAction;
    VoidCallback? fabLongPress;
    VoidCallback? fabDoubleTap;

    switch (currentTabId) {
      case 'home':
        fabIcon = Icons.auto_awesome_rounded;
        fabAction = () => AddTransactionBottomSheet.show(context);
        fabLongPress = () => AddTransactionBottomSheet.show(context, startWithVoice: true);
        fabDoubleTap = () async {
          final txs = ref.read(transactionsStreamProvider).valueOrNull;
          final lastTx = txs != null && txs.isNotEmpty ? txs.first : null;
          if (lastTx == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No hay movimientos para duplicar')),
              );
            }
            return;
          }
          appHaptic(ref, type: HapticType.medium);
          await ref.read(transactionServiceProvider).duplicateTransaction(lastTx.id);
          appSound(ref, type: SoundType.success);
          if (context.mounted) {
            await SuccessOverlay.show(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${lastTx.title}" duplicado'),
                  backgroundColor: AppTheme.colorTransfer.withValues(alpha: 0.85),
                ),
              );
            }
          }
        };
      case 'transactions':
        if (!txSearchActive) {
          fabIcon = Icons.search_rounded;
          fabAction = () {
            appHaptic(ref, type: HapticType.light);
            appSound(ref, type: SoundType.tap);
            ref.read(txSearchActiveProvider.notifier).state = true;
          };
        }
      case 'budget':
        if (hasBudgets) {
          fabIcon = Icons.add_rounded;
          fabAction = () {
            appHaptic(ref, type: HapticType.medium);
            appSound(ref, type: SoundType.tap);
            AddBudgetBottomSheet.show(context);
          };
        }
      case 'goals':
        if (hasGoals) {
          fabIcon = Icons.add_rounded;
          fabAction = () {
            appHaptic(ref, type: HapticType.medium);
            appSound(ref, type: SoundType.tap);
            AddGoalBottomSheet.show(context);
          };
        }
      case 'people':
        fabIcon = Icons.add_rounded;
        fabAction = () {
          appHaptic(ref, type: HapticType.medium);
          appSound(ref, type: SoundType.tap);
          showPeopleFabMenu(context, ref);
        };
      case 'wishlist':
        fabIcon = Icons.add_shopping_cart_rounded;
        fabAction = () {
          appHaptic(ref, type: HapticType.medium);
          appSound(ref, type: SoundType.tap);
          AddWishlistBottomSheet.show(context);
        };
      case 'accounts':
        fabIcon = Icons.add_rounded;
        fabAction = () {
          appHaptic(ref, type: HapticType.medium);
          appSound(ref, type: SoundType.tap);
          ref.read(addAccountRequestProvider.notifier).state++;
        };
      case 'monthly_overview':
      case 'reports':
      case 'savings':
      case 'more':
        // No FAB en estas tabs
        break;
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── PageView for swiping between tabs ──
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: enabledTabIds.map(_pageForTab).toList(),
          ),

          // ── AI Assistant button (only when enabled in settings) ──
          if (ref.watch(aiAssistantEnabledProvider))
            Positioned(
              left: 16,
              bottom: fabBottom,
              child: GestureDetector(
                onTap: () => showAiAssistantSheet(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF5ECFB1)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),

          // ── Morphing FAB — always in tree, animated in/out ──
          Positioned(
            right: 16,
            bottom: fabBottom,
            child: AnimatedOpacity(
              opacity: fabAction != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: AnimatedScale(
                scale: fabAction != null ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubicEmphasized,
                child: IgnorePointer(
                  ignoring: fabAction == null,
                  child: AppFab(
                    icon: fabIcon ?? Icons.add_rounded,
                    onPressed: fabAction ?? () {},
                    onLongPress: fabLongPress,
                    onDoubleTap: fabDoubleTap,
                  ),
                ),
              ),
            ),
          ),

          // ── Search bar (transactions tab only) ──
          if (currentTabId == 'transactions' && txSearchActive)
            Positioned(
              left: 0,
              right: 0,
              bottom: fabBottom,
              child: _SearchBar(
                controller: _searchController,
                onClose: () {
                  ref.read(txSearchActiveProvider.notifier).state = false;
                  ref.read(txSearchQueryProvider.notifier).state = '';
                  _searchController.clear();
                },
                onChanged: (v) =>
                    ref.read(txSearchQueryProvider.notifier).state = v,
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding + 12),
        child: GestureDetector(
          // Swipe on nav bar to switch tabs
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -300 && _currentPage < enabledTabIds.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            } else if (velocity > 300 && _currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          },
          child: _FloatingNavBar(
            currentIndex: _currentPage,
            tabs: visibleTabs,
            onTap: _onTap,
            pageController: _pageController,
            onLongPress: () {
              appHaptic(ref, type: HapticType.medium);
              appSound(ref, type: SoundType.tap);
              showTabConfigSheet(context, ref);
            },
          ),
        ),
      ),
    );
  }

  Widget _pageForTab(String tabId) {
    switch (tabId) {
      case 'home':
        return const HomePage();
      case 'transactions':
        return const TransactionsPage();
      case 'budget':
        return const BudgetPage();
      case 'goals':
        return const GoalsPage();
      case 'more':
        return const MorePage();
      case 'monthly_overview':
        return const MonthlyOverviewPage();
      case 'people':
        return const PeoplePage();
      case 'wishlist':
        return const WishlistPage();
      case 'reports':
        return const ReportsPage();
      case 'accounts':
        return const AccountsPage();
      case 'savings':
        return const SavingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// AppFab is defined in lib/core/widgets/app_fab.dart

// ─────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;
  const _SearchBar(
      {required this.controller, required this.onClose, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C).withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded,
                    size: 18,
                    color: AppTheme.colorTransfer.withValues(alpha: 0.8)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: onChanged,
                    style:
                        GoogleFonts.inter(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar movimientos...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: Colors.white38),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 44,
                    height: 54,
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Floating Nav Bar
// ─────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;
  final VoidCallback? onLongPress;
  final PageController? pageController;
  const _FloatingNavBar(
      {required this.currentIndex, required this.tabs, required this.onTap, this.onLongPress, this.pageController});

  @override
  Widget build(BuildContext context) {
    final showLabels = tabs.length < 6;
    final barHeight = showLabels ? 70.0 : 60.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF18181F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.04), width: 0.8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final tabWidth = tabs.isNotEmpty ? totalWidth / tabs.length : 0.0;
              const indicatorW = 16.0;

              return Stack(
                children: [
                  Row(
                    children: tabs
                        .asMap()
                        .entries
                        .map((e) => Expanded(
                              child: _NavItem(
                                  tab: e.value,
                                  selected: e.key == currentIndex,
                                  showLabel: showLabels,
                                  onTap: () => onTap(e.key),
                                  onLongPress: onLongPress),
                            ))
                        .toList(),
                  ),
                  // Sliding indicator
                  if (tabs.isNotEmpty)
                    AnimatedBuilder(
                      animation: pageController ?? const AlwaysStoppedAnimation(0),
                      builder: (context, _) {
                        final page = (pageController?.hasClients ?? false)
                            ? (pageController!.page ?? currentIndex.toDouble())
                            : currentIndex.toDouble();
                        final left = page * tabWidth + (tabWidth - indicatorW) / 2;
                        return Positioned(
                          left: left,
                          bottom: showLabels ? 6 : 5,
                          child: Container(
                            width: indicatorW,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.colorTransfer,
                              borderRadius: BorderRadius.circular(1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.colorTransfer.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Nav Item
// ─────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final _TabItem tab;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _NavItem(
      {required this.tab, required this.selected, this.showLabel = true, required this.onTap, this.onLongPress});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _bounceScale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOutCubicEmphasized),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  void _onLongPress() {
    _bounceCtrl.forward().then((_) => _bounceCtrl.reverse());
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: _onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _bounceScale,
        builder: (context, child) => Transform.scale(
          scale: _bounceScale.value,
          child: child,
        ),
        child: SizedBox(
        height: widget.showLabel ? 70 : 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tap ripple circle
            AnimatedBuilder(
              animation: _scale,
              builder: (context, child) => Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        Colors.white.withValues(alpha: 0.12 * _scale.value),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono con badge de alerta
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(widget.tab.icon,
                          key: ValueKey(isSelected),
                          size: widget.showLabel
                              ? (isSelected ? 24 : 22)
                              : (isSelected ? 26 : 24),
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.32)),
                    ),
                    if (widget.tab.badgeCount > 0)
                      Positioned(
                        top: -5,
                        right: -7,
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: const Color(0xFF18181F), width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.tab.badgeCount > 9 ? '9+' : '${widget.tab.badgeCount}',
                              style: GoogleFonts.inter(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.showLabel) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.tab.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.32),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Spacer for indicator area (indicator is rendered in _FloatingNavBar)
                const SizedBox(height: 7,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab Item data
// ─────────────────────────────────────────────
class _TabItem {
  final String id;
  final String label;
  final IconData icon;
  final int badgeCount;
  const _TabItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });
}
