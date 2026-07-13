import 'package:flutter/material.dart';

/// Non-web fallback for [WebNetworkImage]: plain [Image.network] is fine on
/// iOS/Android/desktop since only CanvasKit-on-web has the CORS texture
/// restriction that the DOM-based implementation works around.
class WebNetworkImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholderBuilder?.call(context) ?? const SizedBox.shrink();
      },
      errorBuilder: (context, error, stack) =>
          errorBuilder?.call(context) ?? const SizedBox.shrink(),
    );
  }
}
