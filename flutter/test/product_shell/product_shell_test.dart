import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/product_shell/product_shell.dart';

void main() {
  Widget buildTestApp() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MyTheme.lightTheme,
      darkTheme: MyTheme.darkTheme,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      home: const ProductShellPage(),
    );
  }

  testWidgets('renders Ultimate Remote overview and responsive navigation',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.text('Welcome to Ultimate Remote'), findsOneWidget);
    expect(find.text('Managed devices'), findsOneWidget);
    expect(find.bySemanticsLabel('Devices'), findsOneWidget);
    expect(find.bySemanticsLabel('Overview'), findsOneWidget);
  });

  testWidgets('renders an honest empty device state without fake records',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.bySemanticsLabel('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('No managed devices'), findsOneWidget);
    expect(find.textContaining('There are no device records'), findsOneWidget);
    expect(find.text('Open remote workspace'), findsOneWidget);
  });

  testWidgets('renders settings and about product surfaces', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme mode'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.textContaining('built on RustDesk'), findsOneWidget);
  });

  testWidgets('switches product shell to Arabic and RTL', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Locale>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsWidgets);
    final directions =
        tester.widgetList<Directionality>(find.byType(Directionality));
    expect(
      directions.any((directionality) =>
          directionality.textDirection == TextDirection.rtl),
      isTrue,
    );
  });
}
