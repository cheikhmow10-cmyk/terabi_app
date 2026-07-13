import 'package:flutter/material.dart';
import '../main.dart'; // For AppColors, mockProperties, favoriteIdsNotifier, PropertyCard

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'المفضلة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ValueListenableBuilder<Set<String>>(
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
                    'لا توجد عقارات في المفضلة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اضغط على علامة القلب لإضافة عقارات هنا',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final favoriteProperties = mockProperties
              .where((p) => favorites.contains(p.id))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: favoriteProperties.length,
            itemBuilder: (context, index) {
              return PropertyCard(
                property: favoriteProperties[index],
                index: index,
              );
            },
          );
        },
      ),
    );
  }
}
