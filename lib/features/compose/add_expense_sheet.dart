import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/parafix_theme.dart';
import '../../models/expense_category.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({
    super.key,
    required this.categories,
    this.initialEntry,
    this.scrollController,
  });

  final List<ExpenseCategory> categories;
  final ExpenseDraft? initialEntry;
  final ScrollController? scrollController;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late ExpenseCategory _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  bool get _isFormValid {
    final amount = int.tryParse(_amountController.text);
    return _titleController.text.trim().isNotEmpty &&
        amount != null &&
        amount > 0;
  }

  List<ExpenseCategory> get _displayedCategories => widget.categories;

  @override
  void initState() {
    super.initState();
    final initialEntry = widget.initialEntry;
    final now = DateTime.now();
    _selectedCategory = initialEntry?.category ?? _displayedCategories.first;
    final initialDate = initialEntry?.date ?? now;
    _selectedDate = initialDate.isAfter(now) ? now : initialDate;
    _titleController.text = initialEntry?.title ?? '';
    _amountController.text = initialEntry == null
        ? ''
        : initialEntry.amount.toStringAsFixed(0);
    _noteController.text = initialEntry?.note ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final compactInputDecoration = InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Color.lerp(palette.surfaceAlt, palette.surface, 0.42),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
          child: SingleChildScrollView(
            controller: widget.scrollController,
            physics: parafixPlatformScrollPhysics(Theme.of(context).platform),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    widget.initialEntry == null
                        ? 'Yeni harcama'
                        : 'Harcamayı düzenle',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.initialEntry == null
                        ? 'Hızlıca yeni bir kayıt ekle.'
                        : 'Bilgileri güncelle.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(inputDecorationTheme: compactInputDecoration),
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      inputFormatters: const [_AmountInputFormatter()],
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: const InputDecoration(
                        labelText: 'Tutar',
                        hintText: '0',
                      ),
                      validator: (value) {
                        final amount = int.tryParse(value ?? '');
                        if (amount == null || amount <= 0) {
                          return '0\'dan büyük bir tutar gir.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(inputDecorationTheme: compactInputDecoration),
                    child: TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        hintText: 'Kahve, market, taksi...',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Kısa bir başlık gir.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Kategori',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 9,
                    children: _displayedCategories
                        .map(
                          (category) => _CategoryChip(
                            category: category,
                            selected: _selectedCategory.id == category.id,
                            onSelected: () =>
                                setState(() => _selectedCategory = category),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(inputDecorationTheme: compactInputDecoration),
                    child: TextFormField(
                      controller: _noteController,
                      minLines: 1,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Not',
                        hintText: 'İstersen kısa bir not ekle.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Tarih',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(_selectedDate),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: palette.mutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _titleController,
                        _amountController,
                      ]),
                      builder: (context, _) {
                        return FilledButton(
                          onPressed: _isFormValid ? _submit : null,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              widget.initialEntry == null
                                  ? 'Kaydet'
                                  : 'Güncelle',
                            ),
                          ),
                        );
                      },
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: _selectedDate.isAfter(DateTime.now())
          ? DateTime.now()
          : _selectedDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(_amountController.text);

    Navigator.of(context).pop(
      ExpenseDraft(
        title: _titleController.text.trim(),
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        date: _selectedDate,
        category: _selectedCategory,
      ),
    );
  }
}

class _AmountInputFormatter extends TextInputFormatter {
  const _AmountInputFormatter();

  static final RegExp _validPattern = RegExp(r'^\d{0,8}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _validPattern.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
  });

  final String title;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? note;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 17),
          const SizedBox(width: 6),
          Text(category.name),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: category.color.withValues(alpha: 0.18),
      side: BorderSide.none,
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
