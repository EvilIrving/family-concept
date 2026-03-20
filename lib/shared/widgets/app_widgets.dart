import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/app_models.dart';

export '../../core/theme/app_theme.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.subtitle,
    this.actions,
    this.scrollable = true,
    this.showAppBar = true,
    this.useGradientHeader = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.bodyPadding,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final bool scrollable;
  final bool showAppBar;
  final bool useGradientHeader;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? bodyPadding;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        (bodyPadding ??
                const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.section,
                ))
            .resolve(Directionality.of(context));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
              actions: actions,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: useGradientHeader
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryAccent],
                        )
                      : const LinearGradient(
                          colors: [AppColors.primary, AppColors.primary],
                        ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: scrollable
          ? LayoutBuilder(
              builder: (context, constraints) {
                final minBodyHeight =
                    (constraints.maxHeight - resolvedPadding.vertical).clamp(
                      0.0,
                      double.infinity,
                    );

                return SingleChildScrollView(
                  padding: resolvedPadding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minBodyHeight),
                    child: body,
                  ),
                );
              },
            )
          : Padding(padding: resolvedPadding, child: body),
    );
  }
}

class CenteredContent extends StatelessWidget {
  const CenteredContent({
    required this.child,
    super.key,
    this.maxWidth = 440,
    this.alignment = const Alignment(0, -0.18),
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 当处于无限高度约束时（如 SingleChildScrollView 内），不应用 minHeight
        final hasFiniteHeight = constraints.maxHeight.isFinite;

        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: hasFiniteHeight ? constraints.maxHeight : 0,
          ),
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0x142D6A4F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E251A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: content,
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.isDanger = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isDanger
            ? AppColors.dangerSoft
            : AppColors.surfaceSoft,
        foregroundColor: isDanger ? AppColors.danger : AppColors.primary,
      ),
      icon: Icon(icon),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.primary,
      ),
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.arrow_forward_rounded),
      label: Text(label),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.surfaceSoft,
        foregroundColor: AppColors.primary,
        side: BorderSide.none,
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.chevron_right_rounded),
      label: Text(label),
    );
  }
}

class DangerButton extends StatelessWidget {
  const DangerButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.dangerSoft,
        foregroundColor: AppColors.danger,
        elevation: 0,
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.warning_amber_rounded),
      label: Text(label),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.description,
    super.key,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primary,
            child: Icon(icon),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('出了点问题', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(label: '重试', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip._({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    super.key,
  });

  factory StatusChip.order(OrderStatus status, {Key? key}) {
    return StatusChip._(
      key: key,
      label: status.label,
      backgroundColor: switch (status) {
        OrderStatus.ordering => AppColors.warningSoft,
        OrderStatus.placed => AppColors.surfaceSoft,
        OrderStatus.finished => AppColors.primaryContainer,
      },
      foregroundColor: switch (status) {
        OrderStatus.ordering => const Color(0xFFE76F51),
        OrderStatus.placed => AppColors.primaryLight,
        OrderStatus.finished => AppColors.primary,
      },
    );
  }

  factory StatusChip.item(ItemStatus status, {Key? key}) {
    return StatusChip._(
      key: key,
      label: status.label,
      backgroundColor: switch (status) {
        ItemStatus.waiting => AppColors.surfaceSoft,
        ItemStatus.cooking => AppColors.warningSoft,
        ItemStatus.done => AppColors.primaryContainer,
      },
      foregroundColor: switch (status) {
        ItemStatus.waiting => AppColors.primaryLight,
        ItemStatus.cooking => const Color(0xFFE76F51),
        ItemStatus.done => AppColors.primary,
      },
    );
  }

  factory StatusChip.role(FamilyRole role, {Key? key}) {
    return StatusChip._(
      key: key,
      label: role.label,
      backgroundColor: role == FamilyRole.member
          ? AppColors.surfaceSoft
          : AppColors.primaryContainer,
      foregroundColor: role == FamilyRole.member
          ? AppColors.primaryLight
          : AppColors.primary,
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceSoft,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide.none,
      ),
    );
  }
}

class FamilyHeaderCard extends StatelessWidget {
  const FamilyHeaderCard({required this.family, super.key, this.onSwitch});

  final FamilySummary family;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryAccent],
              ),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.family.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '当前角色 ${family.role.label}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onSwitch != null)
            IconButton(
              onPressed: onSwitch,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
        // ignore: use_null_aware_elements
        if (trailingWidget != null) trailingWidget,
      ],
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = '加载中'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: builder,
  );
}

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDanger ? AppColors.danger : AppColors.primary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
