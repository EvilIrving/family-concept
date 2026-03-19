import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_models.dart';
import '../../shared/repositories/menu_repository.dart';

final dishesProvider = FutureProvider.family<List<Dish>, String>(
  (ref, familyId) => ref.watch(menuRepositoryProvider).fetchDishes(familyId),
);

final dishProvider = FutureProvider.family<Dish, String>(
  (ref, dishId) => ref.watch(menuRepositoryProvider).fetchDish(dishId),
);

final dishImageProvider = FutureProvider.family<String?, String?>(
  (ref, imageUrl) =>
      ref.watch(menuRepositoryProvider).resolveDishImage(imageUrl),
);
