import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'screens/admin_gate_page.dart';
import 'screens/product_details_page.dart';
import 'screens/cart_page.dart';
import 'screens/main_screen.dart';
import 'widgets/web_network_image.dart';
import 'widgets/url_watcher.dart';

void main() {
  // runZonedGuarded so an uncaught async error (e.g. from a browser
  // popstate/hashchange event handler, which runs outside Flutter's own
  // build-time error boundary) can't take down the whole render tree.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // No anonymous sign-in: storefront reads are public (see
    // firestore.rules), and the only write path — the admin dashboard —
    // requires a real FirebaseAuth email/password session (see
    // screens/admin_gate_page.dart).
    //
    // Deliberately NOT calling usePathUrlStrategy(): its engine-level
    // cleanup of URLs it doesn't recognize raced against and reverted our
    // own hash-based /admin detection (confirmed via debug logging — our
    // listener read the correct path, then a moment later an unrelated
    // internal cleanup event reset window.location back to '/'). Default
    // hash-based URLs (#/admin) have no such conflict and are handled by
    // url_watcher.dart.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    runApp(const VazaApp());
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}

// ─────────────────────────────────────────
// App Colors & Theme — black/charcoal + gold on off-white
// ─────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF1A1A1A);       // أسود فحمي
  static const Color primaryDark = Color(0xFF000000);   // أسود نقي
  static const Color accent = Color(0xFFC9A227);        // ذهبي فاخر
  static const Color accentLight = Color(0xFFE8D28A);   // ذهبي فاتح
  static const Color background = Color(0xFFF7F5F1);    // أبيض عاجي
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8A8680);
  static const Color textHint = Color(0xFFBEB9B0);
  static const Color success = Color(0xFF2E7D4F);
  static const Color cardShadow = Color(0x14000000);
  static const Color chipSelected = Color(0xFF1A1A1A);
  static const Color chipUnselected = Color(0xFFF0EDE6);
}

// ─────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────
enum ProductCategory { all, dracs, tshirts, pants, headwear, perfumes, shoes, essentials, personalCare }

extension ProductCategoryLabel on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.all: return 'الكل';
      case ProductCategory.dracs: return 'دراعات';
      case ProductCategory.tshirts: return 'تيشرتات';
      case ProductCategory.pants: return 'بناطيل';
      case ProductCategory.headwear: return 'قبعات';
      case ProductCategory.perfumes: return 'عطور';
      case ProductCategory.shoes: return 'أحذية';
      case ProductCategory.essentials: return 'ملابس أساسية';
      case ProductCategory.personalCare: return 'العناية الشخصية';
    }
  }

  FaIconData get icon {
    switch (this) {
      case ProductCategory.all: return FaIconData(Icons.grid_view_rounded);
      // Traditional robe/thobe: no dedicated Font Awesome icon exists, but
      // "vest" (a full sleeveless outer garment) is the closest fit.
      case ProductCategory.dracs: return FontAwesomeIcons.vest;
      case ProductCategory.tshirts: return FontAwesomeIcons.shirt;
      // Font Awesome's free set has no dedicated pants/trousers icon; a
      // plain clothing hanger is the least misleading fallback available.
      case ProductCategory.pants: return FaIconData(Icons.checkroom_outlined);
      case ProductCategory.headwear: return FontAwesomeIcons.hatCowboy;
      case ProductCategory.perfumes: return FontAwesomeIcons.sprayCanSparkles;
      case ProductCategory.shoes: return FontAwesomeIcons.shoePrints;
      case ProductCategory.essentials: return FaIconData(Icons.inventory_2_rounded);
      case ProductCategory.personalCare: return FaIconData(Icons.soap_rounded);
    }
  }
}

class Product {
  final String id;
  final String title;
  final double price;
  final ProductCategory category;
  final String phone;
  final bool isLuxury;
  final String? description;
  final List<String> sizes;
  final List<String> imageUrls;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.phone,
    this.isLuxury = false,
    this.description,
    this.sizes = const [],
    this.imageUrls = const [],
  });
}

/// Formats an MRU price for display — shared by the grid, details, cart,
/// and add-product screens (previously duplicated in three places).
String formatPrice(double price) {
  if (price >= 1000000) {
    final m = price / 1000000;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)} مليون أوقية';
  }
  return '${price.toStringAsFixed(0)} أوقية';
}

// ─────────────────────────────────────────
// Favorites (wishlist)
// ─────────────────────────────────────────
final ValueNotifier<Set<String>> favoriteIdsNotifier = ValueNotifier({});
void toggleFavorite(String id) {
  final set = Set<String>.from(favoriteIdsNotifier.value);
  if (set.contains(id)) {
    set.remove(id);
  } else {
    set.add(id);
  }
  favoriteIdsNotifier.value = set;
}

// ─────────────────────────────────────────
// Cart — in-memory only (cart key → quantity), checkout is via WhatsApp.
// The cart key encodes the product id plus the selected size (if the
// product has sizes) so "T-shirt / M" and "T-shirt / L" are separate lines.
// ─────────────────────────────────────────
final ValueNotifier<Map<String, int>> cartNotifier = ValueNotifier({});

const String _cartKeySeparator = '::';

String cartKey(String productId, [String? size]) {
  if (size == null || size.isEmpty) return productId;
  return '$productId$_cartKeySeparator$size';
}

({String productId, String? size}) parseCartKey(String key) {
  final i = key.indexOf(_cartKeySeparator);
  if (i == -1) return (productId: key, size: null);
  return (productId: key.substring(0, i), size: key.substring(i + _cartKeySeparator.length));
}

void addToCart(String productId, {String? size}) {
  final key = cartKey(productId, size);
  final map = Map<String, int>.from(cartNotifier.value);
  map[key] = (map[key] ?? 0) + 1;
  cartNotifier.value = map;
}

void removeFromCart(String cartLineKey) {
  final map = Map<String, int>.from(cartNotifier.value);
  map.remove(cartLineKey);
  cartNotifier.value = map;
}

void setCartQuantity(String cartLineKey, int quantity) {
  final map = Map<String, int>.from(cartNotifier.value);
  if (quantity <= 0) {
    map.remove(cartLineKey);
  } else {
    map[cartLineKey] = quantity;
  }
  cartNotifier.value = map;
}

void clearCart() {
  cartNotifier.value = {};
}

void _showAddedToCartSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('تمت الإضافة إلى السلة'),
      duration: const Duration(milliseconds: 900),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

/// Adds [p] to the cart. If it has sizes, prompts for one via a bottom sheet
/// first — the cart needs a size per line so checkout can list it.
void quickAddToCart(BuildContext context, Product p) {
  if (p.sizes.isEmpty) {
    addToCart(p.id);
    _showAddedToCartSnackBar(context);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE8E5DF), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('اختر المقاس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.sizes
                  .map(
                    (s) => GestureDetector(
                      onTap: () {
                        addToCart(p.id, size: s);
                        Navigator.pop(sheetContext);
                        _showAddedToCartSnackBar(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFFF3F1EC), borderRadius: BorderRadius.circular(12)),
                        child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────
// Root App Widget
// ─────────────────────────────────────────
class VazaApp extends StatefulWidget {
  const VazaApp({super.key});

  @override
  State<VazaApp> createState() => _VazaAppState();
}

class _VazaAppState extends State<VazaApp> {
  late String _path;
  StreamSubscription<void>? _urlSub;

  @override
  void initState() {
    super.initState();
    _path = currentPath();
    // MaterialApp's initialRoute is only read once at boot — it doesn't
    // react to the browser URL changing afterwards (e.g. editing just the
    // hash, which never triggers a page reload). Watch for that directly so
    // navigating to /admin actually shows the admin gate without a reload.
    _urlSub = watchUrlChanges().listen((_) {
      final next = currentPath();
      if (next != _path && mounted) setState(() => _path = next);
    });
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAZA | فازا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'MR'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          selectedColor: AppColors.chipSelected,
          backgroundColor: AppColors.chipUnselected,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          labelLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: _path.startsWith('/admin') ? const AdminGatePage() : const MainScreen(),
    );
  }
}

// ─────────────────────────────────────────
// Promo banners — static/decorative, not Firestore-backed
// ─────────────────────────────────────────
class _PromoBanner {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });
}

const List<_PromoBanner> _promoBanners = [
  _PromoBanner(
    title: 'تشكيلة الدراعات الفاخرة',
    subtitle: 'أناقة موريتانية أصيلة',
    colors: [Color(0xFF1A1A1A), Color(0xFF3A3A3A)],
    icon: Icons.checkroom_rounded,
  ),
  _PromoBanner(
    title: 'عطور أصلية 100%',
    subtitle: 'اكتشف رائحتك المميزة',
    colors: [Color(0xFF2B2417), Color(0xFFC9A227)],
    icon: Icons.spa_rounded,
  ),
  _PromoBanner(
    title: 'أحذية عصرية',
    subtitle: 'لكل مناسبة ولمسة أناقة',
    colors: [Color(0xFF1A1A1A), Color(0xFF4A4A4A)],
    icon: Icons.directions_walk_rounded,
  ),
];

// ─────────────────────────────────────────
// Home Page
// ─────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  ProductCategory _selectedCategory = ProductCategory.all;
  String _searchQuery = '';
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;

  // ── Live Firestore stream ──
  late final Stream<QuerySnapshot> _productsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _promoBanners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  /// Convert a Firestore QuerySnapshot into a filtered list of [Product].
  List<Product> _applyFilters(List<Product> all) {
    return all.where((p) {
      final matchCategory =
          _selectedCategory == ProductCategory.all || p.category == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty || p.title.toLowerCase().contains(_searchQuery);
      return matchCategory && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذّر تحميل البيانات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final List<Product> allProducts = snapshot.hasData
            ? snapshot.data!.docs.map<Product>(productFromDoc).toList()
            : [];

        final filtered = _applyFilters(allProducts);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                toolbarHeight: 64,
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: false,
                title: const Text(
                  'VAZA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.textPrimary),
                ),
                actions: [
                  _buildCartIcon(context),
                  const SizedBox(width: 8),
                ],
              ),

              // ── Smart Search Bar
              SliverToBoxAdapter(child: _buildSearchBar()),

              // ── Promo Banner Carousel
              SliverToBoxAdapter(child: _buildBannerCarousel()),

              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // ── Circular Category Row
              SliverToBoxAdapter(child: _buildCategoryCircles()),

              _buildSectionHeader('أحدث المنتجات', Icons.auto_awesome_rounded),

              // ── Loading indicator
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                    ),
                  ),
                )
              // ── Empty state
              else if (filtered.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              // ── Product Grid
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(product: filtered[index], index: index),
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        );
      },
    );
  }

  // ── Cart Icon w/ Badge
  Widget _buildCartIcon(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: cartNotifier,
      builder: (context, cart, _) {
        final count = cart.values.fold<int>(0, (a, b) => a + b);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined),
              color: AppColors.textPrimary,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartPage()),
              ),
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Smart Search Bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEEEAE1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'ابحث عن دراعة، عطر، حذاء...',
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Promo Banner Carousel
  Widget _buildBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _promoBanners.length,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemBuilder: (context, i) {
              final banner = _promoBanners[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: banner.colors,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    const Positioned(bottom: -20, left: -20, child: _DecorativeCircle(size: 100, opacity: 0.08)),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                banner.title,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                banner.subtitle,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'تسوق الآن',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(banner.icon, size: 56, color: Colors.white.withValues(alpha: 0.25)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promoBanners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _bannerIndex == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _bannerIndex == i ? AppColors.primary : AppColors.chipUnselected,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Circular Category Row
  Widget _buildCategoryCircles() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: ProductCategory.values.map((cat) {
          final selected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.primary : const Color(0xFFE8E5DF),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: FaIcon(cat.icon, color: selected ? Colors.white : AppColors.textPrimary, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Section Header
  SliverToBoxAdapter _buildSectionHeader(String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded, size: 56, color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد منتجات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'جرّب تعديل كلمات البحث أو التصنيف',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Firestore document → Product
// ─────────────────────────────────────────
Product productFromDoc(QueryDocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;

  ProductCategory category;
  switch (data['category']) {
    case 'dracs': category = ProductCategory.dracs; break;
    case 'tshirts': category = ProductCategory.tshirts; break;
    case 'pants': category = ProductCategory.pants; break;
    case 'headwear': category = ProductCategory.headwear; break;
    case 'perfumes': category = ProductCategory.perfumes; break;
    case 'shoes': category = ProductCategory.shoes; break;
    case 'essentials': category = ProductCategory.essentials; break;
    case 'personalCare': category = ProductCategory.personalCare; break;
    default: category = ProductCategory.dracs;
  }

  final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
  final sizes = (data['sizes'] as List?)?.cast<String>() ?? [];

  return Product(
    id: doc.id,
    title: data['title'] ?? '',
    price: (data['price'] ?? 0).toDouble(),
    category: category,
    phone: data['phone'] ?? '',
    description: data['description'],
    sizes: sizes,
    imageUrls: imageUrls,
    isLuxury: data['isLuxury'] ?? false,
  );
}

// ─────────────────────────────────────────
// Product Card Widget
// ─────────────────────────────────────────
class ProductCard extends StatefulWidget {
  final Product product;
  final int index;

  const ProductCard({super.key, required this.product, required this.index});

  @override
  State<ProductCard> createState() => ProductCardState();
}

class ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: 60 * (widget.index % 10)), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _placeholder(Product p) {
    return Container(
      color: AppColors.chipUnselected,
      child: Center(child: FaIcon(p.category.icon, size: 40, color: AppColors.textHint)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return ScaleTransition(
      scale: _scaleAnim,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: favoriteIdsNotifier,
        builder: (context, favorites, _) {
          final isFav = favorites.contains(p.id);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (_, anim, _) => FadeTransition(
                  opacity: anim,
                  child: ProductDetailPage(product: p),
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: AppColors.cardShadow, blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: p.imageUrls.isNotEmpty
                            ? WebNetworkImage(
                                url: p.imageUrls.first,
                                fit: BoxFit.cover,
                                placeholderBuilder: (context) => _placeholder(p),
                                errorBuilder: (context) => _placeholder(p),
                              )
                            : _placeholder(p),
                      ),
                      if (p.isLuxury)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                            child: const Text(
                              'فاخر',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => toggleFavorite(p.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? Colors.red : AppColors.textSecondary,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                formatPrice(p.price),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => quickAddToCart(context, p),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 15),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Shared decorative widget
// ─────────────────────────────────────────
class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }
}
