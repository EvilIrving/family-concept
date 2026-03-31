import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_environment.dart';
import '../../core/supabase/supabase_provider.dart';
import '../../core/utils/app_exception.dart';
import '../models/app_models.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(supabaseClientProvider));
});

/// Family menu repository.
class MenuRepository {
  const MenuRepository(this._client);

  final SupabaseClient _client;

  Future<List<Dish>> fetchDishes(String familyId) async {
    try {
      final response = await _client
          .from('dishes')
          .select()
          .eq('family_id', familyId)
          .isFilter('archived_at', null)
          .order('category')
          .order('name');

      return response
          .map((row) => Dish.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error, stackTrace) {
      debugPrint('fetchDishes failed: $error');
      debugPrint('familyId: $familyId');
      debugPrint('stackTrace: $stackTrace');
      throw AppException.from(error, fallbackMessage: '菜品加载失败，请稍后重试');
    }
  }

  Future<Dish> fetchDish(String dishId) async {
    try {
      final response = await _client
          .from('dishes')
          .select()
          .eq('id', dishId)
          .single();

      return Dish.fromJson(Map<String, dynamic>.from(response));
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '菜品加载失败，请稍后重试');
    }
  }

  Future<Dish> saveDish({
    required String familyId,
    required String name,
    required String category,
    required List<DishIngredient> ingredients,
    required List<DishSpec> specs,
    String? dishId,
    String? currentImageUrl,
    XFile? selectedImage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException('请先登录');
    }

    try {
      Map<String, dynamic> response;

      if (dishId == null) {
        response = Map<String, dynamic>.from(
          await _client
              .from('dishes')
              .insert({
                'family_id': familyId,
                'name': name.trim(),
                'category': category.trim(),
                'ingredients': ingredients
                    .map((item) => item.toJson())
                    .toList(),
                'specs': specs.map((item) => item.toJson()).toList(),
                'image_url': currentImageUrl,
                'created_by': user.id,
              })
              .select()
              .single(),
        );
      } else {
        response = Map<String, dynamic>.from(
          await _client
              .from('dishes')
              .update({
                'name': name.trim(),
                'category': category.trim(),
                'ingredients': ingredients
                    .map((item) => item.toJson())
                    .toList(),
                'specs': specs.map((item) => item.toJson()).toList(),
                'image_url': currentImageUrl,
              })
              .eq('id', dishId)
              .select()
              .single(),
        );
      }

      var dish = Dish.fromJson(response);

      if (selectedImage != null) {
        final path = '$familyId/${dish.id}.jpg';
        final bytes = await selectedImage.readAsBytes();
        await _uploadDishImage(path, bytes);

        final updated = await _client
            .from('dishes')
            .update({'image_url': path})
            .eq('id', dish.id)
            .select()
            .single();
        dish = Dish.fromJson(Map<String, dynamic>.from(updated));
      }

      return dish;
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '菜品保存失败，请稍后重试');
    }
  }

  Future<void> deleteDish(String dishId) async {
    try {
      await _client
          .from('dishes')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', dishId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '删除菜品失败，请稍后重试');
    }
  }

  Future<String?> resolveDishImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }

    try {
      return await _client.storage
          .from(AppEnvironment.dishesBucket)
          .createSignedUrl(imageUrl, 60 * 60);
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadDishImage(String path, Uint8List bytes) async {
    await _client.storage
        .from(AppEnvironment.dishesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
  }
}
