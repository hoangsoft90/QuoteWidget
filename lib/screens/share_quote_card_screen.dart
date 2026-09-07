import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// B3: renders the simple quote card — text + optional author + app name —
/// into a PNG. Pure ui.Canvas rendering (no widget tree) so it is
/// deterministic, works off the main isolate flow, and is directly testable.
/// The screen below previews the SAME layout and shares the SAME file.
Future<File> renderQuoteCardPng(
  String quoteText,
  String? author, {
  double scale = 3.0,
}) async {
  const width = 320.0;
  const height = 220.0;
  const padding = 24.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width * scale, height * scale);
  canvas.scale(scale);

  // Card background — the app's seed purple, rounded corners.
  final bgPaint = Paint()..color = const Color(0xFF6750A4);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(16),
    ),
    bgPaint,
  );

  // Quote text (wrapped, up to 6 lines).
  final quoteStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );
  final quoteSpan = TextSpan(text: quoteText, style: quoteStyle);
  final quotePainter = TextPainter(
    text: quoteSpan,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - padding * 2);
  quotePainter.paint(
    canvas,
    const Offset(padding, padding),
  );

  double y = padding + quotePainter.height;

  // Optional author line.
  if (author != null && author.isNotEmpty) {
    final authorPainter = TextPainter(
      text: TextSpan(
        text: '— $author',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - padding * 2);
    y += 16;
    authorPainter.paint(canvas, Offset(padding, y));
    y += authorPainter.height;
  }

  // App name, small, bottom-left corner.
  final appPainter = TextPainter(
    text: const TextSpan(
      text: 'Quote Widget',
      style: TextStyle(
        color: Color(0x99FFFFFF),
        fontSize: 11,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  appPainter.paint(
    canvas,
    Offset(padding, height - padding - appPainter.height),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
      size.width.round(), size.height.round());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  final dir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${dir.path}/quote-card-$timestamp.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

/// B3: share-quote-as-image screen. Preview shows the card template; the
/// share button renders the SAME template to a PNG and hands it to the
/// existing share_plus mechanism.
class ShareQuoteCardScreen extends StatefulWidget {
  final String quoteText;
  final String? author;

  const ShareQuoteCardScreen({
    super.key,
    required this.quoteText,
    this.author,
  });

  @override
  State<ShareQuoteCardScreen> createState() => _ShareQuoteCardScreenState();
}

class _ShareQuoteCardScreenState extends State<ShareQuoteCardScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await renderQuoteCardPng(widget.quoteText, widget.author);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: widget.quoteText,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share the image')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share as image'),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Share image',
            onPressed: _share,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6750A4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.quoteText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.author != null && widget.author!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '— ${widget.author}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Quote Widget',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
