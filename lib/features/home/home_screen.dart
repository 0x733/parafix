import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/parafix_theme.dart';
import '../../models/expense_category.dart';
import '../../models/expense_entry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.entries,
    required this.accentColor,
    required this.onDeleteEntry,
    required this.onEditEntry,
  });

  final List<ExpenseEntry> entries;
  final Color accentColor;
  final ValueChanged<ExpenseEntry> onDeleteEntry;
  final Future<ExpenseEntry?> Function(ExpenseEntry) onEditEntry;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final todayTotal = _sumFor(
      entries.where((entry) => _sameDay(entry.date, now)),
    );
    final weekTotal = _sumFor(
      entries.where((entry) => !_atStartOfDay(entry.date).isBefore(weekStart)),
    );
    final monthTotal = _sumFor(
      entries.where(
        (entry) => !entry.date.isBefore(DateTime(now.year, now.month, 1)),
      ),
    );
    final recentDays = _buildDailyTotals(entries, 7);
    final previewGroups = _buildRecentPreviewGroups(entries, 5);
    final activeDayAverage = _activeDayAverage(entries);
    final weekAverage = recentDays.isEmpty
        ? 0.0
        : recentDays.fold<double>(0, (sum, item) => sum + item.total) /
              recentDays.length;
    final yesterdayTotal = recentDays.length > 1
        ? recentDays[recentDays.length - 2].total
        : 0.0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _SummaryHero(
            todayTotal: todayTotal,
            weekTotal: weekTotal,
            monthTotal: monthTotal,
            accentColor: accentColor,
            dailyAverage: activeDayAverage,
          ),
          if (entries.isEmpty) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İlk harcamanı ekle',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ortadaki + ile ilk kaydını ekle. Özet ve raporlar hemen dolmaya başlar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '7 günlük akış',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          'Bugün dahil',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: recentDays
                            .map(
                              (item) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        item.total == 0
                                            ? '-'
                                            : _shortAmount(item.total),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: math.max(
                                          12,
                                          item.total == 0
                                              ? 12
                                              : (item.total /
                                                            _maxTotal(
                                                              recentDays,
                                                            )) *
                                                        72 +
                                                    14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.isToday
                                              ? accentColor
                                              : accentColor.withValues(
                                                  alpha: 0.24,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.dayLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _StatPill(
                          label: '7 gün ort.',
                          value: _money(weekAverage),
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'Düne göre',
                          value: _differenceFromYesterdayLabel(
                            todayTotal - yesterdayTotal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Son harcamalar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openExpenseSearch(
                    context,
                    entries,
                    onDeleteEntry,
                    onEditEntry,
                  ),
                  child: const Text('Tümünü gör'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Son 5 gün', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            ...previewGroups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _openDayDetails(
                    context,
                    group,
                    onDeleteEntry,
                    onEditEntry,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                group.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Flexible(
                                child: _ScaledText(
                                  text: _money(group.total),
                                  alignment: Alignment.centerRight,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: accentColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...group.previewEntries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: entry.category.color.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      entry.category.icon,
                                      color: entry.category.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.title),
                                        const SizedBox(height: 2),
                                        Text(
                                          entry.category.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: _ScaledText(
                                      text: _money(entry.amount),
                                      alignment: Alignment.centerRight,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${group.entries.length} harcama',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              Text(
                                'Detayı aç',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: accentColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openExpenseSearch(
    BuildContext context,
    List<ExpenseEntry> sourceEntries,
    ValueChanged<ExpenseEntry> onDeleteEntry,
    Future<ExpenseEntry?> Function(ExpenseEntry) onEditEntry,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.52,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.88],
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) {
          return _ExpenseSearchSheet(
            scrollController: scrollController,
            entries: sourceEntries,
            accentColor: accentColor,
            onDeleteEntry: onDeleteEntry,
            onEditEntry: onEditEntry,
          );
        },
      ),
    );
  }

  Future<void> _openDayDetails(
    BuildContext context,
    DailyPreviewGroup group,
    ValueChanged<ExpenseEntry> onDeleteEntry,
    Future<ExpenseEntry?> Function(ExpenseEntry) onEditEntry,
  ) async {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final dayEntries = [...group.entries];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.52,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.86],
        shouldCloseOnMinExtent: true,
        builder: (context, scrollController) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return StatefulBuilder(
            builder: (context, setModalState) {
              final currentTotal = _sumFor(dayEntries);

              return Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
                  child: ListView(
                    controller: scrollController,
                    physics: parafixPlatformScrollPhysics(
                      Theme.of(context).platform,
                    ),
                    children: [
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: palette.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        group.label,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${dayEntries.length} harcama • ${_money(currentTotal)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 18,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Düzenlemek için dokun, silmek için sola kaydır.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...dayEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Slidable(
                              key: ValueKey(entry.id),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.26,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      onDeleteEntry(entry);
                                      setModalState(() {
                                        dayEntries.removeWhere(
                                          (item) => item.id == entry.id,
                                        );
                                      });
                                      if (dayEntries.isEmpty) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    backgroundColor: const Color(0xFFC53D4A),
                                    foregroundColor: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    icon: Icons.delete_outline_rounded,
                                    label: 'Sil',
                                  ),
                                ],
                              ),
                              child: Material(
                                color: palette.surfaceAlt.withValues(
                                  alpha: 0.45,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    final updatedEntry = await onEditEntry(
                                      entry,
                                    );
                                    if (updatedEntry == null) {
                                      return;
                                    }

                                    setModalState(() {
                                      dayEntries.removeWhere(
                                        (item) => item.id == entry.id,
                                      );

                                      if (_sameDay(
                                        updatedEntry.date,
                                        group.day,
                                      )) {
                                        dayEntries.add(updatedEntry);
                                        dayEntries.sort(
                                          (left, right) =>
                                              right.date.compareTo(left.date),
                                        );
                                      }
                                    });

                                    if (dayEntries.isEmpty && context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: entry.category.color
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            entry.category.icon,
                                            color: entry.category.color,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(entry.title),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${entry.category.name} • ${_timeLabel(entry.date)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              if ((entry.note ?? '')
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  entry.note!,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Flexible(
                                          child: _ScaledText(
                                            text: _money(entry.amount),
                                            alignment: Alignment.centerRight,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(color: accentColor),
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExpenseSearchSheet extends StatefulWidget {
  const _ExpenseSearchSheet({
    required this.scrollController,
    required this.entries,
    required this.accentColor,
    required this.onDeleteEntry,
    required this.onEditEntry,
  });

  final ScrollController scrollController;
  final List<ExpenseEntry> entries;
  final Color accentColor;
  final ValueChanged<ExpenseEntry> onDeleteEntry;
  final Future<ExpenseEntry?> Function(ExpenseEntry) onEditEntry;

  @override
  State<_ExpenseSearchSheet> createState() => _ExpenseSearchSheetState();
}

class _ExpenseSearchSheetState extends State<_ExpenseSearchSheet> {
  late final TextEditingController _searchController;
  late final List<ExpenseEntry> _sheetEntries;
  var _selectedRange = _ExpenseSearchRange.all;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _sheetEntries = [...widget.entries]
      ..sort((left, right) => right.date.compareTo(left.date));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final now = DateTime.now();
    final query = _normalizeSearchText(_searchController.text);
    final categories = _categoriesFromEntries(_sheetEntries);
    final effectiveCategoryId =
        _selectedCategoryId != null &&
            categories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;
    final filteredEntries = _sheetEntries
        .where(
          (entry) =>
              _matchesSearchRange(entry, _selectedRange, now) &&
              (effectiveCategoryId == null ||
                  entry.category.id == effectiveCategoryId) &&
              _matchesSearchQuery(entry, query),
        )
        .toList(growable: false);
    final filteredTotal = _sumFor(filteredEntries);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: ListView(
          controller: widget.scrollController,
          physics: parafixPlatformScrollPhysics(Theme.of(context).platform),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Harcamalar',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${filteredEntries.length} kayıt • ${_money(filteredTotal)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: (_) {
                if (mounted) {
                  setState(() {});
                }
              },
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Harcamalarda ara',
                hintText: 'Başlık, kategori veya not',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ExpenseSearchRange.values
                  .map(
                    (range) => ChoiceChip(
                      label: Text(_searchRangeLabel(range)),
                      selected: _selectedRange == range,
                      onSelected: (_) => setState(() => _selectedRange = range),
                    ),
                  )
                  .toList(),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Kategori', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category.name),
                        selected: effectiveCategoryId == category.id,
                        onSelected: (_) => setState(() {
                          _selectedCategoryId =
                              effectiveCategoryId == category.id
                              ? null
                              : category.id;
                        }),
                        selectedColor: category.color.withValues(alpha: 0.16),
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            if (filteredEntries.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Bu filtrelerle eşleşen harcama yok.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...filteredEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExpenseSearchResultTile(
                    entry: entry,
                    accentColor: widget.accentColor,
                    onDelete: () => _deleteEntry(entry),
                    onEdit: () => _editEntry(entry),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _deleteEntry(ExpenseEntry entry) {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onDeleteEntry(entry);

    if (!mounted) {
      return;
    }

    setState(() {
      _sheetEntries.removeWhere((item) => item.id == entry.id);
    });
  }

  Future<void> _editEntry(ExpenseEntry entry) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final updatedEntry = await widget.onEditEntry(entry);

    if (!mounted || updatedEntry == null) {
      return;
    }

    setState(() {
      _sheetEntries.removeWhere((item) => item.id == entry.id);
      _sheetEntries.add(updatedEntry);
      _sheetEntries.sort((left, right) => right.date.compareTo(left.date));
    });
  }
}

class _ExpenseSearchResultTile extends StatelessWidget {
  const _ExpenseSearchResultTile({
    required this.entry,
    required this.accentColor,
    required this.onDelete,
    required this.onEdit,
  });

  final ExpenseEntry entry;
  final Color accentColor;
  final VoidCallback onDelete;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Slidable(
        key: ValueKey('search-${entry.id}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.26,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFC53D4A),
              foregroundColor: Colors.white,
              borderRadius: BorderRadius.circular(20),
              icon: Icons.delete_outline_rounded,
              label: 'Sil',
            ),
          ],
        ),
        child: Material(
          color: palette.surfaceAlt.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: entry.category.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      entry.category.icon,
                      color: entry.category.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.category.name} • ${_longLabel(entry.date)} • ${_timeLabel(entry.date)}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((entry.note ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.note!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: _ScaledText(
                      text: _money(entry.amount),
                      alignment: Alignment.centerRight,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: accentColor),
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

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.todayTotal,
    required this.weekTotal,
    required this.monthTotal,
    required this.accentColor,
    required this.dailyAverage,
  });

  final double todayTotal;
  final double weekTotal;
  final double monthTotal;
  final Color accentColor;
  final double dailyAverage;

  static const double horizontalPadding = 24;
  static const double topBottomPadding = 24;
  static const double titleBottomGap = 8;
  static const double metricsTopGap = 22;
  static const double metricSidePadding = 18;
  static const double averageTopGap = 4;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final heroForeground = _heroForeground(palette);
    final heroMuted = heroForeground.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: topBottomPadding,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darken(accentColor, 0.18), _darken(accentColor, 0.36)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugün',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: heroMuted),
                    ),
                    const SizedBox(height: titleBottomGap),
                    _ScaledText(
                      text: _money(todayTotal),
                      alignment: Alignment.centerLeft,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(color: heroForeground),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Günlük ortalama',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: heroMuted),
                    ),
                    const SizedBox(height: averageTopGap),
                    _ScaledText(
                      text: _money(dailyAverage),
                      alignment: Alignment.centerRight,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: heroForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: metricsTopGap),
          Row(
            children: [
              Expanded(
                child: _MetricColumn(
                  label: 'Son 7 gün',
                  value: _money(weekTotal),
                  textColor: heroForeground,
                  mutedColor: heroMuted,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: heroForeground.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _MetricColumn(
                  label: 'Bu ay',
                  value: _money(monthTotal),
                  textColor: heroForeground,
                  mutedColor: heroMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _SummaryHero.metricSidePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 6),
          _ScaledText(
            text: value,
            alignment: Alignment.centerLeft,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surfaceAlt.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            _ScaledText(
              text: value,
              alignment: Alignment.centerLeft,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaledText extends StatelessWidget {
  const _ScaledText({
    required this.text,
    required this.alignment,
    required this.style,
  });

  final String text;
  final Alignment alignment;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

class DailyTotal {
  const DailyTotal({
    required this.dayLabel,
    required this.total,
    required this.isToday,
  });

  final String dayLabel;
  final double total;
  final bool isToday;
}

class DailyPreviewGroup {
  const DailyPreviewGroup({
    required this.day,
    required this.label,
    required this.total,
    required this.entries,
    required this.previewEntries,
  });

  final DateTime day;
  final String label;
  final double total;
  final List<ExpenseEntry> entries;
  final List<ExpenseEntry> previewEntries;
}

enum _ExpenseSearchRange { all, today, lastSevenDays, currentMonth }

List<DailyTotal> _buildDailyTotals(List<ExpenseEntry> entries, int days) {
  final now = DateTime.now();
  final result = <DailyTotal>[];

  for (var i = days - 1; i >= 0; i--) {
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: i));
    final total = _sumFor(entries.where((entry) => _sameDay(entry.date, day)));

    result.add(
      DailyTotal(
        dayLabel: _dayLabel(day.weekday),
        total: total,
        isToday: _sameDay(day, now),
      ),
    );
  }

  return result;
}

List<ExpenseCategory> _categoriesFromEntries(List<ExpenseEntry> entries) {
  final seenCategoryIds = <String>{};
  final categories = <ExpenseCategory>[];

  for (final entry in entries) {
    if (seenCategoryIds.add(entry.category.id)) {
      categories.add(entry.category);
    }
  }

  return categories;
}

bool _matchesSearchRange(
  ExpenseEntry entry,
  _ExpenseSearchRange range,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final entryDay = _atStartOfDay(entry.date);

  return switch (range) {
    _ExpenseSearchRange.all => true,
    _ExpenseSearchRange.today => _sameDay(entry.date, now),
    _ExpenseSearchRange.lastSevenDays => !entryDay.isBefore(
      today.subtract(const Duration(days: 6)),
    ),
    _ExpenseSearchRange.currentMonth => !entry.date.isBefore(
      DateTime(now.year, now.month),
    ),
  };
}

bool _matchesSearchQuery(ExpenseEntry entry, String query) {
  if (query.isEmpty) {
    return true;
  }

  final haystack = _normalizeSearchText(
    '${entry.title} ${entry.category.name} ${entry.note ?? ''}',
  );
  return haystack.contains(query);
}

String _normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}

String _searchRangeLabel(_ExpenseSearchRange range) {
  return switch (range) {
    _ExpenseSearchRange.all => 'Tümü',
    _ExpenseSearchRange.today => 'Bugün',
    _ExpenseSearchRange.lastSevenDays => 'Son 7 gün',
    _ExpenseSearchRange.currentMonth => 'Bu ay',
  };
}

List<DailyPreviewGroup> _buildRecentPreviewGroups(
  List<ExpenseEntry> entries,
  int dayCount,
) {
  final groups = <DailyPreviewGroup>[];
  DateTime? activeDay;
  final currentEntries = <ExpenseEntry>[];
  var currentTotal = 0.0;

  void flushGroup() {
    final day = activeDay;
    if (day == null || currentEntries.isEmpty) {
      return;
    }
    groups.add(
      DailyPreviewGroup(
        day: day,
        label: _longLabel(day),
        total: currentTotal,
        entries: List<ExpenseEntry>.unmodifiable(currentEntries),
        previewEntries: List<ExpenseEntry>.unmodifiable(currentEntries.take(3)),
      ),
    );
  }

  for (final entry in entries) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    activeDay ??= day;

    if (!_sameDay(day, activeDay)) {
      flushGroup();
      if (groups.length == dayCount) {
        break;
      }
      currentEntries
        ..clear()
        ..add(entry);
      currentTotal = entry.amount;
      activeDay = day;
      continue;
    }

    currentEntries.add(entry);
    currentTotal += entry.amount;
  }

  if (groups.length < dayCount) {
    flushGroup();
  }

  return groups.take(dayCount).toList(growable: false);
}

double _maxTotal(List<DailyTotal> items) {
  return items.fold<double>(
    1,
    (maxValue, item) => math.max(maxValue, item.total),
  );
}

double _sumFor(Iterable<ExpenseEntry> entries) {
  return entries.fold<double>(0, (sum, entry) => sum + entry.amount);
}

DateTime _atStartOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

double _activeDayAverage(List<ExpenseEntry> entries) {
  if (entries.isEmpty) {
    return 0;
  }

  var total = 0.0;
  var activeDayCount = 0;
  DateTime? lastDay;

  for (final entry in entries) {
    total += entry.amount;
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    if (lastDay == null || !_sameDay(lastDay, day)) {
      activeDayCount++;
      lastDay = day;
    }
  }

  return activeDayCount == 0 ? 0 : total / activeDayCount;
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _money(double value) => '${_groupedWhole(value)}₺';

String _shortAmount(double value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(1)}k'
    : _groupedWhole(value);

String _differenceFromYesterdayLabel(double value) {
  if (value == 0) {
    return 'Aynı';
  }

  final direction = value < 0 ? 'daha az' : 'daha fazla';
  return '${_groupedWhole(value.abs())}₺ $direction';
}

String _dayLabel(int weekday) {
  const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return labels[weekday - 1];
}

String _longLabel(DateTime day) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${day.day} ${months[day.month - 1]}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Color _darken(Color color, double amount) {
  return Color.lerp(color, Colors.black, amount) ?? color;
}

String _groupedWhole(double value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

Color _heroForeground(ParafixPalette palette) {
  if (palette.textPrimary.computeLuminance() > 0.7) {
    return palette.textPrimary;
  }
  return palette.accent.computeLuminance() < 0.32
      ? Colors.white
      : const Color(0xFFFDFBF6);
}
