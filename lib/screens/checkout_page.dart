import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'
    show
        AppColors,
        Product,
        cartNotifier,
        clearCart,
        formatPrice,
        productFromDoc,
        parseCartKey;
import '../services/firebase_service.dart';

/// VAZA shop's WhatsApp number for order checkout (+222 36954055).
/// Checkout always goes to the shop, not to individual product phone
/// numbers — this is a single-owner store, not a multi-seller marketplace.
const String _shopWhatsAppNumber = '22236954055';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOrder(List<_CheckoutLine> lines, double total) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final buffer = StringBuffer('مرحباً، أرغب بطلب المنتجات التالية من متجر فازا (VAZA):\n\n');
    buffer.writeln('معلومات العميل:');
    buffer.writeln('الاسم: ${_nameCtrl.text.trim()}');
    buffer.writeln('الهاتف: ${_phoneCtrl.text.trim()}');
    buffer.writeln('عنوان التوصيل: ${_addressCtrl.text.trim()}');
    buffer.writeln('\nالمنتجات:');
    for (final line in lines) {
      final sizeSuffix = line.size != null ? ' (المقاس: ${line.size})' : '';
      buffer.writeln(
        '• ${line.product.title}$sizeSuffix × ${line.quantity} — ${formatPrice(line.product.price * line.quantity)}',
      );
    }
    buffer.writeln('\nالإجمالي: ${formatPrice(total)} (أوقية موريتانية - MRU)');

    final uri = Uri.parse('https://wa.me/$_shopWhatsAppNumber?text=${Uri.encodeComponent(buffer.toString())}');

    bool ok = false;
    try {
      // webOnlyWindowName forces a new tab on Flutter Web — without it,
      // the async platform-channel hop to url_launcher_web can land after
      // the click's user-activation window closes, and browsers silently
      // block the resulting window.open() as a popup.
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      clearCart();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر فتح واتساب — تأكد من السماح بالنوافذ المنبثقة لهذا الموقع'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.productsStream(),
        builder: (context, snapshot) {
          final allProducts =
              snapshot.hasData ? snapshot.data!.docs.map<Product>(productFromDoc).toList() : <Product>[];
          final productsById = {for (final p in allProducts) p.id: p};

          return ValueListenableBuilder<Map<String, int>>(
            valueListenable: cartNotifier,
            builder: (context, cart, _) {
              final lines = cart.entries
                  .map((e) => MapEntry(parseCartKey(e.key), e))
                  .where((e) => productsById.containsKey(e.key.productId))
                  .map(
                    (e) => _CheckoutLine(
                      product: productsById[e.key.productId]!,
                      size: e.key.size,
                      quantity: e.value.value,
                    ),
                  )
                  .toList();

              final total = lines.fold<double>(0, (acc, l) => acc + l.product.price * l.quantity);

              // resizeToAvoidBottomInset (Scaffold's default, set explicitly
              // here for clarity) shrinks body+bottomNavigationBar to sit
              // above the keyboard. Putting the submit button in
              // bottomNavigationBar — instead of a Positioned overlay inside
              // a Stack, which does not participate in that resize/animation
              // the same way — is what keeps it correctly pinned above the
              // keyboard instead of overlapping it, and lets the scroll
              // view's built-in focused-field auto-scroll work against an
              // accurate viewport size instead of a guessed padding value.
              return Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                body: lines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            const Text(
                              'سلتك فارغة',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection(
                              title: 'ملخص الطلب',
                              icon: Icons.receipt_long_rounded,
                              child: Column(
                                children: [
                                  ...lines.map((line) => _OrderSummaryRow(line: line)),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الإجمالي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      Text(formatPrice(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSection(
                              title: 'معلومات التوصيل',
                              icon: Icons.local_shipping_outlined,
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildTextField(
                                      controller: _nameCtrl,
                                      label: 'الاسم الكامل',
                                      hint: 'مثال: محمد ولد أحمد',
                                      icon: Icons.person_outline_rounded,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال الاسم' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextField(
                                      controller: _phoneCtrl,
                                      label: 'رقم الهاتف',
                                      hint: '+222 XX XX XX XX',
                                      icon: Icons.phone_rounded,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال رقم الهاتف' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildTextField(
                                      controller: _addressCtrl,
                                      label: 'عنوان التوصيل',
                                      hint: 'المدينة، الحي، أقرب معلم...',
                                      icon: Icons.location_on_outlined,
                                      maxLines: 3,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال عنوان التوصيل' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                bottomNavigationBar: lines.isEmpty
                    ? null
                    : Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : () => _submitOrder(lines, total),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.textHint,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              icon: _isSubmitting
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Icon(Icons.message_rounded, size: 20),
                              label: const Text('إرسال الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
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
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 20),
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
}

class _CheckoutLine {
  final Product product;
  final String? size;
  final int quantity;
  const _CheckoutLine({required this.product, required this.size, required this.quantity});
}

class _OrderSummaryRow extends StatelessWidget {
  final _CheckoutLine line;
  const _OrderSummaryRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final sizeSuffix = line.size != null ? ' (${line.size})' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${line.product.title}$sizeSuffix × ${line.quantity}',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatPrice(line.product.price * line.quantity),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
