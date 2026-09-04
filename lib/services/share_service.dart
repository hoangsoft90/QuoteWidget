import '../models/item_model.dart';
import '../services/storage_service.dart';

class ShareService {
  final StorageService _storageService;

  ShareService(this._storageService);

  /// Process incoming share text
  Future<ShareResult> processShareText(String text) async {
    try {
      if (text.isEmpty) {
        return ShareResult(
          success: false,
          message: 'No text content to save',
        );
      }

      // Check if it's a URL-only share
      if (_isUrlOnly(text)) {
        return ShareResult(
          success: false,
          message: 'URL received. Add a note about this link?',
          isUrlOnly: true,
          originalText: text,
        );
      }

      // Process plain text
      return ShareResult(
        success: true,
        message: 'Text ready to save',
        text: text,
      );
    } catch (e) {
      return ShareResult(
        success: false,
        message: 'Could not process shared content: $e',
      );
    }
  }

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

  /// Check if text is URL-only
  bool _isUrlOnly(String text) {
    final trimmed = text.trim();
    // Match URLs with or without protocol, including paths and query params
    final urlPattern = RegExp(
      r'^(https?:\/\/)?[\w-]+(\.[\w-]+)+([\/\w\-.~:?#@!$&\(\)*+,;=%]*)?$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(trimmed);
  }

  /// Get appropriate message for share result
  String getShareMessage(ShareResult result, String collectionName) {
    if (!result.success) {
      return result.message;
    }

    return 'Added to $collectionName';
  }
}

class ShareResult {
  final bool success;
  final String message;
  final String? text;
  final bool isUrlOnly;
  final String? originalText;

  ShareResult({
    required this.success,
    required this.message,
    this.text,
    this.isUrlOnly = false,
    this.originalText,
  });
}
