import 'package:flutter/widgets.dart';

class PatientLocalizations {
  const PatientLocalizations._(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('tr')];
  static const delegate = PatientLocalizationsDelegate();

  static Locale resolve(Locale? locale) {
    if (locale?.languageCode.toLowerCase() == 'tr') {
      return const Locale('tr');
    }
    return const Locale('en');
  }

  static PatientLocalizations forLocale(Locale? locale) =>
      PatientLocalizations._(resolve(locale));

  static PatientLocalizations of(BuildContext context) =>
      Localizations.of<PatientLocalizations>(context, PatientLocalizations) ??
      forLocale(Localizations.maybeLocaleOf(context));

  bool get isTurkish => locale.languageCode == 'tr';

  String get appTitle => 'Cycle';
  String get calendar => isTurkish ? 'Takvim' : 'Calendar';
  String get previousMonth => isTurkish ? 'Önceki ay' : 'Previous month';
  String get nextMonth => isTurkish ? 'Sonraki ay' : 'Next month';
  List<String> get weekdayLabels => isTurkish
      ? const <String>['P', 'S', 'Ç', 'P', 'C', 'C', 'P']
      : const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String get today => isTurkish ? 'Bugün' : 'Today';
  String get todayHint => isTurkish
      ? 'Yalnızca önemli olanı kaydet. Cycle geri kalanını sessiz tutar.'
      : 'Only log what matters. Cycle keeps the rest quiet.';
  String get cycleDayUnknown =>
      isTurkish ? 'Döngü günü bilinmiyor' : 'Cycle day unknown';
  String cycleDay(int day) => isTurkish ? 'Döngü günü $day' : 'Cycle day $day';
  String get logPeriodStartHint => isTurkish
      ? 'Başladığında adet başlangıcını kaydet.'
      : 'Log a period start when it happens.';
  String get latestPeriodStartHint => isTurkish
      ? 'En son kaydedilen adet başlangıcına göre.'
      : 'Based on your latest logged period start.';

  String get quickLog => isTurkish ? 'Hızlı Kayıt' : 'Quick Log';
  String get quickLogCardHint => isTurkish
      ? 'Adet, akış veya belirtiyi tek dokunuşla kaydet'
      : 'Period, flow or a symptom in one tap';
  String get quickLogHint => isTurkish
      ? 'Bir kez dokun. İstersen ayrıntıları daha sonra ekleyebilirsin.'
      : 'Tap once. You can add details later if you want.';
  String get log => isTurkish ? 'Kaydet' : 'Log';

  String get periodStarted => isTurkish ? 'Adet başladı' : 'Period started';
  String get lightFlow => isTurkish ? 'Hafif akış' : 'Light flow';
  String get mediumFlow => isTurkish ? 'Orta akış' : 'Medium flow';
  String get heavyFlow => isTurkish ? 'Yoğun akış' : 'Heavy flow';
  String get flow => isTurkish ? 'Akış' : 'Flow';
  String get cramps => isTurkish ? 'Kramplar' : 'Cramps';
  String get headache => isTurkish ? 'Baş ağrısı' : 'Headache';
  String get lowMood => isTurkish ? 'Düşük ruh hali' : 'Low mood';

  String get encryptedLocalVault =>
      isTurkish ? 'Şifreli yerel kasa' : 'Encrypted local vault';
  String vaultSummary(int count, String state) => isTurkish
      ? '$count yerel sağlık kaydı · $state'
      : '$count local health event(s) · $state';
  String get opening => isTurkish ? 'Açılıyor…' : 'Opening…';
  String get timeline => isTurkish ? 'Zaman Çizelgesi' : 'Timeline';
  String get nothingLogged => isTurkish
      ? 'Henüz kayıt yok. Yalnızca yararlı olduğunda bir şey ekle.'
      : 'Nothing logged yet. Add something only when useful.';

  String get privateDataLocked => isTurkish
      ? 'Özel sağlık verileri kilitli.'
      : 'Private health data is locked.';
  String get authenticationRequired => isTurkish
      ? 'Özel sağlık verilerini açmak için kimlik doğrulama gerekiyor.'
      : 'Authentication is required to open private health data.';
  String get unlock => isTurkish ? 'Kilidi aç' : 'Unlock';
  String get unlockReason => isTurkish
      ? 'Özel sağlık verilerinizi görüntülemek için Cycle kilidini açın.'
      : 'Unlock Cycle to view your private health data.';

  String eventsCount(int count) =>
      isTurkish ? '$count kayıt' : '$count event${count == 1 ? '' : 's'}';
  String loggedEventsCount(int count) => isTurkish
      ? '$count kayıtlı olay'
      : '$count logged event${count == 1 ? '' : 's'}';
}

class PatientLocalizationsDelegate
    extends LocalizationsDelegate<PatientLocalizations> {
  const PatientLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'tr';

  @override
  Future<PatientLocalizations> load(Locale locale) async =>
      PatientLocalizations.forLocale(locale);

  @override
  bool shouldReload(PatientLocalizationsDelegate old) => false;
}
