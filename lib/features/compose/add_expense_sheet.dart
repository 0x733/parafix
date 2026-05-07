import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/parafix_theme.dart';
import '../../models/expense_category.dart';
import '../../services/category_learning_service.dart';
import '../../services/receipt_scan_service.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({
    super.key,
    required this.categories,
    required this.categoryLearning,
    this.initialEntry,
    this.scrollController,
  });

  final List<ExpenseCategory> categories;
  final CategoryLearningSnapshot categoryLearning;
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
  final _receiptScanService = ReceiptScanService();

  late ExpenseCategory _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String? _receiptScanMessage;
  var _receiptScanSucceeded = false;
  var _isScanningReceipt = false;
  var _hasUserPickedCategory = false;
  var _isUpdatingTitleProgrammatically = false;

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
    _hasUserPickedCategory = initialEntry != null;
    final initialDate = initialEntry?.date ?? now;
    _selectedDate = initialDate.isAfter(now) ? now : initialDate;
    _titleController.text = initialEntry?.title ?? '';
    _amountController.text = initialEntry == null
        ? ''
        : initialEntry.amount.toStringAsFixed(0);
    _noteController.text = initialEntry?.note ?? '';
    _titleController.addListener(_handleTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.initialEntry == null
                              ? 'Yeni harcama'
                              : 'Harcamayı düzenle',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (widget.initialEntry == null) ...[
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _isScanningReceipt
                              ? null
                              : _openReceiptScanOptions,
                          icon: _isScanningReceipt
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.document_scanner_rounded),
                          label: const Text('Fiş tara'),
                          style: FilledButton.styleFrom(
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.initialEntry == null
                        ? 'Hızlıca yeni bir kayıt ekle.'
                        : 'Bilgileri güncelle.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_receiptScanMessage != null) ...[
                    const SizedBox(height: 12),
                    _ReceiptScanMessage(
                      message: _receiptScanMessage!,
                      succeeded: _receiptScanSucceeded,
                    ),
                  ],
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
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.8,
                          ),
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
                            onSelected: () => setState(() {
                              _hasUserPickedCategory = true;
                              _selectedCategory = category;
                            }),
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

  Future<void> _openReceiptScanOptions() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ReceiptScanSourceSheet(),
    );

    if (source == null || !mounted) {
      return;
    }

    await _scanReceipt(source);
  }

  Future<void> _scanReceipt(ImageSource source) async {
    setState(() {
      _isScanningReceipt = true;
      _receiptScanMessage = 'Fiş okunuyor...';
      _receiptScanSucceeded = true;
    });

    try {
      final result = await _receiptScanService.scanFromSource(
        source: source,
        categories: _displayedCategories,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _isScanningReceipt = false;
          _receiptScanMessage = null;
        });
        return;
      }

      if (!result.hasAnySuggestion) {
        setState(() {
          _isScanningReceipt = false;
          _receiptScanSucceeded = false;
          _receiptScanMessage = 'Fiş okunamadı. Bilgileri elle girebilirsin.';
        });
        return;
      }

      setState(() {
        _applyReceiptScanResult(result);
        _isScanningReceipt = false;
        _receiptScanSucceeded = true;
        _receiptScanMessage = 'Fiş okundu. Bilgileri kontrol et.';
      });

      _formKey.currentState?.validate();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isScanningReceipt = false;
        _receiptScanSucceeded = false;
        _receiptScanMessage = 'Fiş okunamadı. Bilgileri elle girebilirsin.';
      });
    }
  }

  void _applyReceiptScanResult(ReceiptScanResult result) {
    final amount = result.amount;
    if (amount != null && amount > 0) {
      _amountController.text = amount.round().toString();
    }

    final title = result.title;
    if (title != null && title.trim().isNotEmpty) {
      _isUpdatingTitleProgrammatically = true;
      _titleController.text = title.trim();
      _isUpdatingTitleProgrammatically = false;
    }

    _hasUserPickedCategory = false;
    final category =
        _learnedCategoryFor(_titleController.text.trim()) ?? result.category;
    if (category != null) {
      _selectedCategory = category;
    }

    final date = result.date;
    if (date != null) {
      _selectedDate = date;
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

  void _handleTitleChanged() {
    if (_isUpdatingTitleProgrammatically || _hasUserPickedCategory) {
      return;
    }

    final category = _learnedCategoryFor(_titleController.text);
    if (category == null || category.id == _selectedCategory.id || !mounted) {
      return;
    }

    setState(() => _selectedCategory = category);
  }

  ExpenseCategory? _learnedCategoryFor(String title) {
    final categoryId = widget.categoryLearning.suggestCategoryId(
      title,
      _displayedCategories.map((category) => category.id),
    );
    if (categoryId == null) {
      return null;
    }

    for (final category in _displayedCategories) {
      if (category.id == categoryId) {
        return category;
      }
    }

    return null;
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

class _ReceiptScanMessage extends StatelessWidget {
  const _ReceiptScanMessage({required this.message, required this.succeeded});

  final String message;
  final bool succeeded;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final color = succeeded ? palette.accent : const Color(0xFFC53D4A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            succeeded ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ReceiptScanSourceSheet extends StatelessWidget {
  const _ReceiptScanSourceSheet();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'Fişten harcama ekle',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Fotoğrafı seç, alanları otomatik dolduralım.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _ReceiptScanSourceTile(
            icon: Icons.photo_camera_rounded,
            title: 'Fotoğraf çek',
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _ReceiptScanSourceTile(
            icon: Icons.photo_library_rounded,
            title: 'Galeriden seç',
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptScanSourceTile extends StatelessWidget {
  const _ReceiptScanSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surfaceAlt.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: palette.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.mutedText,
            ),
          ],
        ),
      ),
    );
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
