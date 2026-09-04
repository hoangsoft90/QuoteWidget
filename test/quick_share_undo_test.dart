import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/widgets/share_undo_snackbar.dart';

/// Quick Share Undo UI contract (plan5 Sprint 0 §1.7).
///
/// The Hive-level undo semantics (saveToCollection returns the exact created
/// Item; deleteItem soft-deletes it into Trash) are covered in
/// share_service_test.dart — Hive file I/O cannot run under testWidgets'
/// FakeAsync zone. Here we verify the SnackBar contract itself: it shows
/// "Saved to `collectionName`" with a live Undo action, the action fires the
/// onUndo callback, and the confirmation swaps to "Share removed".
void main() {
  Widget harness({required void Function() onUndoPressed}) {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showShareUndoSnackBar(
                messengerKey.currentState!,
                collectionName: 'Test',
                onUndo: () async => onUndoPressed(),
              ),
              child: const Text('trigger share save'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows "Saved to X" with an Undo action', (tester) async {
    await tester.pumpWidget(harness(onUndoPressed: () {}));

    await tester.tap(find.text('trigger share save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // finish entrance

    expect(find.text('Saved to Test'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('tapping Undo fires onUndo and confirms removal',
      (tester) async {
    var undoFired = false;
    await tester.pumpWidget(harness(onUndoPressed: () => undoFired = true));

    await tester.tap(find.text('trigger share save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // fully shown

    await tester.tap(find.text('Undo'));
    // Flush the async onUndo + SnackBar exit/enter animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(undoFired, isTrue, reason: 'Undo action must invoke the callback');
    expect(find.text('Share removed'), findsOneWidget,
        reason: 'confirmation must swap to "Share removed"');
  });

  testWidgets('SnackBar carries the 10s expiry + Undo action contract',
      (tester) async {
    await tester.pumpWidget(harness(onUndoPressed: () {}));

    await tester.tap(find.text('trigger share save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // entrance done

    // plan5 §1.7: the Undo action must expire after ~10–15s. The auto-dismiss
    // timer is Flutter framework behavior once the SnackBar is configured;
    // our contract is that we BUILD it with a 10s duration and an Undo
    // action — assert the actual widget configuration.
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 10),
        reason: 'Undo action must auto-expire after 10s');
    expect(snackBar.action, isNotNull,
        reason: 'confirmation carries an Undo action');
    expect(snackBar.action!.label, 'Undo');
  });
}