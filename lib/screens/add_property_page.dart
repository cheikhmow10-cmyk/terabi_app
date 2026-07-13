import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // includes Uint8List
import 'package:image_picker/image_picker.dart';
import '../main.dart' show AppColors, PropertyType, PropertyTypeLabel, Property;
import '../services/firebase_service.dart';

// ─────────────────────────────────────────
// Mauritanian Location Data
// ─────────────────────────────────────────
const Map<String, List<String>> mauritaniaCities = {
  'نواكشوط': [
    'عرفات',
    'دار النعيم',
    'المينه',
    'لكصر',
    'الرياض',
    'سبخة',
    'تفرغ زينه',
    'توجنين',
    'تيارت',
  ],
  'نواذيبو': ['المدينة', 'الشمال', 'البحيرة'],
  'أطار': ['المدينة الداخلية', 'ضاحية أطار'],
  'كيفه': ['المدينة القديمة', 'الحي الجديد'],
  'روصو': ['مركز روصو', 'الجانب الشرقي'],
  'زويرات': ['الحي العمالي', 'الوسط'],
  'ألاك': ['مركز ألاك'],
};

const Map<String, List<String>> moughataQuartiers = {
  'تفرغ زينه': ['حي الرياض', 'حي النزهة', 'الحي الدبلوماسي', 'حي الجامعة', 'المنطقة الإدارية'],
  'لكصر': ['الحي التجاري', 'حي الإدارة', 'المركز', 'الحي الصناعي'],
  'عرفات': ['عرفات 1', 'عرفات 2', 'عرفات 3', 'الصناعية'],
  'دار النعيم': ['دار النعيم 1', 'دار النعيم 2', 'دار النعيم 3'],
  'المينه': ['المينه 1', 'المينه 2', 'المينه 3'],
  'الرياض': ['الرياض 1', 'الرياض 2'],
  'سبخة': ['سبخة الوسط', 'سبخة الشمال'],
  'توجنين': ['توجنين 1', 'توجنين 2'],
  'تيارت': ['تيارت 1', 'تيارت 2'],
  'المدينة': ['الجزء الأول', 'الجزء الثاني', 'الجزء الثالث'],
  'الشمال': ['الحي الشمالي', 'المنطقة الصناعية'],
  'البحيرة': ['ساحل البحيرة', 'جنوب البحيرة'],
};

const List<Map<String, String>> deedTypes = [
  {'label': 'تيتر فونسيه (Titre Foncier)', 'icon': '🏆', 'desc': 'أعلى مستوى من الحماية القانونية'},
  {'label': 'رخصة إشغال (Permis d\'occuper)', 'icon': '📋', 'desc': 'وثيقة إدارية معترف بها'},
  {'label': 'عقد بيع عرفي', 'icon': '📝', 'desc': 'عقد موثق بين طرفين'},
  {'label': 'ورقة إدارية', 'icon': '🗂️', 'desc': 'وثيقة إدارية أولية'},
  {'label': 'في إطار التحفيظ', 'icon': '⏳', 'desc': 'بانتظار استكمال التسجيل'},
];

// ─────────────────────────────────────────
// Add Property Page
// ─────────────────────────────────────────
class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  late AnimationController _fabAnimCtrl;

  // Form fields
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _bedroomsCtrl = TextEditingController();
  final _bathroomsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  PropertyType _selectedType = PropertyType.land;
  String _selectedCity = 'نواكشوط';
  String? _selectedMoughataa;
  String? _selectedQuartier;
  String? _selectedDeed;
  bool _forRent = false;

  // Image slots
  final List<Uint8List> _selectedImageBytes = [];
  final List<String> _selectedImageNames = [];
  String? _uploadedDocumentName;
  Uint8List? _uploadedDocumentBytes;
  bool _isUploading = false; // حالة الرفع
  final ImagePicker _imagePicker = ImagePicker();

  // Step tracking
  int _currentStep = 0;
  final List<String> _stepTitles = ['المعلومات الأساسية', 'الموقع', 'التفاصيل', 'الوصف والصور'];

  @override
  void initState() {
    super.initState();
    _fabAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnimCtrl.forward();
    _scrollCtrl.addListener(() {
      // Hide/show fab based on scroll
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _scrollCtrl.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  List<String> get _moughataas {
    return mauritaniaCities[_selectedCity] ?? [];
  }

  List<String> get _quartiers {
    if (_selectedMoughataa == null) return [];
    return moughataQuartiers[_selectedMoughataa!] ?? ['الحي الأول', 'الحي الثاني', 'الحي الثالث'];
  }

  bool get _showRooms =>
      _selectedType == PropertyType.apartment || _selectedType == PropertyType.villa;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.primaryDark,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                  child: OutlinedButton.icon(
                    onPressed: _saveDraft,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withAlpha(100), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('مسودة', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStepIndicator(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step 1: Basic Info
                          _buildSection(
                            title: 'المعلومات الأساسية',
                            icon: Icons.info_outline_rounded,
                            stepIndex: 0,
                            child: Column(
                              children: [
                                _buildTypeSelector(),
                                const SizedBox(height: 16),
                                _buildRentOrSaleToggle(),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _titleCtrl,
                                  label: 'عنوان الإعلان',
                                  hint: 'مثال: أرض سكنية في تفرغ زينه...',
                                  icon: Icons.title_rounded,
                                  validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال عنوان' : null,
                                ),
                                const SizedBox(height: 14),
                                _buildTextField(
                                  controller: _phoneCtrl,
                                  label: 'رقم التواصل',
                                  hint: '+222 XX XX XX XX',
                                  icon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال رقم هاتف' : null,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Step 2: Location
                          _buildSection(
                            title: 'الموقع',
                            icon: Icons.location_on_rounded,
                            stepIndex: 1,
                            child: Column(
                              children: [
                                _buildCitySelector(),
                                const SizedBox(height: 14),
                                _buildMoughataaDropdown(),
                                const SizedBox(height: 14),
                                _buildQuartierDropdown(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Step 3: Property Details
                          _buildSection(
                            title: 'التفاصيل',
                            icon: Icons.home_work_rounded,
                            stepIndex: 2,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _priceCtrl,
                                        label: 'السعر',
                                        hint: '0',
                                        icon: Icons.payments_rounded,
                                        keyboardType: TextInputType.number,
                                        suffix: 'MRU',
                                        suffixColor: AppColors.accent,
                                        validator: (v) => (v == null || v.isEmpty) ? 'أدخل السعر' : null,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _areaCtrl,
                                        label: 'المساحة',
                                        hint: '0',
                                        icon: Icons.square_foot_rounded,
                                        keyboardType: TextInputType.number,
                                        suffix: 'م²',
                                        suffixColor: AppColors.primary,
                                        validator: (v) => (v == null || v.isEmpty) ? 'أدخل المساحة' : null,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_showRooms) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _bedroomsCtrl,
                                          label: 'غرف النوم',
                                          hint: '0',
                                          icon: Icons.bed_rounded,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _bathroomsCtrl,
                                          label: 'الحمامات',
                                          hint: '0',
                                          icon: Icons.bathtub_rounded,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _buildDeedSelector(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Step 4: Description & Media
                          _buildSection(
                            title: 'الوصف والصور',
                            icon: Icons.photo_library_rounded,
                            stepIndex: 3,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _descCtrl,
                                  label: 'وصف العقار',
                                  hint: 'اكتب وصفاً تفصيلياً عن العقار، مميزاته، قربه من الخدمات...',
                                  icon: Icons.description_rounded,
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 20),
                                _buildImageUploadSection(),
                                const SizedBox(height: 16),
                                _buildDocumentUpload(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),
                          _buildSubmitButton(),
                          const SizedBox(height: 12),
                          _buildTipsCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Loading Overlay أثناء الرفع إلى Firebase ──
          if (_isUploading)
            Container(
              color: Colors.black.withAlpha(160),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'جارٍ رفع الملفات...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'يتم رفع الصور والوثيقة إلى السحابة',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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


  // ── Header
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF1A6B47)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            top: -30,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(40),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent.withAlpha(80), width: 2),
                    ),
                    child: const Icon(Icons.add_home_rounded, color: AppColors.accentLight, size: 32),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'إضافة عقار جديد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'أعلن عن عقارك وأراضيك في موريتانيا',
                    style: TextStyle(color: Color(0xFFB8D4E0), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Indicator
  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: List.generate(_stepTitles.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentStep = i),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isDone
                                ? AppColors.success
                                : isActive
                                    ? AppColors.accent
                                    : const Color(0xFFDDE6EF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stepTitles[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                            color: isActive
                                ? AppColors.accent
                                : isDone
                                    ? AppColors.success
                                    : AppColors.textHint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < _stepTitles.length - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Section Wrapper
  Widget _buildSection({
    required String title,
    required IconData icon,
    required int stepIndex,
    required Widget child,
  }) {
    final isCurrentStep = stepIndex == _currentStep;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isCurrentStep ? AppColors.accent.withAlpha(120) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          GestureDetector(
            onTap: () => setState(() => _currentStep = stepIndex),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: isCurrentStep
                    ? AppColors.primary.withAlpha(8)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrentStep
                          ? AppColors.primary.withAlpha(20)
                          : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        color: isCurrentStep ? AppColors.primary : AppColors.textSecondary,
                        size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isCurrentStep ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCurrentStep ? AppColors.accent : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${stepIndex + 1}/${_stepTitles.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCurrentStep ? Colors.white : AppColors.textHint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Type Selector
  Widget _buildTypeSelector() {
    final types = [
      PropertyType.land,
      PropertyType.apartment,
      PropertyType.villa,
      PropertyType.commercial,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'نوع العقار', icon: Icons.category_rounded),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: types.map((type) {
              final selected = _selectedType == type;
              final gradient = _typeGradient(type);
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedType = type;
                    _currentStep = 0;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? gradient : null,
                      color: selected ? null : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: gradient.colors.first.withAlpha(80),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.icon,
                            color: selected ? Colors.white : AppColors.textSecondary,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textSecondary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  LinearGradient _typeGradient(PropertyType type) {
    switch (type) {
      case PropertyType.land:
        return const LinearGradient(colors: [Color(0xFF1A5F7A), Color(0xFF2E8B5E)]);
      case PropertyType.apartment:
        return const LinearGradient(colors: [Color(0xFF2980B9), Color(0xFF1ABC9C)]);
      case PropertyType.villa:
        return const LinearGradient(colors: [Color(0xFF6C3483), Color(0xFF1A5F7A)]);
      case PropertyType.commercial:
        return const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD4A843)]);
      default:
        return const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]);
    }
  }

  // ── Rent/Sale Toggle
  Widget _buildRentOrSaleToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'نوع العرض', icon: Icons.swap_horiz_rounded),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _forRent = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: !_forRent
                          ? const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark])
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: !_forRent
                          ? [
                              BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sell_rounded,
                            color: !_forRent ? Colors.white : AppColors.textSecondary,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'للبيع',
                          style: TextStyle(
                            color: !_forRent ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _forRent = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _forRent ? AppColors.accent : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _forRent
                          ? [
                              BoxShadow(
                                  color: AppColors.accent.withAlpha(70),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.key_rounded,
                            color: _forRent ? Colors.white : AppColors.textSecondary,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'للإيجار',
                          style: TextStyle(
                            color: _forRent ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── City Selector
  Widget _buildCitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'المدينة (Wilaya)', icon: Icons.location_city_rounded),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: mauritaniaCities.keys.map((city) {
              final selected = _selectedCity == city;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedCity = city;
                    _selectedMoughataa = null;
                    _selectedQuartier = null;
                    _currentStep = 1;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : const Color(0xFFDDE6EF),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Text(
                      city,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Moughataa Dropdown
  Widget _buildMoughataaDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'المقاطعة (Moughataa)', icon: Icons.map_rounded),
        const SizedBox(height: 10),
        _buildStyledDropdown(
          hint: 'اختر المقاطعة',
          value: _selectedMoughataa,
          items: _moughataas,
          icon: Icons.map_rounded,
          onChanged: (v) => setState(() {
            _selectedMoughataa = v;
            _selectedQuartier = null;
          }),
        ),
      ],
    );
  }

  // ── Quartier Dropdown
  Widget _buildQuartierDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'الحي (Quartier)', icon: Icons.location_on_rounded),
        const SizedBox(height: 10),
        _buildStyledDropdown(
          hint: _selectedMoughataa == null ? 'اختر المقاطعة أولاً' : 'اختر الحي',
          value: _selectedQuartier,
          items: _quartiers,
          icon: Icons.location_on_rounded,
          enabled: _selectedMoughataa != null,
          onChanged: _selectedMoughataa == null
              ? null
              : (v) => setState(() => _selectedQuartier = v),
        ),
      ],
    );
  }

  Widget _buildStyledDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?)? onChanged,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value != null
              ? AppColors.primary.withAlpha(80)
              : const Color(0xFFDDE6EF),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textHint, size: 18),
                const SizedBox(width: 10),
                Text(hint, style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
              ],
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          ),
          borderRadius: BorderRadius.circular(16),
          elevation: 4,
          dropdownColor: Colors.white,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(item, style: const TextStyle(fontSize: 14)),
                    ),
                  ))
              .toList(),
          onChanged: enabled ? onChanged : null,
          selectedItemBuilder: (_) => items
              .map((item) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(icon, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Deed Type Selector
  Widget _buildDeedSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'نوع السند العقاري', icon: Icons.verified_rounded),
        const SizedBox(height: 12),
        ...deedTypes.map((deed) {
          final selected = _selectedDeed == deed['label'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDeed = deed['label'];
              _currentStep = 2;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withAlpha(10) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFDDE6EF),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: AppColors.primary.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Text(deed['icon']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deed['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: selected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          deed['desc']!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Text Field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
    Color? suffixColor,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, icon: icon),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textDirection: TextDirection.rtl,
          validator: validator,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.primary.withAlpha(160), size: 20),
            suffixText: suffix,
            suffixStyle: TextStyle(
              color: suffixColor ?? AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE6EF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE6EF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Image Upload Section
  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _FieldLabel(label: 'صور العقار', icon: Icons.photo_library_rounded),
            if (_selectedImageBytes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedImageBytes.length}/6',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accent.withAlpha(120),
                width: 1.5,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, color: AppColors.accent, size: 28),
                SizedBox(height: 8),
                Text(
                  'اضغط لاختيار صور من جهازك',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedImageBytes.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImageBytes.length,
              itemBuilder: (context, index) {
                final isFirst = index == 0;
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFirst ? AppColors.accent : AppColors.primary.withAlpha(50),
                      width: isFirst ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          _selectedImageBytes[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isFirst)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(200),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(11),
                                bottomRight: Radius.circular(11),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: const Text(
                              'رئيسية',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedImageBytes.removeAt(index);
                            _selectedImageNames.removeAt(index);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(160),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'الصورة الأولى ستكون الصورة الرئيسية للإعلان. يُنصح برفع صور واضحة وذات جودة عالية.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _pickImages() async {
    if (_selectedImageBytes.length >= 6) {
      _showErrorSnackBar('يمكنك رفع 6 صور كحد أقصى');
      return;
    }
    final remaining = 6 - _selectedImageBytes.length;
    final List<XFile> picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final toProcess = picked.length > remaining ? remaining : picked.length;
    for (int i = 0; i < toProcess; i++) {
      final file = picked[i];
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes.add(bytes);
        _selectedImageNames.add(file.name);
      });
    }
  }

  // ── Document Upload
  Widget _buildDocumentUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'المستندات الثبوتية',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_uploadedDocumentName != null)
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ارفع نسخة من وثيقة الملكية (تيتر فونسيه، رخصة إشغال، إلخ...) لزيادة مصداقية الإعلان.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDocument,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _uploadedDocumentName != null ? AppColors.success.withAlpha(15) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _uploadedDocumentName != null ? AppColors.success : AppColors.accent.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _uploadedDocumentName != null ? Icons.file_present_rounded : Icons.upload_file_rounded, 
                          color: _uploadedDocumentName != null ? AppColors.success : AppColors.accent, 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _uploadedDocumentName ?? 'اختيار ملف للرفع',
                            style: TextStyle(
                              color: _uploadedDocumentName != null ? AppColors.success : AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: _uploadedDocumentName != null ? TextAlign.right : TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_uploadedDocumentName != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _uploadedDocumentName = null),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withAlpha(60)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    setState(() {
      _uploadedDocumentName = file.name;
      _uploadedDocumentBytes = bytes;
    });
  }

  // ── Submit Button
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1A6B47)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitForm,
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.publish_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'نشر الإعلان الآن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tips Card
  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(80)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'نصائح للإعلان الناجح',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _TipItem(text: 'أضف صوراً حقيقية وعالية الجودة لجذب أكبر عدد من المهتمين'),
          _TipItem(text: 'حدد السعر الحقيقي للعقار مع إمكانية التفاوض'),
          _TipItem(text: 'اذكر قرب العقار من المدارس والمستشفيات والمساجد'),
          _TipItem(text: 'ارفع وثائق ملكية رسمية لزيادة الثقة وتسريع البيع'),
        ],
      ),
    );
  }

  // ── Actions
  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.save_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('تم حفظ المسودة بنجاح', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitForm() async {
    setState(() => _currentStep = 0);

    // 1. Form fields validation
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('يرجى تعبئة الحقول المطلوبة');
      return;
    }

    // 2. Images validation
    if (_selectedImageBytes.isEmpty) {
      _showErrorSnackBar('يرجى إضافة صورة واحدة على الأقل للعقار');
      return;
    }

    // 3. Document/Deed validation
    if (_selectedDeed == null && _uploadedDocumentName == null) {
      _showErrorSnackBar('يرجى تحديد أو رفع وثيقة العقار لضمان مصداقية الإعلان');
      return;
    }

    // 4. بدء عملية الرفع
    setState(() => _isUploading = true);

    try {
      // ── رفع الصور إلى Firebase Storage ──
      final List<String> imageUrls = [];
      for (int i = 0; i < _selectedImageBytes.length; i++) {
        final url = await FirebaseService.uploadImage(
          _selectedImageBytes[i],
          _selectedImageNames[i],
        );
        imageUrls.add(url);
      }

      // ── رفع الوثيقة إلى Firebase Storage (إذا وُجدت) ──
      String? documentUrl;
      if (_uploadedDocumentBytes != null && _uploadedDocumentName != null) {
        documentUrl = await FirebaseService.uploadDocument(
          _uploadedDocumentBytes!,
          _uploadedDocumentName!,
        );
      }

      // ── إنشاء كائن Property مؤقت للعرض الفوري ──
      final newProperty = Property(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text,
        location: '${_selectedQuartier ?? ''}، ${_selectedMoughataa ?? ''}',
        city: 'نواكشوط',
        neighborhood: _selectedQuartier ?? '',
        price: double.tryParse(_priceCtrl.text) ?? 0,
        area: double.tryParse(_areaCtrl.text) ?? 0,
        type: _selectedType,
        deed: _selectedDeed ?? 'Titre Foncier',
        phone: _phoneCtrl.text,
        gradientColors: const [AppColors.primary, AppColors.accent],
        icon: _selectedType == PropertyType.land ? Icons.landscape_rounded : Icons.home_rounded,
        isFeatured: true,
        description: _descCtrl.text,
        bedrooms: int.tryParse(_bedroomsCtrl.text),
        bathrooms: int.tryParse(_bathroomsCtrl.text),
        imageUrls: imageUrls,
      );

      // ── حفظ العقار في Firestore ──
      await FirebaseService.addProperty(
        property: newProperty,
        imageUrls: imageUrls,
        documentUrl: documentUrl,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      // ── العودة للرئيسية مع العقار الجديد ──
      Navigator.of(context).pop(newProperty);

    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showErrorSnackBar('حدث خطأ أثناء النشر: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;

  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
