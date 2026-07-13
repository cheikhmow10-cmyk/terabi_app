// ─────────────────────────────────────────────────────────────────────────────
// firebase_service.dart — طبقة خدمات Firebase + ImgBB Image Hosting
//
// الصور تُرفع إلى ImgBB (مجاني) ← يُعيد رابط مباشر يُحفظ في Firestore
// الوثائق: يُحفظ اسمها فقط في Firestore حالياً
//
// ⚙️  للتفعيل: ضع مفتاح ImgBB API في _imgbbApiKey أدناه
//     للحصول على المفتاح: https://api.imgbb.com → Get API Key (مجاني)
//
// ⚡  للتبديل لـ Firebase Storage لاحقاً: ضع _useStorage = true
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show Property, AppColors, PropertyType;
import 'package:flutter/material.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─────────────────────────────────────────────────────────────────────
  // ⚙️  إعدادات الرفع — عدّل هنا فقط
  // ─────────────────────────────────────────────────────────────────────

  /// مفتاح ImgBB API المجاني
  /// احصل عليه من: https://api.imgbb.com → "Get API Key"
  static const String _imgbbApiKey = '051184ca9fa64f1057891af2136086fc'; // ← ✏️

  /// true  = رفع عبر Firebase Storage (يحتاج خطة Blaze)
  /// false = رفع عبر ImgBB API (مجاني)
  static const bool _useStorage = false;

  // ─────────────────────────────────────────────────────────────────────
  // رفع صورة واحدة — ImgBB أو Firebase Storage
  // ─────────────────────────────────────────────────────────────────────
  static Future<String> uploadImage(Uint8List bytes, String fileName) async {
    if (_useStorage) {
      // ── Firebase Storage (Blaze) ──
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('properties/images/${timestamp}_$fileName');
      final snapshot = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await snapshot.ref.getDownloadURL();
    } else {
      // ── ImgBB Free API ──
      return await _uploadToImgBB(bytes, fileName);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // رفع وثيقة العقار (اسم الملف فقط في Firestore)
  // ─────────────────────────────────────────────────────────────────────
  static Future<String> uploadDocument(Uint8List bytes, String fileName) async {
    if (_useStorage) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('properties/documents/${timestamp}_$fileName');
      final snapshot = await ref.putData(bytes);
      return await snapshot.ref.getDownloadURL();
    } else {
      // حفظ اسم الملف فقط — يمكن لاحقاً رفعه عبر ImgBB أيضاً
      return 'doc://$fileName';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // رفع صورة إلى ImgBB والحصول على رابط مباشر
  // ─────────────────────────────────────────────────────────────────────
  static Future<String> _uploadToImgBB(Uint8List bytes, String fileName) async {
    try {
      // تحويل الصورة إلى Base64
      final base64Image = base64Encode(bytes);

      // إرسال طلب POST لـ ImgBB API
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
        body: {
          'image': base64Image,
          'name': fileName,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonData['success'] == true) {
          final data = jsonData['data'] as Map<String, dynamic>;

          // Priority order for a guaranteed direct image URL:
          // 1. data['image']['url']  → nested object, always a raw CDN link (*.jpg / *.png)
          // 2. data['url']           → top-level direct link (same CDN, usually identical)
          // 3. data['display_url']   → can sometimes omit the file extension — last resort
          String? directUrl;

          final imageObj = data['image'];
          if (imageObj is Map) {
            directUrl = imageObj['url'] as String?;
          }
          directUrl ??= data['url'] as String?;
          directUrl ??= data['display_url'] as String?;

          if (directUrl == null || directUrl.isEmpty) {
            throw Exception('ImgBB returned no usable URL. Response: ${response.body}');
          }

          debugPrint('✅ ImgBB upload succeeded. Direct URL: $directUrl');
          return directUrl;
        }
        throw Exception('ImgBB error: ${jsonData['error']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // في حالة فشل الرفع، نُرجع Base64 Data URL كبديل احتياطي
      debugPrint('ImgBB upload failed: $e — using local Base64 fallback');
      final base64 = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // حفظ بيانات عقار جديد في Firestore
  // ─────────────────────────────────────────────────────────────────────
  static Future<String> addProperty({
    required Property property,
    required List<String> imageUrls,
    String? documentUrl,
  }) async {
    final docRef = await _firestore.collection('properties').add({
      'createdBy':         FirebaseAuth.instance.currentUser?.uid,
      'title':             property.title,
      'location':          property.location,
      'city':              property.city,
      'neighborhood':      property.neighborhood,
      'price':             property.price,
      'area':              property.area,
      'type':              property.type.name,
      'deed':              property.deed,
      'phone':             property.phone,
      'description':       property.description ?? '',
      'bedrooms':          property.bedrooms,
      'bathrooms':         property.bathrooms,
      'imageUrls':         imageUrls,
      'documentUrl':       documentUrl,
      'isFeatured':        property.isFeatured,
      'createdAt':         FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ─────────────────────────────────────────────────────────────────────
  // جلب كل العقارات من Firestore (مرة واحدة)
  // ─────────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProperties() async {
    final snapshot = await _firestore
        .collection('properties')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Stream للعقارات (تحديث فوري Real-time)
  // ─────────────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> propertiesStream() {
    return _firestore
        .collection('properties')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────
  // تحويل بيانات Firestore → Property object
  // ─────────────────────────────────────────────────────────────────────
  static Property fromFirestore(Map<String, dynamic> data, String id) {
    PropertyType type;
    switch (data['type']) {
      case 'apartment': type = PropertyType.apartment; break;
      case 'villa':     type = PropertyType.villa;     break;
      case 'land':      type = PropertyType.land;      break;
      case 'commercial': type = PropertyType.commercial; break;
      default:          type = PropertyType.apartment;
    }

    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];

    return Property(
      id:             id,
      title:          data['title'] ?? '',
      location:       data['location'] ?? '',
      city:           data['city'] ?? '',
      neighborhood:   data['neighborhood'] ?? '',
      price:          (data['price'] ?? 0).toDouble(),
      area:           (data['area'] ?? 0).toDouble(),
      type:           type,
      deed:           data['deed'] ?? 'Titre Foncier',
      phone:          data['phone'] ?? '',
      description:    data['description'],
      bedrooms:       data['bedrooms'],
      bathrooms:      data['bathrooms'],
      imageUrls:      imageUrls,
      isFeatured:     data['isFeatured'] ?? false,
      gradientColors: const [AppColors.primary, AppColors.accent],
      icon:           type == PropertyType.land ? Icons.landscape_rounded : Icons.home_rounded,
    );
  }
}
