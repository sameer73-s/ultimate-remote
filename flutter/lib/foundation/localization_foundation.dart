import 'package:flutter/widgets.dart';

/// Core locales guaranteed by the Ultimate Remote foundation.
class RemoteLocalization {
  RemoteLocalization._();

  static const Locale english = Locale('en', 'US');
  static const Locale arabic = Locale('ar');
  static const List<Locale> coreLocales = <Locale>[english, arabic];

  static TextDirection directionFor(Locale locale) {
    return const <String>{
      'ar',
      'fa',
      'he',
      'ur',
    }.contains(locale.languageCode.toLowerCase())
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static bool isRightToLeft(Locale locale) {
    return directionFor(locale) == TextDirection.rtl;
  }

  static Locale? resolve(Locale? requested, Iterable<Locale> supported) {
    if (requested == null) {
      return null;
    }
    for (final candidate in supported) {
      if (candidate.languageCode == requested.languageCode &&
          (candidate.countryCode == null ||
              candidate.countryCode == requested.countryCode)) {
        return candidate;
      }
    }
    return null;
  }
}
