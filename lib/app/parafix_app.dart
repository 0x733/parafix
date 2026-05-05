import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/parafix_theme.dart';
import '../features/compose/add_expense_sheet.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/report/report_screen.dart';
import '../features/settings/personalization_sheet.dart';
import '../models/expense_category.dart';
import '../models/expense_entry.dart';
import '../models/monthly_payment.dart';

const _appIconAssetPath =
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png';

class ParafixApp extends StatefulWidget {
  const ParafixApp({super.key});

  @override
  State<ParafixApp> createState() => _ParafixAppState();
}

class _ParafixAppState extends State<ParafixApp> {
  static const _themeStorageKey = 'parafix_theme_preset_v1';
  static const _customCategoriesStorageKey = 'parafix_custom_categories_v1';
  static const _entriesStorageKey = 'parafix_entries_v1';
  static const _monthlyPaymentsStorageKey = 'parafix_monthly_payments_v1';
  static const _onboardingStorageKey = 'parafix_has_seen_onboarding_v1';

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final PageController _pageController;
  late final ValueNotifier<List<ExpenseEntry>> _entriesNotifier;
  late final ValueNotifier<List<MonthlyPayment>> _monthlyPaymentsNotifier;
  late final ValueNotifier<int> _tabIndexNotifier;
  OverlayEntry? _feedbackEntry;
  Timer? _feedbackTimer;

  final List<ExpenseCategory> _coreCategories = [
    ExpenseCategory(
      id: 'market',
      name: 'Market',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF5B8C5A),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'food',
      name: 'Yeme İçme',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFD86F45),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'transport',
      name: 'Ulaşım',
      icon: Icons.directions_bus_rounded,
      color: const Color(0xFF4A6FA5),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'bills',
      name: 'Fatura',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF7C5CFC),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'rent',
      name: 'Kira',
      icon: Icons.home_work_rounded,
      color: const Color(0xFF8A5A44),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'health',
      name: 'Sağlık',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFCC5A71),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'shopping',
      name: 'Alışveriş',
      icon: Icons.shopping_cart_rounded,
      color: const Color(0xFFB35D8D),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Eğlence',
      icon: Icons.theater_comedy_rounded,
      color: const Color(0xFFDAA520),
      isBuiltIn: true,
    ),
    ExpenseCategory(
      id: 'other',
      name: 'Diğer',
      icon: Icons.more_horiz_rounded,
      color: const Color(0xFF6C707A),
      isBuiltIn: true,
    ),
  ];

  late ParafixThemePreset _selectedPreset;
  late List<ExpenseCategory> _customCategories;
  var _hasSeenOnboarding = false;
  var _hasRestoredState = false;
  var _hasPlayedLaunchAnimation = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabIndexNotifier = ValueNotifier(0);
    _selectedPreset = ParafixTheme.presets.first;
    _customCategories = const [];
    _entriesNotifier = ValueNotifier(_seedEntries());
    _monthlyPaymentsNotifier = ValueNotifier(_seedMonthlyPayments());
    unawaited(_restorePersistedState());
  }

  List<ExpenseCategory> get _allCategories => [
    ..._coreCategories,
    ..._customCategories,
  ];

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _feedbackEntry?.remove();
    _pageController.dispose();
    _entriesNotifier.dispose();
    _monthlyPaymentsNotifier.dispose();
    _tabIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themePreset = _hasSeenOnboarding
        ? _selectedPreset
        : ParafixTheme.presets.first;

    return MaterialApp(
      title: 'Parafix',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      locale: const Locale('tr', 'TR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      theme: ParafixTheme.buildTheme(preset: themePreset),
      scrollBehavior: const ParafixScrollBehavior(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_hasRestoredState) {
      return const _StartupHold();
    }

    if (!_hasPlayedLaunchAnimation) {
      return _LaunchSplash(onCompleted: _finishLaunchAnimation);
    }

    if (!_hasSeenOnboarding) {
      return OnboardingScreen(
        onCompleted: () => unawaited(_completeOnboarding()),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 0,
        title: ValueListenableBuilder<int>(
          valueListenable: _tabIndexNotifier,
          builder: (context, tabIndex, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  tabIndex == 0 ? 'Parafix' : 'Rapor',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  tabIndex == 0
                      ? 'Harcamalarını tek bakışta gör.'
                      : 'Özetini net biçimde incele.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              onPressed: _openPersonalization,
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Tema ve kategoriler',
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => _tabIndexNotifier.value = index,
        children: [
          ValueListenableBuilder<List<ExpenseEntry>>(
            valueListenable: _entriesNotifier,
            builder: (context, entries, _) {
              return RepaintBoundary(
                child: HomeScreen(
                  key: const PageStorageKey('home-screen'),
                  entries: entries,
                  accentColor: _selectedPreset.accent,
                  onDeleteEntry: _deleteEntry,
                  onEditEntry: _editEntry,
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: Listenable.merge([
              _entriesNotifier,
              _monthlyPaymentsNotifier,
            ]),
            builder: (context, _) {
              return RepaintBoundary(
                child: ReportScreen(
                  key: const PageStorageKey('report-screen'),
                  entries: _entriesNotifier.value,
                  monthlyPayments: _monthlyPaymentsNotifier.value,
                  categories: _allCategories,
                  accentColor: _selectedPreset.accent,
                  onUpsertMonthlyPayment: _upsertMonthlyPayment,
                  onDeleteMonthlyPayment: _deleteMonthlyPayment,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openAddExpense,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _tabIndexNotifier,
        builder: (context, tabIndex, _) {
          return _ShellNavigationBar(
            currentIndex: tabIndex,
            onSelected: _goToTab,
          );
        },
      ),
    );
  }

  Future<void> _openAddExpense() async {
    unawaited(HapticFeedback.selectionClick());
    await _openExpenseSheet();
  }

  Future<ExpenseEntry?> _editEntry(ExpenseEntry entry) async {
    return _openExpenseSheet(entry: entry);
  }

  Future<ExpenseEntry?> _openExpenseSheet({ExpenseEntry? entry}) async {
    final isEditing = entry != null;
    final modalContext = _navigatorKey.currentContext;
    if (modalContext == null) {
      return null;
    }

    final draft = await showModalBottomSheet<ExpenseDraft>(
      context: modalContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.52,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.86],
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) {
          return AddExpenseSheet(
            scrollController: scrollController,
            categories: _allCategories,
            initialEntry: entry == null
                ? null
                : ExpenseDraft(
                    title: entry.title,
                    amount: entry.amount,
                    date: entry.date,
                    category: entry.category,
                    note: entry.note,
                  ),
          );
        },
      ),
    );

    if (draft == null) {
      return null;
    }

    final nextEntry = ExpenseEntry(
      id: entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title,
      amount: draft.amount,
      note: draft.note,
      date: draft.date,
      category: draft.category,
    );

    _entriesNotifier.value = _upsertEntrySorted(
      _entriesNotifier.value,
      nextEntry,
    );
    unawaited(_persistState());
    unawaited(HapticFeedback.lightImpact());

    _showFeedback(isEditing ? 'Harcama güncellendi.' : 'Harcama eklendi.');

    return nextEntry;
  }

  Future<void> _openPersonalization() async {
    final modalContext = _navigatorKey.currentContext;
    if (modalContext == null) {
      return;
    }

    final categoryResult = await showModalBottomSheet<CategoryEditorResult>(
      context: modalContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.52,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.86],
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) {
          return PersonalizationSheet(
            scrollController: scrollController,
            presets: ParafixTheme.presets,
            selectedPreset: _selectedPreset,
            categories: _customCategories,
            customCount: _customCategories.length,
            onPresetSelected: _selectPreset,
          );
        },
      ),
    );

    if (categoryResult == null) {
      return;
    }

    if (categoryResult.previousCategoryId == null &&
        _customCategories.length >= maxCustomExpenseCategories) {
      _showFeedback('En fazla 3 özel kategori ekleyebilirsin.');
      return;
    }

    setState(() {
      if (categoryResult.previousCategoryId != null) {
        _customCategories = _customCategories
            .map(
              (category) => category.id == categoryResult.previousCategoryId
                  ? categoryResult.category
                  : category,
            )
            .toList(growable: false);
        _entriesNotifier.value = _entriesNotifier.value
            .map(
              (entry) => entry.category.id == categoryResult.previousCategoryId
                  ? ExpenseEntry(
                      id: entry.id,
                      title: entry.title,
                      amount: entry.amount,
                      note: entry.note,
                      date: entry.date,
                      category: categoryResult.category,
                    )
                  : entry,
            )
            .toList(growable: false);
        _monthlyPaymentsNotifier.value = _monthlyPaymentsNotifier.value
            .map(
              (payment) =>
                  payment.category.id == categoryResult.previousCategoryId
                  ? payment.copyWith(category: categoryResult.category)
                  : payment,
            )
            .toList(growable: false);
      } else {
        _customCategories = [..._customCategories, categoryResult.category];
      }
    });
    unawaited(_persistState());
  }

  List<ExpenseEntry> _seedEntries() {
    return const [];
  }

  List<MonthlyPayment> _seedMonthlyPayments() {
    return const [];
  }

  List<ExpenseEntry> _insertEntrySorted(
    List<ExpenseEntry> entries,
    ExpenseEntry newEntry,
  ) {
    final nextEntries = [...entries];
    var low = 0;
    var high = nextEntries.length;

    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (newEntry.date.isAfter(nextEntries[mid].date)) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    nextEntries.insert(low, newEntry);

    return nextEntries;
  }

  List<ExpenseEntry> _upsertEntrySorted(
    List<ExpenseEntry> entries,
    ExpenseEntry nextEntry,
  ) {
    final filtered = entries
        .where((entry) => entry.id != nextEntry.id)
        .toList(growable: false);
    return _insertEntrySorted(filtered, nextEntry);
  }

  void _upsertMonthlyPayment(MonthlyPayment nextPayment) {
    final isEditing = _monthlyPaymentsNotifier.value.any(
      (payment) => payment.id == nextPayment.id,
    );
    _monthlyPaymentsNotifier.value = _upsertMonthlyPaymentList(
      _monthlyPaymentsNotifier.value,
      nextPayment,
    );
    unawaited(_persistState());
    unawaited(HapticFeedback.lightImpact());
    _showFeedback(
      isEditing ? 'Aylık ödeme güncellendi.' : 'Aylık ödeme eklendi.',
    );
  }

  List<MonthlyPayment> _upsertMonthlyPaymentList(
    List<MonthlyPayment> payments,
    MonthlyPayment nextPayment,
  ) {
    final nextPayments = payments
        .where((payment) => payment.id != nextPayment.id)
        .toList(growable: true);
    nextPayments.add(nextPayment);
    return List<MonthlyPayment>.unmodifiable(nextPayments);
  }

  void _deleteMonthlyPayment(String id) {
    _monthlyPaymentsNotifier.value = _monthlyPaymentsNotifier.value
        .where((payment) => payment.id != id)
        .toList(growable: false);
    unawaited(_persistState());
    unawaited(HapticFeedback.mediumImpact());
    _showFeedback('Aylık ödeme silindi.');
  }

  void _goToTab(int index) {
    if (_tabIndexNotifier.value == index) {
      return;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutQuart,
    );
  }

  void _deleteEntry(ExpenseEntry target) {
    _entriesNotifier.value = _entriesNotifier.value
        .where((entry) => entry.id != target.id)
        .toList(growable: false);
    unawaited(_persistState());
    unawaited(HapticFeedback.mediumImpact());
    _showFeedback('Harcama silindi.');
  }

  void _selectPreset(ParafixThemePreset preset) {
    if (_selectedPreset.id == preset.id) {
      return;
    }

    setState(() => _selectedPreset = preset);
    unawaited(HapticFeedback.selectionClick());
    unawaited(_persistState());
  }

  Future<void> _restorePersistedState() async {
    final preferences = await SharedPreferences.getInstance();
    final storedPresetId = preferences.getString(_themeStorageKey);
    final storedCustomCategories = preferences.getString(
      _customCategoriesStorageKey,
    );
    final storedEntries = preferences.getString(_entriesStorageKey);
    final storedMonthlyPayments = preferences.getString(
      _monthlyPaymentsStorageKey,
    );
    final hasExistingState =
        storedPresetId != null ||
        storedCustomCategories != null ||
        storedEntries != null ||
        storedMonthlyPayments != null;
    final storedHasSeenOnboarding =
        preferences.getBool(_onboardingStorageKey) ?? hasExistingState;

    var nextPreset = _selectedPreset;
    var nextCustomCategories = _customCategories;
    List<ExpenseEntry>? nextEntries;
    var nextMonthlyPayments = _monthlyPaymentsNotifier.value;

    if (storedPresetId != null) {
      nextPreset = ParafixTheme.presets.firstWhere(
        (preset) => preset.id == storedPresetId,
        orElse: () => _selectedPreset,
      );
    }

    if (storedCustomCategories != null) {
      final decoded = jsonDecode(storedCustomCategories) as List<dynamic>;
      nextCustomCategories = _normalizeCustomCategories(
        decoded.map(
          (item) =>
              ExpenseCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    }

    if (storedEntries != null) {
      final categoriesById = {
        for (final category in [..._coreCategories, ...nextCustomCategories])
          category.id: category,
      };
      final fallbackCategory = categoriesById['other']!;
      final decoded = jsonDecode(storedEntries) as List<dynamic>;
      nextEntries =
          decoded
              .map(
                (item) => ExpenseEntry.fromJson(
                  Map<String, dynamic>.from(item as Map),
                  resolveCategory: (categoryId) =>
                      categoriesById[categoryId] ?? fallbackCategory,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => b.date.compareTo(a.date));
      if (_isScreenshotSeedEntries(nextEntries)) {
        nextEntries = const [];
      }
    }

    if (storedMonthlyPayments != null) {
      final categoriesById = {
        for (final category in [..._coreCategories, ...nextCustomCategories])
          category.id: category,
      };
      final fallbackCategory = categoriesById['other']!;
      final decoded = jsonDecode(storedMonthlyPayments) as List<dynamic>;
      nextMonthlyPayments = decoded
          .map(
            (item) => MonthlyPayment.fromJson(
              Map<String, dynamic>.from(item as Map),
              resolveCategory: (categoryId) =>
                  categoriesById[categoryId] ?? fallbackCategory,
            ),
          )
          .toList(growable: false);
      if (_isScreenshotSeedPayments(nextMonthlyPayments)) {
        nextMonthlyPayments = const [];
      }
    } else if (storedPresetId != null ||
        storedCustomCategories != null ||
        storedEntries != null) {
      nextMonthlyPayments = const [];
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPreset = nextPreset;
      _customCategories = nextCustomCategories;
      _hasSeenOnboarding = storedHasSeenOnboarding;
      _hasRestoredState = true;
      if (nextEntries != null) {
        _entriesNotifier.value = nextEntries;
      }
      _monthlyPaymentsNotifier.value = nextMonthlyPayments;
    });
  }

  void _finishLaunchAnimation() {
    if (!mounted || _hasPlayedLaunchAnimation) {
      return;
    }

    setState(() => _hasPlayedLaunchAnimation = true);
  }

  Future<void> _completeOnboarding() async {
    if (!mounted) {
      return;
    }

    setState(() => _hasSeenOnboarding = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingStorageKey, true);
  }

  Future<void> _persistState() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeStorageKey, _selectedPreset.id);
    await preferences.setString(
      _customCategoriesStorageKey,
      jsonEncode(
        _customCategories.map((category) => category.toJson()).toList(),
      ),
    );
    await preferences.setString(
      _entriesStorageKey,
      jsonEncode(
        _entriesNotifier.value.map((entry) => entry.toJson()).toList(),
      ),
    );
    await preferences.setString(
      _monthlyPaymentsStorageKey,
      jsonEncode(
        _monthlyPaymentsNotifier.value
            .map((payment) => payment.toJson())
            .toList(),
      ),
    );
  }

  List<ExpenseCategory> _normalizeCustomCategories(
    Iterable<ExpenseCategory> categories,
  ) {
    final coreCategoryIds = _coreCategories
        .map((category) => category.id)
        .toSet();
    final seenCategoryIds = <String>{};
    final normalized = <ExpenseCategory>[];

    for (final category in categories) {
      if (coreCategoryIds.contains(category.id) ||
          !seenCategoryIds.add(category.id)) {
        continue;
      }

      normalized.add(
        ExpenseCategory(
          id: category.id,
          name: _clampCustomCategoryName(category.name),
          icon: category.icon,
          color: category.color,
        ),
      );

      if (normalized.length == maxCustomExpenseCategories) {
        break;
      }
    }

    return List<ExpenseCategory>.unmodifiable(normalized);
  }

  String _clampCustomCategoryName(String name) {
    final trimmed = name.trim();
    if (trimmed.length <= maxCustomCategoryNameLength) {
      return trimmed;
    }
    return trimmed.substring(0, maxCustomCategoryNameLength);
  }

  bool _isScreenshotSeedEntries(List<ExpenseEntry> entries) {
    const seedEntryIds = {
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
      '13',
      '14',
      '15',
      '16',
      '17',
      '18',
    };

    return entries.isNotEmpty &&
        entries.every((entry) => seedEntryIds.contains(entry.id));
  }

  bool _isScreenshotSeedPayments(List<MonthlyPayment> payments) {
    const seedPaymentIds = {'monthly-1', 'monthly-2', 'monthly-3', 'monthly-4'};

    return payments.isNotEmpty &&
        payments.every((payment) => seedPaymentIds.contains(payment.id));
  }

  void _showFeedback(String message) {
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }

    _feedbackTimer?.cancel();
    _feedbackEntry?.remove();

    final isDark = _selectedPreset.brightness == Brightness.dark;
    _feedbackEntry = OverlayEntry(
      builder: (_) => _FeedbackToast(
        message: message,
        backgroundColor: isDark
            ? const Color(0xFF243149)
            : const Color(0xFF111418),
        borderColor: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.12),
      ),
    );

    overlay.insert(_feedbackEntry!);
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _feedbackEntry?.remove();
      _feedbackEntry = null;
    });
  }
}

class _LaunchSplash extends StatefulWidget {
  const _LaunchSplash({required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<_LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<_LaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _screenOpacity;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onCompleted();
          }
        });
    _screenOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 72),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 28,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<ParafixPalette>()!;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0B1A2E)
        : palette.background;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity: _screenOpacity,
        child: SizedBox.expand(
          child: ColoredBox(
            color: backgroundColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LaunchAppIcon(palette, matchThemeColor: !isDark),
                  const SizedBox(height: 16),
                  Text(
                    'Parafix',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchAppIcon extends StatelessWidget {
  const _LaunchAppIcon(this.palette, {required this.matchThemeColor});

  final ParafixPalette palette;
  final bool matchThemeColor;

  @override
  Widget build(BuildContext context) {
    final icon = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        _appIconAssetPath,
        width: 92,
        height: 92,
        cacheWidth: 276,
        cacheHeight: 276,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );

    if (!matchThemeColor) {
      return icon;
    }

    return ColorFiltered(
      colorFilter: ColorFilter.mode(palette.accent, BlendMode.hue),
      child: icon,
    );
  }
}

class _StartupHold extends StatelessWidget {
  const _StartupHold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

class _FeedbackToast extends StatelessWidget {
  const _FeedbackToast({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String message;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return IgnorePointer(
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 72),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<ParafixPalette>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.24 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        notchMargin: 12,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                label: 'Ana Sayfa',
                icon: Icons.home_rounded,
                selected: currentIndex == 0,
                onTap: () => onSelected(0),
              ),
            ),
            const SizedBox(width: 112),
            Expanded(
              child: _NavItem(
                label: 'Rapor',
                icon: Icons.bar_chart_rounded,
                selected: currentIndex == 1,
                onTap: () => onSelected(1),
              ),
            ),
          ],
        ),
      ).withSurfaceTint(theme),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ParafixPalette>()!;
    final selectedBackground = colors.accent.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.26 : 0.14,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Container(
                constraints: const BoxConstraints(minWidth: 112),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.transparent,
                    selectedBackground,
                    value,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: 1 + (0.04 * value),
                      child: Icon(
                        icon,
                        color: Color.lerp(
                          colors.mutedText,
                          colors.accent,
                          value,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Color.lerp(
                          colors.mutedText,
                          colors.accent,
                          value,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

extension on BottomAppBar {
  Widget withSurfaceTint(ThemeData theme) {
    return Theme(
      data: theme.copyWith(splashFactory: InkRipple.splashFactory),
      child: this,
    );
  }
}
