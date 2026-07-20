/// Non-web fallback — there's no browser URL bar, so there's nothing to
/// watch and no route other than the storefront.
Stream<void> watchUrlChanges() => const Stream<void>.empty();

String currentPath() => '/';
