import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // includes Uint8List
import 'package:image_picker/image_picker.dart';
import '../main.dart' show AppColors, Product, ProductCategory, ProductCategoryLabel;
import '../services/firebase_service.dart';

// ─────────────────────────────────────────
// Admin Dashboard — only reachable via /admin after a successful
// FirebaseAuth email/password sign-in (see AdminGatePage). Currently a
// single-purpose "add product" form; the storefront has no reference to
// this page anywhere.
// ─────────────────────────────────────────
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

const List<String> _availableSizes = ['S', 'M', 'L', 'XL', 'XXL', 'مقاس واحد'];

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  ProductCategory _selectedCategory = ProductCategory.dracs;
  bool _isLuxury = false;
  final Set<String> _selectedSizes = {};

  final List<Uint8List> _selectedImageBytes = [];
  final List<String> _selectedImageNames = [];
  bool _isUploading = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImageBytes.isEmpty) {
      _showErrorSnackBar('يرجى إضافة صورة واحدة على الأقل للمنتج');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final List<String> imageUrls = [];
      for (int i = 0; i < _selectedImageBytes.length; i++) {
        final url = await FirebaseService.uploadImage(
          _selectedImageBytes[i],
          _selectedImageNames[i],
        );
        imageUrls.add(url);
      }

      final newProduct = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text,
        price: double.tryParse(_priceCtrl.text) ?? 0,
        category: _selectedCategory,
        phone: _phoneCtrl.text,
        description: _descCtrl.text,
        sizes: _selectedSizes.toList(),
        imageUrls: imageUrls,
        isLuxury: _isLuxury,
      );

      await FirebaseService.addProduct(product: newProduct, imageUrls: imageUrls);

      if (!mounted) return;
      _resetForm();
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('تم نشر المنتج بنجاح'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showErrorSnackBar('حدث خطأ أثناء النشر: $e');
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleCtrl.clear();
    _priceCtrl.clear();
    _descCtrl.clear();
    _phoneCtrl.clear();
    setState(() {
      _selectedCategory = ProductCategory.dracs;
      _isLuxury = false;
      _selectedSizes.clear();
      _selectedImageBytes.clear();
      _selectedImageNames.clear();
    });
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

  @override
  Widget build(BuildContext context) {
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لوحة تحكم المشرف', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (adminEmail.isNotEmpty)
                    Text(adminEmail, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'تسجيل الخروج',
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إضافة منتج جديد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'التصنيف',
                      icon: Icons.category_rounded,
                      child: _buildCategorySelector(),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'معلومات المنتج',
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _titleCtrl,
                            label: 'اسم المنتج',
                            hint: 'مثال: دراعة فاخرة مطرزة يدوياً...',
                            icon: Icons.title_rounded,
                            validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال اسم المنتج' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
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
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _phoneCtrl,
                            label: 'رقم التواصل',
                            hint: '+222 XX XX XX XX',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال رقم هاتف' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _descCtrl,
                            label: 'الوصف',
                            hint: 'اكتب وصفاً للمنتج، الخامة، طريقة الاستخدام...',
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'المقاسات (اختياري)',
                      icon: Icons.straighten_rounded,
                      child: _buildSizeSelector(),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'منتج فاخر',
                      icon: Icons.diamond_rounded,
                      child: _buildLuxuryToggle(),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'صور المنتج',
                      icon: Icons.photo_library_rounded,
                      child: _buildImageUploadSection(),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),

          // ── Submit Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.textHint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('نشر المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper
  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
        ],
      ),
    );
  }

  // ── Category Selector
  Widget _buildCategorySelector() {
    final categories = ProductCategory.values.where((c) => c != ProductCategory.all).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: categories.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : const Color(0xFFF3F1EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon, color: selected ? Colors.white : AppColors.textSecondary, size: 18),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Size Selector
  Widget _buildSizeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSizes.map((size) {
        final selected = _selectedSizes.contains(size);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedSizes.remove(size);
            } else {
              _selectedSizes.add(size);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : const Color(0xFFF3F1EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              size,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Luxury Toggle
  Widget _buildLuxuryToggle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'ضع علامة "فاخر" على هذا المنتج لتمييزه في المتجر',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ),
        Switch(
          value: _isLuxury,
          onChanged: (v) => setState(() => _isLuxury = v),
          activeThumbColor: AppColors.accent,
        ),
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
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 15),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textDirection: TextDirection.rtl,
          validator: validator,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 20),
            suffixText: suffix,
            suffixStyle: TextStyle(color: suffixColor ?? AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F5F1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEDEAE3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEDEAE3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
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
            const Text('صور المنتج', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if (_selectedImageBytes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                child: Text('${_selectedImageBytes.length}/6', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
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
              color: const Color(0xFFF7F5F1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, color: AppColors.accent, size: 28),
                SizedBox(height: 8),
                Text('اضغط لاختيار صور من جهازك', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
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
                    border: Border.all(color: isFirst ? AppColors.accent : AppColors.primary.withValues(alpha: 0.2), width: isFirst ? 2 : 1),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(_selectedImageBytes[index], fit: BoxFit.cover),
                      ),
                      if (isFirst)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(11), bottomRight: Radius.circular(11)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: const Text('رئيسية', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
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
          'الصورة الأولى ستكون الصورة الرئيسية للمنتج. يُنصح برفع صور واضحة وذات جودة عالية.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
