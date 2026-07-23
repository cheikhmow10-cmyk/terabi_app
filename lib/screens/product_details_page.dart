import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show AppColors, CategoryIcon, Product, ProductCategoryLabel, favoriteIdsNotifier, toggleFavorite, formatPrice, addToCart;
import '../widgets/web_network_image.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _imageIndex = 0;
  final PageController _pageController = PageController();
  String? _selectedSize;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp(Product p) async {
    final digits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final sizeSuffix = _selectedSize != null ? ' — المقاس: $_selectedSize' : '';
    final message = 'مرحباً، أنا مهتم بمنتج "${p.title}"$sizeSuffix (${formatPrice(p.price)}) من متجر فازا (VAZA).';
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
    bool ok = false;
    try {
      // webOnlyWindowName forces a new tab on Flutter Web — without it, the
      // async platform-channel hop can land after the click's user-activation
      // window closes, and browsers silently block the popup.
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) _showError('تعذر فتح واتساب — تأكد من السماح بالنوافذ المنبثقة لهذا الموقع');
  }

  Future<void> _callSeller(Product p) async {
    bool ok = false;
    try {
      ok = await launchUrl(Uri.parse('tel:${p.phone}'), webOnlyWindowName: '_blank');
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) _showError('تعذر إجراء الاتصال');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: favoriteIdsNotifier,
      builder: (context, favorites, _) {
        final isFav = favorites.contains(p.id);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppColors.background,
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (p.sizes.isNotEmpty && _selectedSize == null) {
                              _showError('الرجاء اختيار المقاس أولاً');
                              return;
                            }
                            addToCart(p.id, size: _selectedSize);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('تمت الإضافة إلى السلة'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                            shadowColor: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                          label: const Text('أضف إلى السلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: ElevatedButton(
                        onPressed: () => _callSeller(p),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F1EC),
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.phone_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: ElevatedButton(
                        onPressed: () => _openWhatsApp(p),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                          shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.message_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 380,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? Colors.red : Colors.white,
                            size: 18,
                          ),
                          onPressed: () => toggleFavorite(p.id),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(background: _buildImageGallery(p)),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.chipUnselected, borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CategoryIcon(category: p.category, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 5),
                                    Text(
                                      p.category.label,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.isLuxury) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                                  child: const Text(
                                    'فاخر',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            p.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatPrice(p.price),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                          if (p.sizes.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'المقاسات المتوفرة',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: p.sizes.map((s) {
                                final selected = _selectedSize == s;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedSize = s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE8E5DF)),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: selected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'وصف المنتج',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (p.description?.isNotEmpty ?? false) ? p.description! : 'لا يوجد وصف متاح لهذا المنتج.',
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageGallery(Product p) {
    if (p.imageUrls.isEmpty) {
      return Container(
        color: AppColors.primary,
        child: Center(child: CategoryIcon(category: p.category, size: 80, color: Colors.white.withValues(alpha: 0.3))),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: p.imageUrls.length,
          onPageChanged: (i) => setState(() => _imageIndex = i),
          itemBuilder: (context, i) => WebNetworkImage(
            url: p.imageUrls[i],
            fit: BoxFit.cover,
            placeholderBuilder: (context) => Container(color: AppColors.chipUnselected),
            errorBuilder: (context) => Container(
              color: AppColors.chipUnselected,
              child: Center(child: CategoryIcon(category: p.category, size: 60, color: AppColors.textHint)),
            ),
          ),
        ),
        if (p.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                p.imageUrls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _imageIndex == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _imageIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
