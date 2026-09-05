import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/models/collection_model.dart';
import 'package:quotewidget/widgets/share_target_dialog.dart';

/// plan6 H5: share-target confirmation dialog.
///
/// Pure widget contract (no Hive — deterministic): the dialog shows the
/// default collection, and the three actions resolve to the right enum so
/// main.dart can save / open the picker / abort.
void main() {
  final defaultCollection = Collection(
    id: 'col-1',
    name: 'My Quotes',
    createdAt: DateTime(2026, 9, 5),
  );

  /// Pumps the app + opens the dialog (no action tapped yet).
  Future<void> pumpAndOpen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  await showShareTargetDialog(
                    context,
                    defaultCollection: defaultCollection,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Opens the dialog, taps [label] (or the barrier when [dismissByBarrier]),
  /// and resolves the awaited dialog future via the widget tree.
  Future<ShareTargetAction?> pumpAndTap(WidgetTester tester, String label,
      {bool dismissByBarrier = false}) async {
    ShareTargetAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showShareTargetDialog(
                    context,
                    defaultCollection: defaultCollection,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    if (dismissByBarrier) {
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
    } else {
      await tester.tap(find.text(label));
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('dialog shows default collection + 3 actions', (tester) async {
    await pumpAndOpen(tester);

    expect(find.text('Save shared text'), findsOneWidget);
    expect(find.text('Lưu vào "My Quotes"?'), findsOneWidget);
    expect(find.text('Lưu vào'), findsOneWidget); // primary save action
    expect(find.text('Đổi collection'), findsOneWidget);
    expect(find.text('Huỷ'), findsOneWidget);
  });

  testWidgets('primary action → saveDefault', (tester) async {
    final result = await pumpAndTap(tester, 'Lưu vào');
    expect(result, ShareTargetAction.saveDefault);
  });

  testWidgets('secondary action → changeCollection', (tester) async {
    final result = await pumpAndTap(tester, 'Đổi collection');
    expect(result, ShareTargetAction.changeCollection);
  });

  testWidgets('cancel → cancel', (tester) async {
    final result = await pumpAndTap(tester, 'Huỷ');
    expect(result, ShareTargetAction.cancel);
  });

  testWidgets('dismissing the dialog (barrier tap) → cancel', (tester) async {
    final result =
        await pumpAndTap(tester, '', dismissByBarrier: true);
    expect(result, ShareTargetAction.cancel);
  });
}