import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class ThermalCameraFeed extends StatefulWidget {
  const ThermalCameraFeed({super.key, required this.streamUrl});

  final String streamUrl;

  @override
  State<ThermalCameraFeed> createState() => _ThermalCameraFeedState();
}

class _ThermalCameraFeedState extends State<ThermalCameraFeed> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'moashir-thermal-feed-${DateTime.now().microsecondsSinceEpoch}';
    final source = _feedUrl(widget.streamUrl);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return web.HTMLIFrameElement()
        ..src = source
        ..loading = 'eager'
        ..style.border = '0'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('title', "MO'ASHIR thermal camera feed");
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: HtmlElementView(viewType: _viewType));
  }
}

String _feedUrl(String streamUrl) {
  final trimmed = streamUrl.trim();
  if (trimmed.endsWith('/video_feed')) return trimmed;
  return '${trimmed.replaceFirst(RegExp(r'/$'), '')}/video_feed';
}
