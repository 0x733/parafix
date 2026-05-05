import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/parafix_theme.dart';
import '../../models/expense_category.dart';

class PersonalizationSheet extends StatefulWidget {
  const PersonalizationSheet({
    super.key,
    this.scrollController,
    required this.presets,
    required this.selectedPreset,
    required this.categories,
    required this.customCount,
    required this.onPresetSelected,
    required this.onExportExpenses,
    required this.onExportMonthlyPayments,
  });

  final ScrollController? scrollController;
  final List<ParafixThemePreset> presets;
  final ParafixThemePreset selectedPreset;
  final List<ExpenseCategory> categories;
  final int customCount;
  final ValueChanged<ParafixThemePreset> onPresetSelected;
  final VoidCallback onExportExpenses;
  final VoidCallback onExportMonthlyPayments;

  @override
  State<PersonalizationSheet> createState() => _PersonalizationSheetState();
}

class _PersonalizationSheetState extends State<PersonalizationSheet> {
  final _nameController = TextEditingController();
  final List<IconData> _icons = const [
    Icons.local_cafe_rounded,
    Icons.movie_rounded,
    Icons.sports_esports_rounded,
    Icons.school_rounded,
    Icons.work_rounded,
  ];
  final List<Color> _colors = const [
    Color(0xFFBF5B48),
    Color(0xFF4F7CAC),
    Color(0xFF1F8A70),
    Color(0xFFB35D8D),
    Color(0xFFDAA520),
  ];

  IconData _selectedIcon = Icons.local_cafe_rounded;
  Color _selectedColor = const Color(0xFFBF5B48);
  ExpenseCategory? _editingCategory;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSubmitCategory =
        _editingCategory != null ||
        widget.customCount < maxCustomExpenseCategories;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: ListView(
          controller: widget.scrollController,
          shrinkWrap: true,
          physics: parafixPlatformScrollPhysics(Theme.of(context).platform),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  'Kişiselleştir',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Temayı seç, kategorilerini kendi düzenine göre şekillendir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Text('Tema', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.presets.map((preset) {
                    final selected = widget.selectedPreset.id == preset.id;
                    return GestureDetector(
                      onTap: () => widget.onPresetSelected(preset),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 152,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: preset.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? preset.accent : palette.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _ColorDot(color: preset.accent),
                                const SizedBox(width: 8),
                                Text(
                                  preset.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: preset.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: preset.background,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: preset.surfaceAlt,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _themeSubtitle(preset.id),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: preset.mutedText),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Özel kategoriler',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${widget.customCount}/$maxCustomExpenseCategories özel kategori',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'En fazla 3 özel kategori ekleyebilirsin. Adlar 9 karakteri geçemez.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (widget.categories.isNotEmpty) ...[
                  ...widget.categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _startEditingCategory(category),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceAlt.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: category.color.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(category.name)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Düzenle',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: category.color),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: category.color,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  _editingCategory == null
                      ? 'Özel kategori ekle'
                      : 'Kategoriyi düzenle',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  maxLength: maxCustomCategoryNameLength,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      maxCustomCategoryNameLength,
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kategori adı',
                    hintText: 'Örnek: Hobi',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: _icons.map((icon) {
                    final selected = icon == _selectedIcon;
                    return ChoiceChip(
                      label: Icon(icon, size: 18),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedIcon = icon),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _colors.map((color) {
                    final selected = color == _selectedColor;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: selected ? 42 : 36,
                          height: selected ? 42 : 36,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? palette.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (!canSubmitCategory) ...[
                  Text(
                    'Limit doldu. Yeni eklemek yerine mevcut bir özel kategoriyi düzenleyebilirsin.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: canSubmitCategory ? _submitCategory : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _editingCategory == null
                            ? 'Kategori ekle'
                            : 'Değişiklikleri kaydet',
                      ),
                    ),
                  ),
                ),
                if (_editingCategory != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _resetEditor,
                      child: const Text('Yeni kategoriye dön'),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                Text('Veriler', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Kayıtlarını CSV dosyası olarak dışa aktarabilirsin.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _ExportActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Harcamaları dışa aktar',
                  subtitle: 'Harcama geçmişini tablo dosyası olarak paylaş.',
                  onTap: widget.onExportExpenses,
                ),
                const SizedBox(height: 10),
                _ExportActionTile(
                  icon: Icons.event_repeat_rounded,
                  title: 'Aylık ödemeleri dışa aktar',
                  subtitle: 'Abonelik ve düzenli ödeme listesini paylaş.',
                  onTap: widget.onExportMonthlyPayments,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitCategory() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kategoriye bir ad ver.')));
      return;
    }

    if (name.length > maxCustomCategoryNameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori adı en fazla 9 karakter olabilir.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      CategoryEditorResult(
        previousCategoryId: _editingCategory?.id,
        category: ExpenseCategory(
          id:
              _editingCategory?.id ??
              '${name.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          icon: _selectedIcon,
          color: _selectedColor,
        ),
      ),
    );
  }

  void _startEditingCategory(ExpenseCategory category) {
    setState(() {
      _editingCategory = category;
      _nameController.text = category.name;
      _selectedIcon = category.icon;
      _selectedColor = category.color;
    });
  }

  void _resetEditor() {
    setState(() {
      _editingCategory = null;
      _nameController.clear();
      _selectedIcon = _icons.first;
      _selectedColor = _colors.first;
    });
  }
}

class _ExportActionTile extends StatelessWidget {
  const _ExportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ParafixPalette>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: palette.surfaceAlt.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: palette.accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.ios_share_rounded, size: 19, color: palette.mutedText),
          ],
        ),
      ),
    );
  }
}

class CategoryEditorResult {
  const CategoryEditorResult({required this.category, this.previousCategoryId});

  final ExpenseCategory category;
  final String? previousCategoryId;
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

String _themeSubtitle(String id) {
  switch (id) {
    case 'sand':
      return 'Sıcak ve sade.';
    case 'graphite':
      return 'Net ve modern.';
    case 'forest':
      return 'Doğal ve dengeli.';
    case 'night':
      return 'Koyu ve odaklı.';
    case 'dust-rose':
      return 'Yumuşak ve kişisel.';
    case 'burgundy':
      return 'Sıcak ve güçlü.';
    default:
      return '';
  }
}
