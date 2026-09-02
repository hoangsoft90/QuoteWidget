import 'package:flutter/material.dart';
import '../models/widget_config_model.dart';

/// A card widget that displays a quote with configurable appearance.
/// Used in the app to preview how quotes will look on the home screen.
class QuoteCard extends StatelessWidget {
  final String text;
  final AppearanceConfig appearance;
  final SizeCategory sizeCategory;
  final int? index;
  final int? total;
  final VoidCallback? onTap;

  const QuoteCard({
    super.key,
    required this.text,
    required this.appearance,
    this.sizeCategory = SizeCategory.small,
    this.index,
    this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: sizeCategory == SizeCategory.small ? 110 : 250,
        height: 110,
        decoration: BoxDecoration(
          color: Color(appearance.background),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: _getAlignment(appearance.alignment),
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: appearance.fontSize,
                  color: Color(appearance.textColor),
                  height: 1.2,
                ),
                textAlign: _getTextAlign(appearance.alignment),
                maxLines: sizeCategory == SizeCategory.small ? 3 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (index != null && total != null && total! > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${index! + 1}/$total',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(appearance.textColor).withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
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
