import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/add_property_page.dart';
import 'screens/property_details_page.dart';
import 'screens/main_screen.dart';
import 'widgets/web_network_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Firestore rules require request.auth != null for writes; sign in
  // anonymously so screens like Add Property keep working without a login UI.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TerabiApp());
}

// ─────────────────────────────────────────
// App Colors & Theme
// ─────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF1A5F7A);      // أزرق بترولي فاخر
  static const Color primaryDark = Color(0xFF0D3D52);  // أزرق داكن
  static const Color accent = Color(0xFFD4A843);       // ذهبي رملي
  static const Color accentLight = Color(0xFFF0D080);  // ذهبي فاتح
  static const Color background = Color(0xFFF4F6F9);   // خلفية رمادية فاتحة
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2A3A);
  static const Color textSecondary = Color(0xFF6B7C8E);
  static const Color textHint = Color(0xFFAABBCC);
  static const Color success = Color(0xFF27AE60);
  static const Color cardShadow = Color(0x1A1A5F7A);
  static const Color chipSelected = Color(0xFF1A5F7A);
  static const Color chipUnselected = Color(0xFFECF2F7);
}

// ─────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────
enum PropertyType { all, land, apartment, villa, commercial }

extension PropertyTypeLabel on PropertyType {
  String get label {
    switch (this) {
      case PropertyType.all: return 'الكل';
      case PropertyType.land: return 'أراضي';
      case PropertyType.apartment: return 'شقق';
      case PropertyType.villa: return 'فلل';
      case PropertyType.commercial: return 'تجاري';
    }
  }

  IconData get icon {
    switch (this) {
      case PropertyType.all: return Icons.grid_view_rounded;
      case PropertyType.land: return Icons.landscape_rounded;
      case PropertyType.apartment: return Icons.apartment_rounded;
      case PropertyType.villa: return Icons.villa_rounded;
      case PropertyType.commercial: return Icons.store_rounded;
    }
  }
}

class Property {
  final String id;
  final String title;
  final String location;
  final String city;
  final String neighborhood;
  final double price;
  final double area;
  final PropertyType type;
  final String deed; // نوع السند
  final String phone;
  final List<Color> gradientColors;
  final IconData icon;
  final bool isFeatured;
  final String? description;
  final int? bedrooms;
  final int? bathrooms;
  final List<String> imageUrls; // روابط الصور من Firebase Storage

  const Property({
    required this.id,
    required this.title,
    required this.location,
    required this.city,
    required this.neighborhood,
    required this.price,
    required this.area,
    required this.type,
    required this.deed,
    required this.phone,
    required this.gradientColors,
    required this.icon,
    this.isFeatured = false,
    this.description,
    this.bedrooms,
    this.bathrooms,
    this.imageUrls = const [],
  });
}

// ─────────────────────────────────────────
// Mock Data
// ─────────────────────────────────────────
final ValueNotifier<Set<String>> favoriteIdsNotifier = ValueNotifier({});
void toggleFavorite(String id) {
  final set = Set<String>.from(favoriteIdsNotifier.value);
  if (set.contains(id)) set.remove(id);
  else set.add(id);
  favoriteIdsNotifier.value = set;
}

final List<Property> mockProperties = [
  Property(
    id: '1',
    title: 'أرض سكنية في تفرغ زينه',
    location: 'تفرغ زينه، نواكشوط',
    city: 'نواكشوط',
    neighborhood: 'تفرغ زينه',
    price: 4500000,
    area: 400,
    type: PropertyType.land,
    deed: 'تيتر فونسيي (Titre Foncier)',
    phone: '+22222345678',
    gradientColors: [Color(0xFF1A5F7A), Color(0xFF2E8B5E)],
    icon: Icons.landscape_rounded,
    isFeatured: true,
    description:
        'أرض سكنية مميزة في حي تفرغ زينه الراقي، مسجلة بسند ملكية رسمي. تقع في منطقة هادئة وقريبة من جميع الخدمات، مناسبة لبناء فيلا عائلية فاخرة.',
  ),
  Property(
    id: '2',
    title: 'شقة فاخرة في دار النعيم',
    location: 'دار النعيم، نواكشوط',
    city: 'نواكشوط',
    neighborhood: 'دار النعيم',
    price: 6200000,
    area: 120,
    type: PropertyType.apartment,
    deed: 'رخصة إشغال (Permis d\'occuper)',
    phone: '+22233456789',
    gradientColors: [Color(0xFFD4A843), Color(0xFFC0392B)],
    icon: Icons.apartment_rounded,
    bedrooms: 3,
    bathrooms: 2,
    isFeatured: false,
    description:
        'شقة حديثة ومجهزة بالكامل في قلب نواكشوط، الطابق الثالث مع إطلالة رائعة. تشمل مطبخاً أمريكياً وصالة واسعة وثلاث غرف نوم فسيحة.',
  ),
  Property(
    id: '3',
    title: 'فيلا فاخرة في لكصر',
    location: 'لكصر، نواكشوط',
    city: 'نواكشوط',
    neighborhood: 'لكصر',
    price: 28000000,
    area: 600,
    type: PropertyType.villa,
    deed: 'تيتر فونسيي (Titre Foncier)',
    phone: '+22244567890',
    gradientColors: [Color(0xFF6C3483), Color(0xFF1A5F7A)],
    icon: Icons.villa_rounded,
    bedrooms: 5,
    bathrooms: 4,
    isFeatured: true,
    description:
        'فيلا استثنائية بتصميم عصري في حي لكصر الأرستقراطي، محاطة بحديقة غناء. تحتوي على خمس غرف نوم فاخرة، مسبح خاص، وجراج لثلاث سيارات.',
  ),
  Property(
    id: '4',
    title: 'أرض زراعية في نواذيبو',
    location: 'نواذيبو',
    city: 'نواذيبو',
    neighborhood: 'المدينة',
    price: 1800000,
    area: 2000,
    type: PropertyType.land,
    deed: 'رخصة إشغال (Permis d\'occuper)',
    phone: '+22255678901',
    gradientColors: [Color(0xFF27AE60), Color(0xFF1E8449)],
    icon: Icons.grass_rounded,
    isFeatured: false,
    description:
        'أرض شاسعة ذات مواصفات زراعية ممتازة في ضواحي نواذيبو، مع إمكانية الوصول للمياه الجوفية. مثالية للاستثمار الزراعي أو مشاريع الإنتاج الغذائي.',
  ),
  Property(
    id: '5',
    title: 'محل تجاري في السوق المركزي',
    location: 'السوق المركزي، نواكشوط',
    city: 'نواكشوط',
    neighborhood: 'السوق المركزي',
    price: 9500000,
    area: 80,
    type: PropertyType.commercial,
    deed: 'تيتر فونسيي (Titre Foncier)',
    phone: '+22266789012',
    gradientColors: [Color(0xFFE67E22), Color(0xFFD4A843)],
    icon: Icons.store_rounded,
    isFeatured: false,
    description:
        'محل تجاري استراتيجي في قلب السوق المركزي بنواكشوط، في منطقة تجارية عالية الكثافة. مناسب للمتاجر والمكاتب والمطاعم.',
  ),
  Property(
    id: '6',
    title: 'شقة بغرفتين في ريياض',
    location: 'الرياض، نواكشوط',
    city: 'نواكشوط',
    neighborhood: 'الرياض',
    price: 3800000,
    area: 85,
    type: PropertyType.apartment,
    deed: 'رخصة إشغال (Permis d\'occuper)',
    phone: '+22277890123',
    gradientColors: [Color(0xFF2980B9), Color(0xFF1ABC9C)],
    icon: Icons.apartment_rounded,
    bedrooms: 2,
    bathrooms: 1,
    isFeatured: false,
    description:
        'شقة أنيقة في حي الرياض الهادئ، بتشطيبات عالية الجودة ونوافذ واسعة تسمح بتهوية جيدة. قريبة من المدارس والمرافق الصحية.',
  ),
  Property(
    id: '7',
    title: 'أرض للبيع في الحي الثامن',
    location: 'الحي الثامن، نواكشوط',
    city: 'نواكشوط',
    neighborhood: 'الحي الثامن',
    price: 2200000,
    area: 300,
    type: PropertyType.land,
    deed: 'رخصة إشغال (Permis d\'occuper)',
    phone: '+22288901234',
    gradientColors: [Color(0xFF8E44AD), Color(0xFF2C3E50)],
    icon: Icons.landscape_rounded,
    isFeatured: false,
    description:
        'قطعة أرض بموقع ممتاز في الحي الثامن بنواكشوط، جاهزة للبناء الفوري. محاطة بالخدمات الأساسية والطرق المعبدة.',
  ),
  Property(
    id: '8',
    title: 'فيلا مع بستان في أطار',
    location: 'أطار، آدرار',
    city: 'أطار',
    neighborhood: 'المدينة',
    price: 12000000,
    area: 800,
    type: PropertyType.villa,
    deed: 'تيتر فونسيي (Titre Foncier)',
    phone: '+22299012345',
    gradientColors: [Color(0xFF16A085), Color(0xFF27AE60)],
    icon: Icons.villa_rounded,
    bedrooms: 4,
    bathrooms: 3,
    isFeatured: true,
    description:
        'فيلا ريفية ساحرة في مدينة أطار التاريخية، محاطة ببستان نخيل وأشجار فواكه. تجمع بين الأصالة الموريتانية والرفاهية الحديثة.',
  ),
];

// ─────────────────────────────────────────
// Root App Widget
// ─────────────────────────────────────────
class TerabiApp extends StatelessWidget {
  const TerabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ترابي - عقارات موريتانيا',
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
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
      home: const MainScreen(),
    );
  }
}

// ─────────────────────────────────────────
// Home Page
// ─────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  PropertyType _selectedType = PropertyType.all;
  String _searchQuery = '';
  String? _selectedCity;
  // null means "no price/area filter applied yet" — the sliders in the
  // filter sheet only become an active constraint once the user explicitly
  // applies them, so the default view shows every property instead of
  // silently hiding listings outside an arbitrary default range.
  RangeValues? _priceRange;
  RangeValues? _areaRange;
  late AnimationController _headerAnimCtrl;
  late Animation<double> _headerFadeAnim;

  // ── Live Firestore stream ──
  late final Stream<QuerySnapshot> _propertiesStream;

  @override
  void initState() {
    super.initState();
    // Create the stream here — AFTER Firebase.initializeApp() has run in main().
    // Using FirebaseFirestore.instance directly avoids the circular-import
    // issue that previously caused a null crash on the web.
    _propertiesStream = FirebaseFirestore.instance
        .collection('properties')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _headerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimCtrl,
      curve: Curves.easeOut,
    );
    _headerAnimCtrl.forward();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerAnimCtrl.dispose();
    super.dispose();
  }

  /// Convert a Firestore QuerySnapshot into a filtered list of [Property].
  List<Property> _applyFilters(List<Property> all) {
    return all.where((p) {
      final matchType = _selectedType == PropertyType.all || p.type == _selectedType;
      final matchSearch = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery) ||
          p.location.toLowerCase().contains(_searchQuery) ||
          p.city.toLowerCase().contains(_searchQuery) ||
          p.neighborhood.toLowerCase().contains(_searchQuery);
      final matchCity = _selectedCity == null || p.city == _selectedCity;
      final matchPrice = _priceRange == null ||
          (p.price >= _priceRange!.start && p.price <= _priceRange!.end);
      final matchArea = _areaRange == null ||
          (p.area >= _areaRange!.start && p.area <= _areaRange!.end);
      return matchType && matchSearch && matchCity && matchPrice && matchArea;
    }).toList();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        selectedCity: _selectedCity,
        priceRange: _priceRange ?? const RangeValues(0, 30000000),
        areaRange: _areaRange ?? const RangeValues(0, 3000),
        onApply: (city, price, area) {
          setState(() {
            _selectedCity = city;
            _priceRange = price;
            _areaRange = area;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _propertiesStream,
      builder: (context, snapshot) {
        // ── Derive the live property list from Firestore ──
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'تعذّر تحميل البيانات',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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

        final List<Property> allProperties = snapshot.hasData
            ? snapshot.data!.docs
                .map<Property>(_propertyFromDoc)
                .toList()
            : [];

        final filtered = _applyFilters(allProperties);
        final featured = allProperties.where((p) => p.isFeatured).toList();
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Sliver App Bar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeroHeader(allProperties.length),
                ),
              ),

              // ── Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildSearchBar(),
                ),
              ),

              // ── Filter Chips
              SliverToBoxAdapter(
                child: _buildFilterChips(),
              ),

              // ── Loading indicator
              if (isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                )
              else ...[
                // ── Featured Section
                if (featured.isNotEmpty) ...[
                  _buildSectionHeader('المميزة', Icons.star_rounded),
                  SliverToBoxAdapter(
                    child: _buildFeaturedCarousel(featured),
                  ),
                ],

                // ── All Properties Section
                _buildSectionHeader('جميع العقارات (${filtered.length})', Icons.home_work_rounded),

                // ── Property List
                if (filtered.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => PropertyCard(
                          property: filtered[i],
                          index: i,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Add Property FAB
              FloatingActionButton(
                heroTag: 'addPropertyFab',
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 450),
                      pageBuilder: (_, anim, secondAnim) {
                        final curvedAnim = CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        );
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(curvedAnim),
                          child: const AddPropertyPage(),
                        );
                      },
                    ),
                  );

                  // The StreamBuilder auto-refreshes when Firestore updates.
                  // We only need to show the success snackbar here.
                  if (result is Property && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('تم نشر إعلانك بنجاح!'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.add_home_rounded, size: 26),
              ),
              const SizedBox(height: 12),
              // ── Filter FAB
              FloatingActionButton.extended(
                heroTag: 'filterFab',
                onPressed: _openFilterSheet,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text(
                  'فلترة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Hero Header
  Widget _buildHeroHeader(int count) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF155F3E)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            left: -40,
            child: _DecorativeCircle(size: 160, opacity: 0.08),
          ),
          Positioned(
            bottom: -20,
            right: 40,
            child: _DecorativeCircle(size: 100, opacity: 0.06),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: FadeTransition(
                opacity: _headerFadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.accentLight,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'موريتانيا',
                                  style: TextStyle(
                                    color: AppColors.accentLight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ترابي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const Text(
                              'اعثر على عقارك المثالي',
                              style: TextStyle(
                                color: Color(0xFFB8D4E0),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        // Stats badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$count+',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'عقار',
                                style: TextStyle(
                                  color: Color(0xFFB8D4E0),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'ابحث عن عقار، حي، أو مدينة...',
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Filter Chips
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: PropertyType.values.map((type) {
          final selected = _selectedType == type;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FilterChip(
                selected: selected,
                avatar: Icon(
                  type.icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                label: Text(
                  type.label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                onSelected: (_) => setState(() => _selectedType = type),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                checkmarkColor: Colors.transparent,
                showCheckmark: false,
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: AppColors.textHint.withValues(alpha: 0.4)),
                elevation: selected ? 3 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Featured Carousel
  Widget _buildFeaturedCarousel(List<Property> featured) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: featured.length,
        itemBuilder: (context, i) {
          final p = featured[i];
          return GestureDetector(
            onTap: () => _openPropertyDetail(p),
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: p.gradientColors,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: p.gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative pattern
                  Positioned(
                    top: -15,
                    left: -15,
                    child: _DecorativeCircle(size: 80, opacity: 0.12),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -10,
                    child: _DecorativeCircle(size: 100, opacity: 0.10),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '⭐ مميز',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(p.icon, color: Colors.white.withValues(alpha: 0.8), size: 28),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    p.location,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatPrice(p.price),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
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

  // ── Empty State
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 56, color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'جرّب تعديل معايير البحث أو الفلاتر',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openPropertyDetail(Property property) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, anim, ___) => FadeTransition(
          opacity: anim,
          child: PropertyDetailPage(property: property),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)} مليون أوقية';
    }
    return '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} أوقية';
  }
}

// ─────────────────────────────────────────
// Firestore → Property converter
// ─────────────────────────────────────────
Property _propertyFromDoc(QueryDocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;

  PropertyType type;
  switch (data['type']) {
    case 'apartment':  type = PropertyType.apartment;  break;
    case 'villa':      type = PropertyType.villa;       break;
    case 'land':       type = PropertyType.land;        break;
    case 'commercial': type = PropertyType.commercial;  break;
    default:           type = PropertyType.apartment;
  }

  final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];

  return Property(
    id:            doc.id,
    title:         data['title']        ?? '',
    location:      data['location']     ?? '',
    city:          data['city']         ?? '',
    neighborhood:  data['neighborhood'] ?? '',
    price:         (data['price']  ?? 0).toDouble(),
    area:          (data['area']   ?? 0).toDouble(),
    type:          type,
    deed:          data['deed']    ?? 'Titre Foncier',
    phone:         data['phone']   ?? '',
    description:   data['description'],
    bedrooms:      data['bedrooms'],
    bathrooms:     data['bathrooms'],
    imageUrls:     imageUrls,
    isFeatured:    data['isFeatured'] ?? false,
    gradientColors: const [AppColors.primary, AppColors.accent],
    icon: type == PropertyType.land
        ? Icons.landscape_rounded
        : Icons.home_rounded,
  );
}

// ─────────────────────────────────────────
// Property Card Widget
// ─────────────────────────────────────────
class PropertyCard extends StatefulWidget {
  final Property property;
  final int index;

  const PropertyCard({super.key, required this.property, required this.index});

  @override
  State<PropertyCard> createState() => PropertyCardState();
}

class PropertyCardState extends State<PropertyCard> with SingleTickerProviderStateMixin {
  
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut),
    );
    Future.delayed(Duration(milliseconds: (80 * widget.index).toInt()), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;

    return ValueListenableBuilder<Set<String>>(valueListenable: favoriteIdsNotifier, builder: (context, favorites, _) { return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, anim, ___) => FadeTransition(
              opacity: anim,
              child: PropertyDetailPage(property: p),
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image / Gradient Header
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: p.imageUrls.isNotEmpty
                          ? WebNetworkImage(
                              url: p.imageUrls.first,
                              fit: BoxFit.cover,
                              placeholderBuilder: (context) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: p.gradientColors,
                                  ),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorBuilder: (context) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: p.gradientColors,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    p.icon,
                                    size: 64,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: p.gradientColors,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      p.icon,
                                      size: 64,
                                      color: Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  Positioned(
                                    top: -20,
                                    right: -20,
                                    child: _DecorativeCircle(size: 100, opacity: 0.12),
                                  ),
                                  Positioned(
                                    bottom: -30,
                                    left: 20,
                                    child: _DecorativeCircle(size: 80, opacity: 0.10),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  // Type badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p.type.label,
                        style: TextStyle(
                          color: p.gradientColors.first,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => toggleFavorite(widget.property.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: favoriteIdsNotifier.value.contains(widget.property.id)
                              ? Colors.red.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          favoriteIdsNotifier.value.contains(widget.property.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: favoriteIdsNotifier.value.contains(widget.property.id) ? Colors.white : Colors.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Details
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPrice(p.price),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.accent, size: 15),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.location,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.square_foot_rounded,
                          label: '${p.area.toInt()} م²',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        if (p.bedrooms != null)
                          _StatChip(
                            icon: Icons.bed_rounded,
                            label: '${p.bedrooms} غرف',
                            color: AppColors.accent,
                          ),
                        if (p.bedrooms != null) const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: AppColors.success, size: 13),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    p.deed.split('(').first.trim(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEEF2F7)),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.phone_rounded,
                            label: 'اتصال',
                            color: AppColors.primary,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.message_rounded,
                            label: 'واتساب',
                            color: const Color(0xFF25D366),
                            onTap: () {},
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
      ),
    );
    });
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}م أوقية';
    }
    return '${price.toStringAsFixed(0)} أوقية';
  }
}

// ─────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Filter Bottom Sheet
// ─────────────────────────────────────────
class FilterBottomSheet extends StatefulWidget {
  final String? selectedCity;
  final RangeValues priceRange;
  final RangeValues areaRange;
  final void Function(String? city, RangeValues price, RangeValues area) onApply;

  const FilterBottomSheet({
    super.key,
    this.selectedCity,
    required this.priceRange,
    required this.areaRange,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String? _selectedCity;
  late RangeValues _priceRange;
  late RangeValues _areaRange;

  final List<String> _cities = ['نواكشوط', 'نواذيبو', 'أطار', 'كيفه', 'روصو', 'زويرات'];

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.selectedCity;
    _priceRange = widget.priceRange;
    _areaRange = widget.areaRange;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE3EE),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'فلترة متقدمة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCity = null;
                              _priceRange = const RangeValues(0, 30000000);
                              _areaRange = const RangeValues(0, 3000);
                            });
                          },
                          child: const Text(
                            'إعادة ضبط',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── City Section
                    _SectionTitle(title: 'المدينة', icon: Icons.location_city_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _selectedCity = null),
                          child: _CityChip(label: 'الكل', selected: _selectedCity == null),
                        ),
                        ..._cities.map((city) => GestureDetector(
                              onTap: () => setState(() => _selectedCity = city),
                              child: _CityChip(label: city, selected: _selectedCity == city),
                            )),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Price Range
                    _SectionTitle(title: 'نطاق السعر (أوقية جديدة)', icon: Icons.attach_money_rounded),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatPrice(_priceRange.start),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _formatPrice(_priceRange.end),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: const Color(0xFFE0EAF2),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 30000000,
                        divisions: 60,
                        onChanged: (v) => setState(() => _priceRange = v),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Area Range
                    _SectionTitle(title: 'المساحة (م²)', icon: Icons.square_foot_rounded),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_areaRange.start.toInt()} م²',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_areaRange.end.toInt()} م²',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: const Color(0xFFF5E9C8),
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withValues(alpha: 0.15),
                        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: RangeSlider(
                        values: _areaRange,
                        min: 0,
                        max: 3000,
                        divisions: 30,
                        onChanged: (v) => setState(() => _areaRange = v),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onApply(_selectedCity, _priceRange, _areaRange);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        child: const Text(
                          'تطبيق الفلاتر',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}م';
    }
    return '${price.toInt()}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _CityChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : const Color(0xFFECF2F7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: selected
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Property Detail Page
// ─────────────────────────────────────────
