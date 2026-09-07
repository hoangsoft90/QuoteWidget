import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/screens/share_quote_card_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B3: the quote-card screen builds the simple card template (text + author
/// + app name) and the share pipeline produces a real PNG through
/// [renderQuoteCardPng] — the exact function the share button calls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('b3_share_test_');
    // renderQuoteCardPng writes into the app temp dir — mock the plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    await tempDir.delete(recursive: true);
  });

  testWidgets('card renders quote, author and app name', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShareQuoteCardScreen(
        quoteText: 'Simplicity is the ultimate sophistication',
        author: 'da Vinci',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Simplicity is the ultimate sophistication'),
        findsOneWidget);
    expect(find.text('— da Vinci'), findsOneWidget);
    expect(find.text('Quote Widget'), findsOneWidget);
  });

  testWidgets('card omits the author line when unset', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const ShareQuoteCardScreen(quoteText: 'No author here'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No author here'), findsOneWidget);
    expect(find.textContaining('—'), findsNothing,
        reason: 'no author → no em-dash line');
  });

  test('share pipeline renders a real PNG file (with author)', () async {
    final file = await renderQuoteCardPng(
      'Simplicity is the ultimate sophistication',
      'da Vinci',
    );

    expect(await file.exists(), isTrue);
    expect(file.path.endsWith('.png'), isTrue);
    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(1000),
        reason: 'rendered card is a substantial image, not a blank stub');
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47],
        reason: 'file must be a real PNG');
  });

  test('share pipeline works without an author (branch covered)', () async {
    final file = await renderQuoteCardPng('No author here', null);

    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
