import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CategoryLearningSample {
  const CategoryLearningSample({required this.title, required this.categoryId});

  final String title;
  final String categoryId;
}

class CategoryLearningSnapshot {
  const CategoryLearningSnapshot._(this._rules);

  static const empty = CategoryLearningSnapshot._({});

  final Map<String, _CategoryLearningRule> _rules;

  bool get isEmpty => _rules.isEmpty;

  String? suggestCategoryId(
    String title,
    Iterable<String> availableCategoryIds,
  ) {
    final availableIds = availableCategoryIds.toSet();
    if (availableIds.isEmpty) {
      return null;
    }

    for (final key in _titleKeys(title)) {
      final rule = _rules[key];
      final categoryId = rule?.bestCategoryId(availableIds);
      if (categoryId != null) {
        return categoryId;
      }
    }

    return null;
  }
}

class CategoryLearningService {
  static const _storageKey = 'parafix_category_learning_v1';
  static const _maxRules = 180;

  Future<CategoryLearningSnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    if (stored == null) {
      return CategoryLearningSnapshot.empty;
    }

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final rules = <String, _CategoryLearningRule>{};

      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is! Map) {
          continue;
        }

        final rule = _CategoryLearningRule.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (rule.isEmpty) {
          continue;
        }

        rules[key] = rule;
      }

      return CategoryLearningSnapshot._(Map.unmodifiable(rules));
    } catch (_) {
      return CategoryLearningSnapshot.empty;
    }
  }

  Future<CategoryLearningSnapshot> learn({
    required String title,
    required String categoryId,
  }) {
    return learnMany([
      CategoryLearningSample(title: title, categoryId: categoryId),
    ]);
  }

  Future<CategoryLearningSnapshot> learnMany(
    Iterable<CategoryLearningSample> samples,
  ) async {
    final current = await load();
    final nextRules = {
      for (final entry in current._rules.entries)
        entry.key: entry.value.mutableCopy(),
    };

    for (final sample in samples) {
      final cleanCategoryId = sample.categoryId.trim();
      if (cleanCategoryId.isEmpty) {
        continue;
      }

      for (final key in _titleKeys(sample.title)) {
        final rule = nextRules.putIfAbsent(
          key,
          () => _MutableCategoryLearningRule(),
        );
        rule.increment(cleanCategoryId);
      }
    }

    final compactRules = _trimRules(nextRules);
    await _save(compactRules);

    return CategoryLearningSnapshot._(
      Map.unmodifiable(
        compactRules.map(
          (key, value) => MapEntry(key, value.toImmutableRule()),
        ),
      ),
    );
  }

  Future<void> _save(Map<String, _MutableCategoryLearningRule> rules) async {
    final preferences = await SharedPreferences.getInstance();
    if (rules.isEmpty) {
      await preferences.remove(_storageKey);
      return;
    }

    await preferences.setString(
      _storageKey,
      jsonEncode(rules.map((key, rule) => MapEntry(key, rule.toJson()))),
    );
  }

  Map<String, _MutableCategoryLearningRule> _trimRules(
    Map<String, _MutableCategoryLearningRule> rules,
  ) {
    if (rules.length <= _maxRules) {
      return rules;
    }

    final sortedEntries = rules.entries.toList()
      ..sort((left, right) {
        final totalCompare = right.value.total.compareTo(left.value.total);
        if (totalCompare != 0) {
          return totalCompare;
        }
        return left.key.compareTo(right.key);
      });

    return Map.fromEntries(sortedEntries.take(_maxRules));
  }
}

class _CategoryLearningRule {
  const _CategoryLearningRule({
    required this.counts,
    required this.lastCategoryId,
  });

  final Map<String, int> counts;
  final String? lastCategoryId;

  bool get isEmpty => counts.isEmpty;

  String? bestCategoryId(Set<String> availableCategoryIds) {
    final candidates = counts.entries
        .where((entry) => availableCategoryIds.contains(entry.key))
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((left, right) {
      final countCompare = right.value.compareTo(left.value);
      if (countCompare != 0) {
        return countCompare;
      }

      if (left.key == lastCategoryId) {
        return -1;
      }
      if (right.key == lastCategoryId) {
        return 1;
      }

      return left.key.compareTo(right.key);
    });

    return candidates.first.key;
  }

  _MutableCategoryLearningRule mutableCopy() {
    return _MutableCategoryLearningRule(
      counts: {...counts},
      lastCategoryId: lastCategoryId,
    );
  }

  factory _CategoryLearningRule.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    final counts = <String, int>{};

    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final categoryId = entry.key.toString();
        final rawCount = entry.value;
        final count = rawCount is int
            ? rawCount
            : int.tryParse(rawCount.toString()) ?? 0;
        if (categoryId.isNotEmpty && count > 0) {
          counts[categoryId] = count;
        }
      }
    }

    return _CategoryLearningRule(
      counts: Map.unmodifiable(counts),
      lastCategoryId: json['lastCategoryId'] as String?,
    );
  }
}

class _MutableCategoryLearningRule {
  _MutableCategoryLearningRule({Map<String, int>? counts, this.lastCategoryId})
    : counts = counts ?? {};

  final Map<String, int> counts;
  String? lastCategoryId;

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  void increment(String categoryId) {
    counts.update(categoryId, (count) => count + 1, ifAbsent: () => 1);
    lastCategoryId = categoryId;
  }

  _CategoryLearningRule toImmutableRule() {
    return _CategoryLearningRule(
      counts: Map.unmodifiable(counts),
      lastCategoryId: lastCategoryId,
    );
  }

  Map<String, dynamic> toJson() {
    return {'counts': counts, 'lastCategoryId': lastCategoryId};
  }
}

List<String> _titleKeys(String title) {
  final normalized = _normalizeTitle(title);
  if (normalized.isEmpty) {
    return const [];
  }

  final words = normalized.split(' ');
  final keys = <String>{normalized};

  if (words.length >= 2) {
    keys.add('${words[0]} ${words[1]}');
  }

  final firstWord = words.first;
  if (firstWord.length >= 3) {
    keys.add(firstWord);
  }

  return keys.toList(growable: false);
}

String _normalizeTitle(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
