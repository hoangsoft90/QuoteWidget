import '../models/item_model.dart';
import '../services/storage_service.dart';

class ShareService {
  final StorageService _storageService;

  ShareService(this._storageService);

  /// Save shared text to a collection.
  ///
  /// Returns the created [Item] on success, null on failure — the item is the
  /// exact Undo target for the Quick-Share Undo action (plan5 Sprint 0 §1.7).
  Future<Item?> saveToCollection({
    required String text,
    required String collectionId,
  }) async {
    try {
      final items = _storageService.getItemsForCollection(collectionId);
      final nextOrder = items.isEmpty
          ? 0
          : items.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;

      return await _storageService.createItem(
        collectionId: collectionId,
        text: text,
        order: nextOrder,
      );
    } catch (e) {
      return null;
    }
  }
}