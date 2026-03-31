import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/app_exception.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/menu_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import 'menu_providers.dart';

class DishFormPage extends ConsumerWidget {
  const DishFormPage({super.key, this.dishId});

  final String? dishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dishId == null) {
      return const _DishFormBody();
    }

    final dishAsync = ref.watch(dishProvider(dishId!));
    return dishAsync.when(
      loading: () => const AppScaffold(
        title: '编辑菜品',
        body: SizedBox(height: 320, child: LoadingView()),
      ),
      error: (error, _) => AppScaffold(
        title: '编辑菜品',
        body: ErrorStateView(
          message: AppException.from(
            error,
            fallbackMessage: '菜品加载失败，请稍后重试',
          ).message,
          onRetry: () => ref.invalidate(dishProvider(dishId!)),
        ),
      ),
      data: (dish) => _DishFormBody(existingDish: dish),
    );
  }
}

class _DishFormBody extends ConsumerStatefulWidget {
  const _DishFormBody({this.existingDish});

  final Dish? existingDish;

  @override
  ConsumerState<_DishFormBody> createState() => _DishFormBodyState();
}

class _DishFormBodyState extends ConsumerState<_DishFormBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late List<_IngredientDraft> _ingredients;
  late List<_SpecDraft> _specs;

  XFile? _selectedImage;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingDish?.name ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.existingDish?.category ?? '',
    );
    _ingredients = (widget.existingDish?.ingredients ?? const [])
        .map(_IngredientDraft.fromIngredient)
        .toList();
    if (_ingredients.isEmpty) {
      _ingredients = [_IngredientDraft.empty()];
    }
    _specs = (widget.existingDish?.specs ?? const [])
        .map(_SpecDraft.fromSpec)
        .toList();
    if (_specs.isEmpty) {
      _specs = [_SpecDraft.empty()];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    for (final draft in _ingredients) {
      draft.dispose();
    }
    for (final draft in _specs) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _save() async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) {
      return;
    }

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    if (name.isEmpty || category.isEmpty) {
      setState(() {
        _errorText = '请先填写菜名和分类';
      });
      return;
    }

    final ingredients = <DishIngredient>[];
    for (final draft in _ingredients) {
      final nameText = draft.nameController.text.trim();
      final amountText = draft.amountController.text.trim();
      final unitText = draft.unitController.text.trim();

      if (nameText.isEmpty && amountText.isEmpty && unitText.isEmpty) {
        continue;
      }
      final amount = double.tryParse(amountText);
      if (nameText.isEmpty || unitText.isEmpty || amount == null) {
        setState(() {
          _errorText = '请完整填写每个食材的名称、数量和单位';
        });
        return;
      }
      ingredients.add(
        DishIngredient(name: nameText, amount: amount, unit: unitText),
      );
    }

    if (ingredients.isEmpty) {
      setState(() {
        _errorText = '请至少填写一个食材';
      });
      return;
    }

    final specs = <DishSpec>[];
    for (final draft in _specs) {
      final nameText = draft.nameController.text.trim();
      final valuesText = draft.values
          .map((value) => value.controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (nameText.isEmpty && valuesText.isEmpty) {
        continue;
      }
      if (nameText.isEmpty || valuesText.isEmpty) {
        setState(() {
          _errorText = '请完整填写每组规格的名称和选项';
        });
        return;
      }

      specs.add(
        DishSpec(name: nameText, values: valuesText, required: draft.required),
      );
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final dish = await ref
          .read(menuRepositoryProvider)
          .saveDish(
            familyId: family.id,
            dishId: widget.existingDish?.id,
            name: name,
            category: category,
            ingredients: ingredients,
            specs: specs,
            currentImageUrl: widget.existingDish?.imageUrl,
            selectedImage: _selectedImage,
          );
      ref.invalidate(dishesProvider(family.id));
      ref.invalidate(dishProvider(dish.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
        context.pop();
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '菜品保存失败，请稍后重试',
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final dish = widget.existingDish;
    final family = ref.read(currentFamilyProvider);
    if (dish == null || family == null) {
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: '删除这道菜？',
      message: '删除后不会影响历史订单，但这道菜不会再出现在菜单里。',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(menuRepositoryProvider).deleteDish(dish.id);
      ref.invalidate(dishesProvider(family.id));
      if (mounted) {
        context.pop();
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '删除菜品失败，请稍后重试',
        ).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    final existingImageAsync = ref.watch(
      dishImageProvider(widget.existingDish?.imageUrl),
    );

    if (family == null) {
      return const AppScaffold(
        title: '菜品表单',
        body: EmptyState(title: '没有可用家庭', description: '请先进入一个家庭再继续。'),
      );
    }

    return AppScaffold(
      title: widget.existingDish == null ? '新增菜品' : '编辑菜品',
      subtitle: family.name,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('封面图', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: _selectedImage != null
                        ? Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                          )
                        : existingImageAsync.when(
                            loading: () => Container(
                              color: AppColors.surfaceSoft,
                              child: const LoadingView(label: '图片加载中'),
                            ),
                            error: (_, _) => Container(
                              color: AppColors.surfaceSoft,
                              child: const Icon(
                                Icons.image_not_supported_rounded,
                              ),
                            ),
                            data: (url) => url == null
                                ? Container(
                                    color: AppColors.surfaceSoft,
                                    child: const Icon(
                                      Icons.image_rounded,
                                      size: 48,
                                    ),
                                  )
                                : Image.network(url, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: '选择图片',
                  icon: Icons.photo_library_rounded,
                  onPressed: _pickImage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: '菜名',
                  errorText: _errorText,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _categoryController,
                  label: '分类',
                  hintText: '例如 凉菜、热炒、汤',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '规格',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _specs.add(_SpecDraft.empty());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '例如：杯型、温度、口味、甜度。留空整组即可不启用规格。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _specs.length; index++) ...[
                  _SpecEditorCard(
                    draft: _specs[index],
                    onRemove: _specs.length == 1
                        ? null
                        : () {
                            setState(() {
                              final item = _specs.removeAt(index);
                              item.dispose();
                            });
                          },
                  ),
                  if (index != _specs.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '食材',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _ingredients.add(_IngredientDraft.empty());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _ingredients.length; index++) ...[
                  _IngredientRow(
                    draft: _ingredients[index],
                    onRemove: _ingredients.length == 1
                        ? null
                        : () {
                            setState(() {
                              final item = _ingredients.removeAt(index);
                              item.dispose();
                            });
                          },
                  ),
                  if (index != _ingredients.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: '保存',
            onPressed: _save,
            icon: Icons.save_rounded,
            isLoading: _isSaving,
          ),
          if (widget.existingDish != null) ...[
            const SizedBox(height: 12),
            DangerButton(
              label: '删除',
              icon: Icons.delete_outline_rounded,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.draft, this.onRemove});

  final _IngredientDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AppTextField(controller: draft.nameController, label: '食材'),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: AppTextField(
            controller: draft.amountController,
            label: '数量',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: AppTextField(controller: draft.unitController, label: '单位'),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
        ],
      ],
    );
  }
}

class _IngredientDraft {
  _IngredientDraft({
    required this.nameController,
    required this.amountController,
    required this.unitController,
  });

  factory _IngredientDraft.empty() {
    return _IngredientDraft(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      unitController: TextEditingController(),
    );
  }

  factory _IngredientDraft.fromIngredient(DishIngredient ingredient) {
    return _IngredientDraft(
      nameController: TextEditingController(text: ingredient.name),
      amountController: TextEditingController(text: '${ingredient.amount}'),
      unitController: TextEditingController(text: ingredient.unit),
    );
  }

  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController unitController;

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
  }
}

class _SpecDraft {
  _SpecDraft({
    required this.nameController,
    required this.required,
    required this.values,
  });

  factory _SpecDraft.empty() {
    return _SpecDraft(
      nameController: TextEditingController(),
      required: false,
      values: [_SpecValueDraft.empty()],
    );
  }

  factory _SpecDraft.fromSpec(DishSpec spec) {
    return _SpecDraft(
      nameController: TextEditingController(text: spec.name),
      required: spec.required,
      values: (spec.values.isEmpty ? [''] : spec.values)
          .map(_SpecValueDraft.fromText)
          .toList(),
    );
  }

  final TextEditingController nameController;
  bool required;
  final List<_SpecValueDraft> values;

  DishSpec? toDishSpec() {
    final name = nameController.text.trim();
    final parsedValues = values
        .map((draft) => draft.controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (name.isEmpty && parsedValues.isEmpty) {
      return null;
    }

    return DishSpec(name: name, values: parsedValues, required: required);
  }

  void dispose() {
    nameController.dispose();
    for (final value in values) {
      value.dispose();
    }
  }
}

class _SpecValueDraft {
  _SpecValueDraft({required this.controller});

  factory _SpecValueDraft.empty() {
    return _SpecValueDraft(controller: TextEditingController());
  }

  factory _SpecValueDraft.fromText(String value) {
    return _SpecValueDraft(controller: TextEditingController(text: value));
  }

  final TextEditingController controller;

  void dispose() {
    controller.dispose();
  }
}

class _SpecEditorCard extends StatefulWidget {
  const _SpecEditorCard({required this.draft, this.onRemove});

  final _SpecDraft draft;
  final VoidCallback? onRemove;

  @override
  State<_SpecEditorCard> createState() => _SpecEditorCardState();
}

class _SpecEditorCardState extends State<_SpecEditorCard> {
  void _addValue() {
    setState(() {
      widget.draft.values.add(_SpecValueDraft.empty());
    });
  }

  void _removeValue(int index) {
    setState(() {
      final value = widget.draft.values.removeAt(index);
      value.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: draft.nameController,
                  label: '规格名',
                  hintText: '例如 杯型',
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('必选'),
                  Switch(
                    value: draft.required,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        draft.required = value;
                      });
                    },
                  ),
                ],
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '规格值',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _addValue,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < draft.values.length; index++) ...[
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: draft.values[index].controller,
                    label: '选项 ${index + 1}',
                    hintText: '例如 大杯',
                  ),
                ),
                if (draft.values.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _removeValue(index),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ],
            ),
            if (index != draft.values.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
