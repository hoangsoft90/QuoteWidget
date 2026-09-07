import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/models/collection_model.dart';
import 'package:quotewidget/screens/collection_detail_screen.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:quotewidget/services/widget_service.dart';

/// Final Hardening P1-1: while search or the favorites-only filter is active,
/// the Collection Detail list is a SUBSET of the collection. Persisting that
/// subset's order would renumber only the visible items and silently corrupt
/// the `order` of every item hidden by the filter. Reorder must be disabled
/// (no drag listeners) and any reorder attempt must no-op + explain why.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;
  late Collection col;
  late List<String> itemIds;

  List<MethodCall> mockHomeWidgetChannel() {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return calls;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockHomeWidgetChannel();
    tempDir = await Directory.systemTemp.createTemp('cd_reorder_test_');
    storage = StorageService();
    await storage.init(testPath: tempDir.path);
    col = await storage.createCollection('Col');
    await storage.createItem(collectionId: col.id, text: 'A', order: 0);
    await storage.createItem(collectionId: col.id, text: 'B', order: 1);
    await storage.createItem(collectionId: col.id, text: 'C', order: 2);
    itemIds =
        storage.getItemsForCollection(col.id).map((i) => i.id).toList();
  });

  tearDown(() async {
    await storage.clearAll();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CollectionDetailScreen(
        collection: col,
        storageService: storage,
        widgetService: WidgetService(storage),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<String> persistedOrder() =>
      storage.getItemsForCollection(col.id).map((i) => i.text).toList();

  const disabledSnack = 'Tắt tìm kiếm/lọc để sắp xếp lại thứ tự';

  testWidgets('search active → reorder no-ops with snackbar + no drag handles',
      (tester) async {
    await pumpScreen(tester);

    // Enable search and type a query → subset view.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'B');
    await tester.pumpAndSettle();

    // Subset shown (item card text), and NO drag listeners are present
    // (reorder disabled). (find.text would also match the search field's own
    // text, so scope the item lookup to Cards.)
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('B')),
      findsOneWidget,
      reason: 'search result visible',
    );
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing,
        reason: 'P1-1: while search is active items must not be draggable');

    // A reorder attempt (whatever triggers it) must no-op + explain.
    final state = tester.state(find.byType(CollectionDetailScreen));
    await (state as dynamic).handleReorder(0, 1);
    await tester.pump();

    expect(find.text(disabledSnack), findsOneWidget,
        reason: 'user must be told why sorting is off');
    expect(persistedOrder(), ['A', 'B', 'C'],
        reason: 'P1-1: the subset order must never be persisted');
  });

  testWidgets('favorites-only active → reorder no-ops with snackbar',
      (tester) async {
    // Only B is a favorite → favorites-only view is a subset [B].
    // (Real Hive IO must run outside the fake-async zone.)
    await tester.runAsync(() => storage.setItemFavorite(itemIds[1], true));

    await pumpScreen(tester);
    // The AppBar star toggles the favorites-only filter (the item rows each
    // have their own star icons — scope the tap to the AppBar action).
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.star_border),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing,
        reason: 'P1-1: while the favorites filter is active nothing is '
            'draggable');

    final state = tester.state(find.byType(CollectionDetailScreen));
    await (state as dynamic).handleReorder(0, 1);
    await tester.pump();

    expect(find.text(disabledSnack), findsOneWidget);
    expect(persistedOrder(), ['A', 'B', 'C'],
        reason: 'P1-1: hidden items must keep their order');
  });

  testWidgets('no filter → reorder still works as before', (tester) async {
    await pumpScreen(tester);

    // Full list → every tile is wrapped in a drag listener.
    expect(find.byType(ReorderableDelayedDragStartListener), findsNWidgets(3));

    final state = tester.state(find.byType(CollectionDetailScreen));
    await tester.runAsync(() async {
      await (state as dynamic).handleReorder(0, 1);
    });
    await tester.pumpAndSettle();

    expect(persistedOrder(), ['B', 'A', 'C'],
        reason: 'unfiltered reorder must keep working (A,B,C → B,A,C)');
  });
}
