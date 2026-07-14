import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show AppColors, Product, favoriteIdsNotifier, productFromDoc, ProductCard;
import '../services/firebase_service.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المفضلة', style: TextStyle(fontWeight: FontWeight.w900)),
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

          return ValueListenableBuilder<Set<String>>(
            valueListenable: favoriteIdsNotifier,
            builder: (context, favorites, _) {
              if (favorites.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 80,
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد منتجات في المفضلة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اضغط على علامة القلب لإضافة منتجات هنا',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              final favoriteProducts = allProducts.where((p) => favorites.contains(p.id)).toList();

              if (favoriteProducts.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                itemCount: favoriteProducts.length,
                itemBuilder: (context, index) => ProductCard(product: favoriteProducts[index], index: index),
              );
            },
          );
        },
      ),
    );
  }
}
