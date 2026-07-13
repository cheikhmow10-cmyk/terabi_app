// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Displays a network image through a native `<img>` DOM element instead of
/// [Image.network]/CanvasKit.
///
/// CanvasKit renders by uploading images as WebGL textures, which the
/// browser refuses to do for cross-origin images unless the server sends
/// `Access-Control-Allow-Origin` (ImgBB's CDN doesn't) — the texture upload
/// silently fails and nothing gets drawn. A plain `<img>` tag has no such
/// restriction: the browser has always been able to *display* cross-origin
/// images, it only blocks *reading pixels back* (canvas/WebGL), which an
/// `<img>` composited via [HtmlElementView] never needs to do.
class WebNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;
  final WidgetBuilder? errorBuilder;

  const WebNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  State<WebNetworkImage> createState() => _WebNetworkImageState();
}

enum _LoadState { loading, loaded, error }

class _WebNetworkImageState extends State<WebNetworkImage> {
  late String _viewType;
  _LoadState _state = _LoadState.loading;

  static String _objectFitFor(BoxFit fit) {
    switch (fit) {
      case BoxFit.fill: return 'fill';
      case BoxFit.contain: return 'contain';
      case BoxFit.cover: return 'cover';
      case BoxFit.fitWidth: return 'cover';
      case BoxFit.fitHeight: return 'cover';
      case BoxFit.none: return 'none';
      case BoxFit.scaleDown: return 'scale-down';
    }
  }

  @override
  void initState() {
    super.initState();
    _registerImage();
  }

  @override
  void didUpdateWidget(covariant WebNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _state = _LoadState.loading;
      _registerImage();
    }
  }

  void _registerImage() {
    _viewType =
        'web-network-image-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    final img = html.ImageElement()
      ..src = widget.url
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _objectFitFor(widget.fit)
      ..style.border = 'none';

    img.onLoad.first.then((_) {
      if (mounted) setState(() => _state = _LoadState.loaded);
    });
    img.onError.first.then((_) {
      if (mounted) setState(() => _state = _LoadState.error);
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => img);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink();
      case _LoadState.error:
        return widget.errorBuilder?.call(context) ?? const SizedBox.shrink();
      case _LoadState.loaded:
        return HtmlElementView(viewType: _viewType);
    }
  }
}
