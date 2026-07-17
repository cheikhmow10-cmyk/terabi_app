import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'
    show AppColors, Product, ProductCategoryLabel, cartNotifier, removeFromCart, setCartQuantity, formatPrice, productFromDoc, parseCartKey;
import '../services/firebase_service.dart';
import '../widgets/web_network_image.dart';

/// VAZA shop's WhatsApp number for order checkout (+222 36954055).
/// Checkout always goes to the shop, not to individual product phone
/// numbers — this is a single-owner store, not a multi-seller marketplace.
const String _shopWhatsAppNumber = '22236954055';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  Future<void> _checkout(BuildContext context, List<_CartLine> lines, double total) async {
    if (lines.isEmpty) return;
    final buffer = StringBuffer('مرحباً، أرغب بطلب المنتجات التالية من متجر فازا (VAZA):\n\n');
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

    if (!ok && context.mounted) {
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('السلة', style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
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
                      (e) => _CartLine(
                        cartLineKey: e.value.key,
                        product: productsById[e.key.productId]!,
                        size: e.key.size,
                        quantity: e.value.value,
                      ),
                    )
                    .toList();

                if (lines.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'سلتك فارغة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        const Text('أضف منتجات لتظهر هنا', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                final total = lines.fold<double>(0, (acc, l) => acc + l.product.price * l.quantity);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: lines.length,
                        itemBuilder: (context, index) => _CartItemTile(line: lines[index]),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الإجمالي', style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                Text(formatPrice(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () => _checkout(context, lines, total),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 3,
                                ),
                                icon: const Icon(Icons.message_rounded, size: 20),
                                label: const Text('إتمام الطلب عبر واتساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CartLine {
  final String cartLineKey;
  final Product product;
  final String? size;
  final int quantity;
  const _CartLine({required this.cartLineKey, required this.product, required this.size, required this.quantity});
}

class _CartItemTile extends StatelessWidget {
  final _CartLine line;
  const _CartItemTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: p.imageUrls.isNotEmpty
                  ? WebNetworkImage(
                      url: p.imageUrls.first,
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) => Container(color: AppColors.chipUnselected),
                      errorBuilder: (context) =>
                          Container(color: AppColors.chipUnselected, child: Icon(p.category.icon, color: AppColors.textHint)),
                    )
                  : Container(color: AppColors.chipUnselected, child: Icon(p.category.icon, color: AppColors.textHint)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (line.size != null) ...[
                  const SizedBox(height: 2),
                  Text('المقاس: ${line.size}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(formatPrice(p.price), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove_rounded, onTap: () => setCartQuantity(line.cartLineKey, line.quantity - 1)),
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    _QtyButton(icon: Icons.add_rounded, onTap: () => setCartQuantity(line.cartLineKey, line.quantity + 1)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            onPressed: () => removeFromCart(line.cartLineKey),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: const Color(0xFFF3F1EC), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }
}
