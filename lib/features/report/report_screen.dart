import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/parafix_theme.dart';
import '../../models/expense_category.dart';
import '../../models/expense_entry.dart';
import '../../models/monthly_payment.dart';
import 'monthly_payment_sheet.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.entries,
    required this.monthlyPayments,
    required this.categories,
    required this.accentColor,
    required this.onUpsertMonthlyPayment,
    required this.onDeleteMonthlyPayment,
    required this.onDeleteEntry,
    required this.onEditEntry,
  });

  final List<ExpenseEntry> entries;
  final List<MonthlyPayment> monthlyPayments;
  final List<ExpenseCategory> categories;
  final Color accentColor;
  final ValueChanged<MonthlyPayment> onUpsertMonthlyPayment;
  final ValueChanged<String> onDeleteMonthlyPayment;
  final ValueChanged<ExpenseEntry> onDeleteEntry;
  final Future<ExpenseEntry?> Function(ExpenseEntry) onEditEntry;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedRange = 0;

  static const _ranges = [
    _ReportRange(label: 'Son 7 Gün', type: _RangeType.sevenDays),
    _ReportRange(label: 'Son 30 Gün', type: _RangeType.thirtyDays),
    _ReportRange(label: 'Bu Ay', type: _RangeType.currentMonth),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final now = DateTime.now();
    final range = _ranges[_selectedRange];
    final filtered = _filterEntries(widget.entries, range.type, now);
    final buckets = _buildBuckets(filtered, range.type, now);
    final maxBucket = _maxBucket(buckets);
    final total = filtered.fold<double>(0, (sum, entry) => sum + entry.amount);
    final rankedCategories = _buildCategoryBreakdowns(filtered);
    final average = filtered.isEmpty ? 0.0 : total / filtered.length;
    final activeMonthlyPayments = widget.monthlyPayments
        .where((payment) => payment.isActive)
        .toList(growable: false);
    final monthlyPaymentLoad = activeMonthlyPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final sortedMonthlyPayments = _sortMonthlyPayments(
      widget.monthlyPayments,
      now,
    );
    final nextMonthlyPayment = activeMonthlyPayments.isEmpty
        ? null
        : (activeMonthlyPayments.toList()..sort(
                (left, right) =>
                    _nextDueDate(left, now).compareTo(_nextDueDate(right, now)),
              ))
              .first;
    final remainingMonthlyPayments = sortedMonthlyPayments
        .where((payment) => payment.id != nextMonthlyPayment?.id)
        .toList(growable: false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              _ranges.length,
              (index) => ChoiceChip(
                label: Text(_ranges[index].label),
                selected: _selectedRange == index,
                onSelected: (_) => setState(() => _selectedRange = index),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Harcama ritmi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rangeDescription(range.type),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Bu aralıkta kayıt yok.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    SizedBox(
                      height: 170,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: buckets
                            .map(
                              (bucket) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        bucket.value == 0
                                            ? '-'
                                            : _groupedWhole(bucket.value),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: math.max(
                                          14,
                                          maxBucket == 0
                                              ? 14
                                              : (bucket.value / maxBucket) *
                                                        96 +
                                                    16,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              widget.accentColor,
                                              widget.accentColor.withValues(
                                                alpha: 0.28,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        bucket.label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ReportMetric(
                  label: 'Toplam',
                  value: _money(total),
                  accentColor: widget.accentColor,
                  emphasized: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReportMetric(
                  label: 'İşlem başı ort.',
                  value: _money(average),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kategori dağılımı',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...rankedCategories
                      .take(5)
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _CategoryDistributionTile(
                            category: category,
                            rangeTotal: total,
                            accentColor: widget.accentColor,
                            onTap: () => _openCategoryDetails(
                              context,
                              category: category,
                              range: range,
                              rangeTotal: total,
                            ),
                          ),
                        ),
                      ),
                  if (rankedCategories.isEmpty)
                    Text(
                      'Kayıt ekledikçe dağılım burada görünür.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Aylık Ödemeler',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () => _openMonthlyPaymentSheet(context),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Aylık ödeme ekle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ReportMetric(
                          label: 'Aylık yük',
                          value: _money(monthlyPaymentLoad),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ReportMetric(
                          label: 'Aktif ödeme',
                          value: activeMonthlyPayments.length.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (nextMonthlyPayment != null) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openMonthlyPaymentSheet(
                        context,
                        payment: nextMonthlyPayment,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: widget.accentColor.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                nextMonthlyPayment.category.icon,
                                color: widget.accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sıradaki ödeme',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nextMonthlyPayment.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${nextMonthlyPayment.category.name} • ${_shortDate(_nextDueDate(nextMonthlyPayment, now))}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _money(nextMonthlyPayment.amount),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: widget.accentColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _dueLabel(
                                    _nextDueDate(nextMonthlyPayment, now),
                                    now,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (sortedMonthlyPayments.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tekrarlayan ödemelerini burada takip edebilirsin.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _openMonthlyPaymentSheet(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('İlk ödemeyi ekle'),
                        ),
                      ],
                    )
                  else ...[
                    if (remainingMonthlyPayments.isNotEmpty) ...[
                      Text(
                        nextMonthlyPayment == null
                            ? 'Tüm aylık ödemeler'
                            : 'Diğer aylık ödemeler',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...remainingMonthlyPayments.map(
                      (payment) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openMonthlyPaymentSheet(
                            context,
                            payment: payment,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.surfaceAlt.withValues(alpha: 0.44),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: payment.category.color.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    payment.billingDay.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: payment.category.color,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        payment.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: payment.isActive
                                                  ? null
                                                  : palette.mutedText,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        payment.isActive
                                            ? 'Her ay ${payment.billingDay}. gün • ${payment.category.name}'
                                            : 'Pasif • ${payment.category.name}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _money(payment.amount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: payment.isActive
                                                ? widget.accentColor
                                                : palette.mutedText,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      payment.isActive
                                          ? _shortDate(
                                              _nextDueDate(payment, now),
                                            )
                                          : 'Pasif',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMonthlyPaymentSheet(
    BuildContext context, {
    MonthlyPayment? payment,
  }) async {
    final result = await showModalBottomSheet<MonthlyPaymentSheetResult>(
      context: context,
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
          return MonthlyPaymentSheet(
            scrollController: scrollController,
            categories: widget.categories,
            initialPayment: payment,
          );
        },
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    switch (result.action) {
      case MonthlyPaymentSheetAction.save:
        final nextPayment = result.payment;
        if (nextPayment != null) {
          widget.onUpsertMonthlyPayment(nextPayment);
        }
        break;
      case MonthlyPaymentSheetAction.delete:
        final deletedPaymentId = result.deletedPaymentId;
        if (deletedPaymentId != null) {
          widget.onDeleteMonthlyPayment(deletedPaymentId);
        }
        break;
    }
  }

  Future<void> _openCategoryDetails(
    BuildContext context, {
    required _CategoryBreakdown category,
    required _ReportRange range,
    required double rangeTotal,
  }) async {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final categoryInfo = category.category;
    final categoryEntries = [...category.entries]
      ..sort((left, right) => right.date.compareTo(left.date));
    var currentRangeTotal = rangeTotal;

    await showModalBottomSheet<void>(
      context: context,
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
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return StatefulBuilder(
            builder: (context, setModalState) {
              final categoryTotal = _sumFor(categoryEntries);
              final categoryShare = currentRangeTotal == 0
                  ? 0.0
                  : categoryTotal / currentRangeTotal;
              final categoryAverage = categoryEntries.isEmpty
                  ? 0.0
                  : categoryTotal / categoryEntries.length;

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
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: categoryInfo.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              categoryInfo.icon,
                              color: categoryInfo.color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  categoryInfo.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  range.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: _ScaledReportText(
                              text: _money(categoryTotal),
                              alignment: Alignment.centerRight,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: widget.accentColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _CategoryDetailMetric(
                            label: 'Pay',
                            value: '${(categoryShare * 100).round()}%',
                          ),
                          const SizedBox(width: 10),
                          _CategoryDetailMetric(
                            label: 'İşlem',
                            value: categoryEntries.length.toString(),
                          ),
                          const SizedBox(width: 10),
                          _CategoryDetailMetric(
                            label: 'Ort.',
                            value: _money(categoryAverage),
                          ),
                        ],
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
                              color: widget.accentColor,
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
                      Text(
                        'Harcamalar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...categoryEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CategoryExpenseTile(
                            entry: entry,
                            accentColor: widget.accentColor,
                            onDelete: () {
                              widget.onDeleteEntry(entry);
                              setModalState(() {
                                categoryEntries.removeWhere(
                                  (item) => item.id == entry.id,
                                );
                                currentRangeTotal = math.max(
                                  0,
                                  currentRangeTotal - entry.amount,
                                );
                              });

                              if (categoryEntries.isEmpty && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            onEdit: () async {
                              final updatedEntry = await widget.onEditEntry(
                                entry,
                              );
                              if (updatedEntry == null || !context.mounted) {
                                return;
                              }

                              final stillInRange = _filterEntries(
                                [updatedEntry],
                                range.type,
                                DateTime.now(),
                              ).isNotEmpty;

                              setModalState(() {
                                categoryEntries.removeWhere(
                                  (item) => item.id == entry.id,
                                );
                                currentRangeTotal = math.max(
                                  0,
                                  currentRangeTotal - entry.amount,
                                );

                                if (stillInRange) {
                                  currentRangeTotal += updatedEntry.amount;

                                  if (updatedEntry.category.id ==
                                      categoryInfo.id) {
                                    categoryEntries.add(updatedEntry);
                                    categoryEntries.sort(
                                      (left, right) =>
                                          right.date.compareTo(left.date),
                                    );
                                  }
                                }
                              });

                              if (categoryEntries.isEmpty && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
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

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    this.accentColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? accentColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: emphasized && accentColor != null
            ? accentColor!.withValues(alpha: 0.12)
            : palette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          _ScaledReportText(
            text: value,
            alignment: Alignment.centerLeft,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _CategoryDistributionTile extends StatelessWidget {
  const _CategoryDistributionTile({
    required this.category,
    required this.rangeTotal,
    required this.accentColor,
    required this.onTap,
  });

  final _CategoryBreakdown category;
  final double rangeTotal;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final progress = rangeTotal == 0 ? 0.0 : category.total / rangeTotal;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: category.category.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.category.icon,
                    size: 18,
                    color: category.category.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(category.category.name)),
                Flexible(
                  child: _ScaledReportText(
                    text: _money(category.total),
                    alignment: Alignment.centerRight,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.mutedText,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 10,
                backgroundColor: palette.surfaceAlt,
                value: progress.clamp(0.0, 1.0).toDouble(),
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDetailMetric extends StatelessWidget {
  const _CategoryDetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            _ScaledReportText(
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

class _CategoryExpenseTile extends StatelessWidget {
  const _CategoryExpenseTile({
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
        key: ValueKey('report-category-${entry.id}'),
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
                          '${_longDate(entry.date)} • ${_timeLabel(entry.date)}',
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
                    child: _ScaledReportText(
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

class _ScaledReportText extends StatelessWidget {
  const _ScaledReportText({
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

class _CategoryBreakdown {
  const _CategoryBreakdown({
    required this.category,
    required this.entries,
    required this.total,
  });

  final ExpenseCategory category;
  final List<ExpenseEntry> entries;
  final double total;
}

enum _RangeType { sevenDays, thirtyDays, currentMonth }

class _ReportRange {
  const _ReportRange({required this.label, required this.type});

  final String label;
  final _RangeType type;
}

class _Bucket {
  const _Bucket({required this.label, required this.value});

  final String label;
  final double value;
}

List<MonthlyPayment> _sortMonthlyPayments(
  List<MonthlyPayment> payments,
  DateTime now,
) {
  final activePayments = payments.where((payment) => payment.isActive).toList()
    ..sort(
      (left, right) =>
          _nextDueDate(left, now).compareTo(_nextDueDate(right, now)),
    );
  final inactivePayments =
      payments.where((payment) => !payment.isActive).toList()
        ..sort((left, right) => left.title.compareTo(right.title));

  return [...activePayments, ...inactivePayments];
}

List<ExpenseEntry> _filterEntries(
  List<ExpenseEntry> entries,
  _RangeType range,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final DateTime start;

  switch (range) {
    case _RangeType.sevenDays:
      start = today.subtract(const Duration(days: 6));
      break;
    case _RangeType.thirtyDays:
      start = today.subtract(const Duration(days: 29));
      break;
    case _RangeType.currentMonth:
      start = DateTime(now.year, now.month, 1);
      break;
  }

  return entries.where((entry) => !entry.date.isBefore(start)).toList();
}

List<_CategoryBreakdown> _buildCategoryBreakdowns(List<ExpenseEntry> entries) {
  final entriesByCategory = <String, List<ExpenseEntry>>{};

  for (final entry in entries) {
    entriesByCategory
        .putIfAbsent(entry.category.id, () => <ExpenseEntry>[])
        .add(entry);
  }

  final breakdowns = entriesByCategory.values.map((categoryEntries) {
    final sortedEntries = [...categoryEntries]
      ..sort((left, right) => right.date.compareTo(left.date));
    return _CategoryBreakdown(
      category: sortedEntries.first.category,
      entries: List<ExpenseEntry>.unmodifiable(sortedEntries),
      total: _sumFor(sortedEntries),
    );
  }).toList();

  breakdowns.sort((left, right) => right.total.compareTo(left.total));
  return breakdowns;
}

List<_Bucket> _buildBuckets(
  List<ExpenseEntry> entries,
  _RangeType range,
  DateTime now,
) {
  switch (range) {
    case _RangeType.sevenDays:
      return _buildDailyBuckets(entries, now);
    case _RangeType.thirtyDays:
      return _buildFiveDayBuckets(entries, now);
    case _RangeType.currentMonth:
      return _buildWeeklyMonthBuckets(entries, now);
  }
}

List<_Bucket> _buildDailyBuckets(List<ExpenseEntry> entries, DateTime now) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));
  final buckets = <_Bucket>[];

  for (var i = 0; i < 7; i++) {
    final day = start.add(Duration(days: i));
    final total = entries
        .where((entry) => _sameDay(entry.date, day))
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    buckets.add(_Bucket(label: _weekdayLabel(day.weekday), value: total));
  }

  return buckets;
}

List<_Bucket> _buildFiveDayBuckets(List<ExpenseEntry> entries, DateTime now) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 29));
  final buckets = <_Bucket>[];

  for (var i = 0; i < 6; i++) {
    final chunkStart = start.add(Duration(days: i * 5));
    final chunkEnd = chunkStart.add(const Duration(days: 4));
    final total = entries
        .where(
          (entry) =>
              !_atStartOfDay(entry.date).isBefore(chunkStart) &&
              !_atStartOfDay(entry.date).isAfter(chunkEnd),
        )
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    buckets.add(
      _Bucket(label: '${chunkStart.day}-${chunkEnd.day}', value: total),
    );
  }

  return buckets;
}

List<_Bucket> _buildWeeklyMonthBuckets(
  List<ExpenseEntry> entries,
  DateTime now,
) {
  final monthStart = DateTime(now.year, now.month, 1);
  final daysInMonth = now.day;
  final buckets = <_Bucket>[];
  var weekIndex = 1;

  for (var day = 1; day <= daysInMonth; day += 7) {
    final chunkStart = monthStart.add(Duration(days: day - 1));
    final chunkEnd = monthStart.add(
      Duration(days: math.min(day + 5, daysInMonth) - 1),
    );
    final total = entries
        .where(
          (entry) =>
              !_atStartOfDay(entry.date).isBefore(chunkStart) &&
              !_atStartOfDay(entry.date).isAfter(chunkEnd),
        )
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    buckets.add(_Bucket(label: '$weekIndex. hf', value: total));
    weekIndex++;
  }

  return buckets;
}

double _maxBucket(List<_Bucket> buckets) {
  return buckets.fold<double>(
    0,
    (maxValue, bucket) => math.max(maxValue, bucket.value),
  );
}

String _rangeDescription(_RangeType range) {
  switch (range) {
    case _RangeType.sevenDays:
      return 'Son 7 günü gün gün gösterir.';
    case _RangeType.thirtyDays:
      return 'Son 30 günü 5 günlük bloklarla özetler.';
    case _RangeType.currentMonth:
      return 'Bu ayı hafta bloklarıyla gösterir.';
  }
}

String _weekdayLabel(int weekday) {
  const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return labels[weekday - 1];
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

double _sumFor(Iterable<ExpenseEntry> entries) {
  return entries.fold<double>(0, (sum, entry) => sum + entry.amount);
}

DateTime _atStartOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _nextDueDate(MonthlyPayment payment, DateTime now) {
  final today = _atStartOfDay(now);
  final currentMonthDueDate = _dueDateForMonth(payment, now.year, now.month);

  if (!currentMonthDueDate.isBefore(today)) {
    return currentMonthDueDate;
  }

  final nextMonthDate = DateTime(now.year, now.month + 1);
  return _dueDateForMonth(payment, nextMonthDate.year, nextMonthDate.month);
}

DateTime _dueDateForMonth(MonthlyPayment payment, int year, int month) {
  final day = math.min(payment.billingDay, _daysInMonth(year, month));
  return DateTime(year, month, day);
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

String _dueLabel(DateTime dueDate, DateTime now) {
  final difference = dueDate.difference(_atStartOfDay(now)).inDays;

  if (difference == 0) {
    return 'Bugün';
  }
  if (difference == 1) {
    return 'Yarın';
  }

  return '$difference gün sonra';
}

String _shortDate(DateTime date) {
  const months = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _longDate(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _money(double value) => '${_groupedWhole(value)}₺';

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
