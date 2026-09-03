import 'package:flutter/material.dart';
import '../models/widget_config_model.dart';
import '../models/collection_model.dart';
import '../models/widget_theme.dart';
import '../services/storage_service.dart';

class WidgetPreview extends StatefulWidget {
  final WidgetConfig config;
  final Collection? collection;
  final StorageService storageService;

  const WidgetPreview({
    super.key,
    required this.config,
    this.collection,
    required this.storageService,
  });

  @override
  State<WidgetPreview> createState() => _WidgetPreviewState();
}

class _WidgetPreviewState extends State<WidgetPreview> {
  @override
  Widget build(BuildContext context) {
    final items = widget.collection != null
        ? widget.storageService.getItemsForCollection(widget.collection!.id)
        : <dynamic>[];

    String text;
    if (widget.collection == null) {
      text = 'Select a collection to preview';
    } else if (items.isEmpty) {
      text = 'Add some content to this collection.';
    } else {
      final index = widget.config.currentIndex.clamp(0, items.length - 1);
      text = items[index].text;
    }

    final size = widget.config.sizeCategory == SizeCategory.small
        ? const Size(110, 110)
        : const Size(250, 110);

    // Curated theme → mirror the native gradient drawable in the preview.
    final curated = curatedThemeById(widget.config.appearance.theme);
    final BoxDecoration decoration;
    if (curated != null) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(curated.backgroundColor),
            Color(curated.gradientEnd),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: Color(widget.config.appearance.background),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    return Container(
      width: size.width,
      height: size.height,
      decoration: decoration,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: _getAlignment(widget.config.appearance.alignment),
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: widget.config.appearance.fontSize,
                color: Color(widget.config.appearance.textColor),
                height: 1.2,
              ),
              textAlign: _getTextAlign(widget.config.appearance.alignment),
              maxLines: widget.config.sizeCategory == SizeCategory.small ? 3 : 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  CrossAxisAlignment _getAlignment(TextAlignment alignment) {
    switch (alignment) {
      case TextAlignment.left:
        return CrossAxisAlignment.start;
      case TextAlignment.center:
        return CrossAxisAlignment.center;
      case TextAlignment.right:
        return CrossAxisAlignment.end;
    }
  }

  TextAlign _getTextAlign(TextAlignment alignment) {
    switch (alignment) {
      case TextAlignment.left:
        return TextAlign.left;
      case TextAlignment.center:
        return TextAlign.center;
      case TextAlignment.right:
        return TextAlign.right;
    }
  }
}
