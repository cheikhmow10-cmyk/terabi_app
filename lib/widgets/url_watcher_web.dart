import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Fires whenever the browser URL changes without a full page reload —
/// back/forward navigation, or editing just the hash (which never reloads
/// the page per web spec, so it wouldn't otherwise be noticed).
Stream<void> watchUrlChanges() {
  final controller = StreamController<void>.broadcast();
  html.window.onPopState.listen((_) => controller.add(null));
  html.window.onHashChange.listen((_) => controller.add(null));
  return controller.stream;
}

/// The "logical" path for routing purposes: /admin via the default
/// hash-based URL (#/admin — what Flutter web uses unless you opt into
/// usePathUrlStrategy(), which we deliberately don't here — see main.dart),
/// with a plain-pathname fallback for a direct /admin request that reached
/// the server (matches the SPA rewrite rule in firebase.json).
///
/// Reads window.location directly rather than Uri.base: Uri.base did not
/// reliably reflect a same-page hash change (no reload) in testing.
/// Deliberately has no side effects (no history.replaceState) — a previous
/// version rewrote the URL here to "clean up" the hash, but that raced with
/// Flutter's own hash-strategy history handling and crashed it.
String currentPath() {
  final pathname = html.window.location.pathname ?? '/';
  if (pathname.isNotEmpty && pathname != '/') return pathname;
  final hash = html.window.location.hash; // e.g. "#/admin", or "" if none
  if (hash.isEmpty) return '/';
  final withoutHash = hash.startsWith('#') ? hash.substring(1) : hash;
  if (withoutHash.isEmpty) return '/';
  return withoutHash.startsWith('/') ? withoutHash : '/$withoutHash';
}
