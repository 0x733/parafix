import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense_category.dart';

class ReceiptScanResult {
  const ReceiptScanResult({this.title, this.amount, this.date, this.category});

  final String? title;
  final double? amount;
  final DateTime? date;
  final ExpenseCategory? category;

  bool get hasAnySuggestion =>
      title != null || amount != null || date != null || category != null;
}

class ReceiptScanService {
  ReceiptScanService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const _ocrChannel = MethodChannel('parafix/receipt_ocr');

  final ImagePicker _imagePicker;

  Future<ReceiptScanResult?> scanFromSource({
    required ImageSource source,
    required List<ExpenseCategory> categories,
  }) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 86,
      maxWidth: 1800,
    );

    if (image == null) {
      return null;
    }

    final lines = await _recognizeLines(image.path);
    if (lines.isEmpty) {
      return const ReceiptScanResult();
    }

    return _parseReceiptLines(lines, categories);
  }

  Future<List<String>> _recognizeLines(String imagePath) async {
    final result = await _ocrChannel.invokeListMethod<String>('recognizeText', {
      'path': imagePath,
    });

    return (result ?? const <String>[])
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

ReceiptScanResult _parseReceiptLines(
  List<String> lines,
  List<ExpenseCategory> categories,
) {
  final fullText = lines.join('\n');
  final title = _pickReceiptTitle(lines);
  final amount = _pickReceiptAmount(lines);
  final date = _pickReceiptDate(fullText);
  final category = _suggestCategory('$title\n$fullText', categories);

  return ReceiptScanResult(
    title: title,
    amount: amount,
    date: date,
    category: category,
  );
}

String? _pickReceiptTitle(List<String> lines) {
  final fullText = lines.join('\n');
  final merchantTitle = _matchKnownMerchant(fullText);
  if (merchantTitle != null) {
    return merchantTitle;
  }

  for (final line in lines.take(12)) {
    final cleaned = _cleanTitleCandidate(line);
    final merchantLineTitle = _matchKnownMerchant(cleaned);
    if (merchantLineTitle != null) {
      return merchantLineTitle;
    }

    if (!_isLikelyTitleLine(cleaned)) {
      continue;
    }

    return _simplifyMerchantTitle(cleaned);
  }

  return null;
}

String? _matchKnownMerchant(String text) {
  final normalized = _normalizeText(text);

  for (final merchant in _knownMerchants) {
    for (final alias in merchant.aliases) {
      if (normalized.contains(alias)) {
        return merchant.title;
      }
    }
  }

  return null;
}

bool _isLikelyTitleLine(String value) {
  final normalized = _normalizeText(value);

  return value.length >= 3 &&
      value.length <= 42 &&
      !_containsAmount(value) &&
      !_datePattern.hasMatch(value) &&
      !normalized.contains('fis') &&
      !normalized.contains('fatura') &&
      !normalized.contains('tarih') &&
      !normalized.contains('toplam') &&
      !normalized.contains('pos') &&
      !normalized.contains('terminal') &&
      !normalized.contains('musteri') &&
      !normalized.contains('vergi') &&
      !normalized.contains('vkn') &&
      !normalized.contains('mersis') &&
      !normalized.contains('sube') &&
      !normalized.contains('adres') &&
      !normalized.contains('tel');
}

double? _pickReceiptAmount(List<String> lines) {
  final candidates = <_AmountCandidate>[];

  for (final line in lines) {
    final normalizedLine = _normalizeText(line);

    for (final match in _amountPattern.allMatches(line)) {
      final amount = _parseAmount(match.group(1)!);
      if (amount == null || amount <= 0 || amount > 1000000) {
        continue;
      }

      var score = 0;
      if (normalizedLine.contains('genel toplam')) score += 80;
      if (normalizedLine.contains('toplam')) score += 60;
      if (normalizedLine.contains('tutar')) score += 46;
      if (normalizedLine.contains('odenecek')) score += 42;
      if (normalizedLine.contains('satis')) score += 16;
      if (match.group(2) != null) score += 12;
      if (_hasDecimalPart(match.group(1)!)) score += 6;
      if (normalizedLine.contains('kdv')) score -= 34;
      if (normalizedLine.contains('para ustu')) score -= 70;
      if (normalizedLine.contains('nakit')) score -= 24;
      if (normalizedLine.contains('fis no')) score -= 40;

      candidates.add(_AmountCandidate(amount: amount, score: score));
    }
  }

  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return b.amount.compareTo(a.amount);
  });

  final best = candidates.first;
  if (best.score <= 0) {
    return candidates.map((candidate) => candidate.amount).reduce(math.max);
  }

  return best.amount;
}

DateTime? _pickReceiptDate(String text) {
  final now = DateTime.now();

  for (final match in _datePattern.allMatches(text)) {
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final rawYear = int.tryParse(match.group(3)!);

    if (day == null || month == null || rawYear == null) {
      continue;
    }

    final year = rawYear < 100 ? 2000 + rawYear : rawYear;
    if (month < 1 || month > 12 || day < 1 || day > _daysInMonth(year, month)) {
      continue;
    }

    final date = DateTime(year, month, day);
    if (date.isAfter(now)) {
      return DateTime(now.year, now.month, now.day);
    }

    return date;
  }

  return null;
}

ExpenseCategory? _suggestCategory(
  String text,
  List<ExpenseCategory> categories,
) {
  final normalized = _normalizeText(text);
  final scores = <String, int>{};

  void score(String categoryId, List<String> keywords) {
    for (final keyword in keywords) {
      if (normalized.contains(keyword)) {
        scores.update(categoryId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
  }

  score('market', [
    'market',
    'supermarket',
    'hipermarket',
    'migros',
    'migros jet',
    'bim',
    'a101',
    'sok',
    'sok market',
    'sok marketler',
    'carrefour',
    'carrefoursa',
    'macro',
    'macrocenter',
    'file',
    'gross',
    'bizim gross',
    'bizimgross',
    'metro market',
    'hakmar',
    'onur market',
    'happy center',
    'kim market',
    'sec market',
    'tarim kredi',
    'istegelsin',
    'getir market',
    'getir buyuk',
  ]);
  score('food', [
    'restoran',
    'restaurant',
    'cafe',
    'kafe',
    'kahve',
    'yemek',
    'lokanta',
    'fast food',
    'burger',
    'pizza',
    'doner',
    'kofte',
    'pide',
    'lahmacun',
    'kebap',
    'starbucks',
    'kahve dunyasi',
    'espresso lab',
    'gloria jeans',
    'caffe nero',
    'mcdonald',
    'burger king',
    'popeyes',
    'kfc',
    'dominos',
    'pizza hut',
    'little caesars',
    'arbys',
    'tavuk dunyasi',
    'baydoner',
    'kofteci yusuf',
    'midyeci',
    'yemeksepeti',
    'getir yemek',
    'trendyol yemek',
  ]);
  score('transport', [
    'taksi',
    'taxi',
    'bitaksi',
    'uber',
    'metro',
    'metro istanbul',
    'marmaray',
    'iett',
    'izban',
    'ego',
    'eshot',
    'ulasim',
    'otobus',
    'minibus',
    'dolmus',
    'havaist',
    'havabus',
    'thy',
    'turkish airlines',
    'pegasus',
    'ajet',
    'anadolu jet',
    'obilet',
    'enuygun',
    'otopark',
    'ispark',
    'marti',
    'binbin',
    'hop',
    'shell',
    'opet',
    'bp',
    'petrol ofisi',
    'total',
    'totalenergies',
    'aytemiz',
    'alpet',
    'lukoil',
    'tp',
    'turkiye petrolleri',
    'petrol',
    'akaryakit',
    'benzin',
    'mazot',
    'motorin',
    'istasyon',
  ]);
  score('bills', [
    'fatura',
    'elektrik',
    'enerji',
    'enerjisa',
    'ck bogazici',
    'ayedas',
    'bedas',
    'dogalgaz',
    'igdas',
    'su faturasi',
    'iski',
    'aski',
    'internet',
    'turkcell',
    'vodafone',
    'telekom',
    'turk telekom',
    'ttnet',
    'superonline',
    'turksat',
    'kablonet',
    'millenicom',
    'netspeed',
    'dsmart',
    'digiturk',
    'faturamatik',
    'otomatik odeme',
  ]);
  score('rent', [
    'kira',
    'rent',
    'konut kira',
    'ev kira',
    'apartman aidat',
    'site aidat',
  ]);
  score('health', [
    'eczane',
    'hastane',
    'medikal',
    'saglik',
    'pharmacy',
    'hospital',
    'klinik',
    'poliklinik',
    'dis',
    'dent',
    'optik',
    'lens',
    'laboratuvar',
    'lab',
    'acibadem',
    'memorial',
    'medipol',
    'medicana',
    'medical park',
    'liv hospital',
    'amerikan hastanesi',
    'florence nightingale',
    'lokman hekim',
    'duzen lab',
    'synevo',
  ]);
  score('shopping', [
    'alisveris',
    'trendyol',
    'hepsiburada',
    'amazon',
    'n11',
    'pttavm',
    'ciceksepeti',
    'lcw',
    'lc waikiki',
    'zara',
    'magaza',
    'store',
    'boyner',
    'morhipo',
    'defacto',
    'koton',
    'mavi',
    'colins',
    'flo',
    'ayakkabi dunyasi',
    'instreet',
    'decathlon',
    'teknosa',
    'media markt',
    'mediamarkt',
    'vatan',
    'vatan bilgisayar',
    'ikea',
    'koctas',
    'bauhaus',
    'tekzen',
    'gratis',
    'rossmann',
    'watsons',
    'avm',
    'kitap',
    'kirtasiye',
  ]);
  score('entertainment', [
    'sinema',
    'cinema',
    'cinemaximum',
    'paribu cineverse',
    'eglence',
    'netflix',
    'spotify',
    'youtube',
    'youtube premium',
    'disney',
    'disneyplus',
    'blutv',
    'gain',
    'exxen',
    'prime video',
    'amazon prime',
    'tod',
    'bein',
    'oyun',
    'steam',
    'epic games',
    'playstation',
    'psn',
    'xbox',
    'biletix',
    'passo',
    'konser',
    'tiyatro',
    'muze',
  ]);

  if (scores.isEmpty) {
    return _findCategory(categories, 'other');
  }

  final bestCategoryId = scores.entries.reduce((left, right) {
    if (right.value > left.value) {
      return right;
    }
    return left;
  }).key;

  return _findCategory(categories, bestCategoryId) ??
      _findCategory(categories, 'other');
}

ExpenseCategory? _findCategory(List<ExpenseCategory> categories, String id) {
  for (final category in categories) {
    if (category.id == id) {
      return category;
    }
  }

  return null;
}

String _cleanTitleCandidate(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[^a-zA-ZçğıöşüÇĞİÖŞÜ0-9]+'), '')
      .trim();
}

String _simplifyMerchantTitle(String value) {
  var title = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\bTICARET\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bTİCARET\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bSANAYI\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bSANAYİ\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bMAGAZACILIK\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bMAĞAZACILIK\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bGIDA\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bLTD\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bSTI\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bŞTİ\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bA\.?S\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bA\.?Ş\.?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (title.length > 28) {
    title = title.substring(0, 28).trim();
  }

  return title.isEmpty ? value : title;
}

String _normalizeText(String value) {
  return value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

double? _parseAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'\s'), '');
  final commaIndex = cleaned.lastIndexOf(',');
  final dotIndex = cleaned.lastIndexOf('.');
  final decimalIndex = math.max(commaIndex, dotIndex);

  if (decimalIndex == -1) {
    return double.tryParse(cleaned.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  final whole = cleaned
      .substring(0, decimalIndex)
      .replaceAll(RegExp(r'[^0-9]'), '');
  final fraction = cleaned
      .substring(decimalIndex + 1)
      .replaceAll(RegExp(r'[^0-9]'), '');

  if (whole.isEmpty || fraction.isEmpty) {
    return null;
  }

  return double.tryParse('$whole.$fraction');
}

bool _containsAmount(String value) => _amountPattern.hasMatch(value);

bool _hasDecimalPart(String value) {
  return RegExp(r'[.,]\d{2}\b').hasMatch(value);
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

class _AmountCandidate {
  const _AmountCandidate({required this.amount, required this.score});

  final double amount;
  final int score;
}

class _KnownMerchant {
  const _KnownMerchant({required this.title, required this.aliases});

  final String title;
  final List<String> aliases;
}

const _knownMerchants = [
  _KnownMerchant(title: 'Migros', aliases: ['migros']),
  _KnownMerchant(title: 'BİM', aliases: ['bim']),
  _KnownMerchant(title: 'A101', aliases: ['a101']),
  _KnownMerchant(title: 'Şok', aliases: ['sok market', 'sok marketler']),
  _KnownMerchant(title: 'CarrefourSA', aliases: ['carrefour', 'carrefoursa']),
  _KnownMerchant(title: 'Macrocenter', aliases: ['macrocenter', 'macro']),
  _KnownMerchant(title: 'File Market', aliases: ['file market', 'file']),
  _KnownMerchant(title: 'Hakmar', aliases: ['hakmar']),
  _KnownMerchant(title: 'Onur Market', aliases: ['onur market']),
  _KnownMerchant(title: 'Tarım Kredi', aliases: ['tarim kredi']),
  _KnownMerchant(title: 'Getir', aliases: ['getir']),
  _KnownMerchant(title: 'Yemeksepeti', aliases: ['yemeksepeti']),
  _KnownMerchant(title: 'Trendyol', aliases: ['trendyol']),
  _KnownMerchant(title: 'Hepsiburada', aliases: ['hepsiburada']),
  _KnownMerchant(title: 'Amazon', aliases: ['amazon']),
  _KnownMerchant(title: 'N11', aliases: ['n11']),
  _KnownMerchant(title: 'Çiçeksepeti', aliases: ['ciceksepeti']),
  _KnownMerchant(title: 'Starbucks', aliases: ['starbucks']),
  _KnownMerchant(title: 'Kahve Dünyası', aliases: ['kahve dunyasi']),
  _KnownMerchant(title: 'EspressoLab', aliases: ['espresso lab']),
  _KnownMerchant(title: 'Gloria Jean’s', aliases: ['gloria jeans']),
  _KnownMerchant(title: 'Caffè Nero', aliases: ['caffe nero']),
  _KnownMerchant(title: 'McDonald’s', aliases: ['mcdonald']),
  _KnownMerchant(title: 'Burger King', aliases: ['burger king']),
  _KnownMerchant(title: 'KFC', aliases: ['kfc']),
  _KnownMerchant(title: 'Popeyes', aliases: ['popeyes']),
  _KnownMerchant(title: 'Domino’s', aliases: ['dominos']),
  _KnownMerchant(title: 'Pizza Hut', aliases: ['pizza hut']),
  _KnownMerchant(title: 'Tavuk Dünyası', aliases: ['tavuk dunyasi']),
  _KnownMerchant(title: 'Köfteci Yusuf', aliases: ['kofteci yusuf']),
  _KnownMerchant(title: 'Baydöner', aliases: ['baydoner']),
  _KnownMerchant(title: 'BiTaksi', aliases: ['bitaksi']),
  _KnownMerchant(title: 'Uber', aliases: ['uber']),
  _KnownMerchant(title: 'İETT', aliases: ['iett']),
  _KnownMerchant(title: 'Marmaray', aliases: ['marmaray']),
  _KnownMerchant(title: 'İZBAN', aliases: ['izban']),
  _KnownMerchant(title: 'Havaist', aliases: ['havaist']),
  _KnownMerchant(title: 'Havabus', aliases: ['havabus']),
  _KnownMerchant(title: 'THY', aliases: ['thy', 'turkish airlines']),
  _KnownMerchant(title: 'Pegasus', aliases: ['pegasus']),
  _KnownMerchant(title: 'AJet', aliases: ['ajet', 'anadolu jet']),
  _KnownMerchant(title: 'Obilet', aliases: ['obilet']),
  _KnownMerchant(title: 'Enuygun', aliases: ['enuygun']),
  _KnownMerchant(title: 'İspark', aliases: ['ispark']),
  _KnownMerchant(title: 'Martı', aliases: ['marti']),
  _KnownMerchant(title: 'Shell', aliases: ['shell']),
  _KnownMerchant(title: 'Opet', aliases: ['opet']),
  _KnownMerchant(title: 'BP', aliases: ['bp']),
  _KnownMerchant(title: 'Petrol Ofisi', aliases: ['petrol ofisi']),
  _KnownMerchant(title: 'TotalEnergies', aliases: ['totalenergies', 'total']),
  _KnownMerchant(title: 'Aytemiz', aliases: ['aytemiz']),
  _KnownMerchant(title: 'Turkcell', aliases: ['turkcell']),
  _KnownMerchant(title: 'Vodafone', aliases: ['vodafone']),
  _KnownMerchant(title: 'Türk Telekom', aliases: ['turk telekom', 'telekom']),
  _KnownMerchant(title: 'Superonline', aliases: ['superonline']),
  _KnownMerchant(title: 'Kablonet', aliases: ['kablonet', 'turksat']),
  _KnownMerchant(title: 'Enerjisa', aliases: ['enerjisa']),
  _KnownMerchant(title: 'İGDAŞ', aliases: ['igdas']),
  _KnownMerchant(title: 'İSKİ', aliases: ['iski']),
  _KnownMerchant(title: 'Eczane', aliases: ['eczane']),
  _KnownMerchant(title: 'Acıbadem', aliases: ['acibadem']),
  _KnownMerchant(title: 'Memorial', aliases: ['memorial']),
  _KnownMerchant(title: 'Medipol', aliases: ['medipol']),
  _KnownMerchant(title: 'Medical Park', aliases: ['medical park']),
  _KnownMerchant(title: 'Medicana', aliases: ['medicana']),
  _KnownMerchant(title: 'Gratis', aliases: ['gratis']),
  _KnownMerchant(title: 'Rossmann', aliases: ['rossmann']),
  _KnownMerchant(title: 'Watsons', aliases: ['watsons']),
  _KnownMerchant(title: 'LC Waikiki', aliases: ['lc waikiki', 'lcw']),
  _KnownMerchant(title: 'Zara', aliases: ['zara']),
  _KnownMerchant(title: 'Boyner', aliases: ['boyner']),
  _KnownMerchant(title: 'DeFacto', aliases: ['defacto']),
  _KnownMerchant(title: 'Koton', aliases: ['koton']),
  _KnownMerchant(title: 'Mavi', aliases: ['mavi']),
  _KnownMerchant(title: 'FLO', aliases: ['flo']),
  _KnownMerchant(title: 'Decathlon', aliases: ['decathlon']),
  _KnownMerchant(title: 'Teknosa', aliases: ['teknosa']),
  _KnownMerchant(title: 'MediaMarkt', aliases: ['media markt', 'mediamarkt']),
  _KnownMerchant(title: 'Vatan Bilgisayar', aliases: ['vatan bilgisayar']),
  _KnownMerchant(title: 'IKEA', aliases: ['ikea']),
  _KnownMerchant(title: 'Koçtaş', aliases: ['koctas']),
  _KnownMerchant(title: 'Bauhaus', aliases: ['bauhaus']),
  _KnownMerchant(title: 'Netflix', aliases: ['netflix']),
  _KnownMerchant(title: 'Spotify', aliases: ['spotify']),
  _KnownMerchant(title: 'YouTube', aliases: ['youtube']),
  _KnownMerchant(title: 'Disney+', aliases: ['disneyplus', 'disney']),
  _KnownMerchant(title: 'BluTV', aliases: ['blutv']),
  _KnownMerchant(title: 'Exxen', aliases: ['exxen']),
  _KnownMerchant(title: 'Steam', aliases: ['steam']),
  _KnownMerchant(title: 'PlayStation', aliases: ['playstation', 'psn']),
  _KnownMerchant(title: 'Biletix', aliases: ['biletix']),
  _KnownMerchant(title: 'Passo', aliases: ['passo']),
  _KnownMerchant(title: 'Paribu Cineverse', aliases: ['paribu cineverse']),
  _KnownMerchant(title: 'Cinemaximum', aliases: ['cinemaximum']),
];

final _datePattern = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b');
final _amountPattern = RegExp(
  r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2})|\d+)\s*(₺|TL|TRY)?\b',
  caseSensitive: false,
);
