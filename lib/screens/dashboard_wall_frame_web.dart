import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class PhoneAppFrame extends StatefulWidget {
  const PhoneAppFrame({
    super.key,
    required this.role,
  });

  final String role;

  @override
  State<PhoneAppFrame> createState() => _PhoneAppFrameState();
}

class _PhoneAppFrameState extends State<PhoneAppFrame> {
  late final String _viewType;
  late final String _frameId;

  @override
  void initState() {
    super.initState();
    _frameId = DateTime.now().microsecondsSinceEpoch.toString();
    _viewType = 'moashir-phone-${widget.role}-$_frameId';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final source = Uri.base.replace(
        queryParameters: {
          ...Uri.base.queryParameters,
          'moashirEmbeddedRole': widget.role,
          'moashirFrame': _frameId,
        },
        fragment: '',
      ).toString();

      return web.HTMLIFrameElement()
        ..src = source
        ..loading = 'eager'
        ..style.border = '0'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('allow', 'camera; microphone; geolocation')
        ..setAttribute('title', "Mo'Ashir ${widget.role} app");
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: HtmlElementView(viewType: _viewType));
  }
}
