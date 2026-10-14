import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/shared/ui/theme/theme_service.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;
  final Color? color;
  final Color? tintColor;
  final bool isSelected;
  final Color? selectedBorderColor;
  final double? elevation;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 14.0,
    this.opacity = 0.15,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.color,
    this.tintColor,
    this.isSelected = false,
    this.selectedBorderColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useGlassmorphism = context.select<ThemeService, bool?>(
      (s) => s.useGlassmorphism,
    ) ?? false;
    final useMaterialTheme = context.select<ThemeService, bool?>(
      (s) => s.useMaterialTheme,
    ) ?? false;
    final isPremium = context.select<SubscriptionService, bool?>(
      (s) => s.isPremium,
    ) ?? false;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark &&
        (theme.scaffoldBackgroundColor == Colors.black ||
            theme.colorScheme.surface == const Color(0xFF000000));
    final useGlass = useGlassmorphism && isPremium && !kIsWeb;

    // Default glass color adapts to theme if not provided, with a beautiful primary/category tint
    final effectiveTint = tintColor ?? color ?? theme.colorScheme.primary;
    final baseColor = isAmoled
        ? const Color(0xFF000000)
        : (isDark
              ? (useMaterialTheme
                    ? theme.colorScheme.surface
                    : const Color(0xFF151824))
              : (useMaterialTheme ? theme.colorScheme.surface : Colors.white));

    final glassColor = Color.lerp(
      baseColor,
      effectiveTint,
      isDark ? (isAmoled ? 0.22 : 0.18) : 0.12,
    )!;

    final radius = borderRadius ?? BorderRadius.circular(24.0);

    // Specular border: frosted glass rim catches ambient light with a clean white/tint blend
    final Color borderTone;
    if (isSelected) {
      borderTone = selectedBorderColor ?? theme.colorScheme.primary;
    } else if (useGlass) {
      if (isDark) {
        borderTone = Color.lerp(
          Colors.white,
          effectiveTint,
          0.35,
        )!.withValues(alpha: isAmoled ? 0.22 : 0.18);
      } else {
        borderTone = Color.lerp(
          Colors.white,
          effectiveTint,
          0.20,
        )!.withValues(alpha: 0.38);
      }
    } else {
      borderTone = effectiveTint.withValues(alpha: isDark ? 0.16 : 0.12);
    }

    final glassBorder =
        border ??
        Border.all(
          color: borderTone,
          width: isSelected ? 1.5 : 1.0,
        );

    final double shadowElevation = elevation ?? (useGlass ? 2.0 : 2.0);
    final List<BoxShadow>? shadow;
    if (useGlass && shadowElevation > 0.0) {
      // Floating ambient specular occlusion shadow
      shadow = [
        BoxShadow(
          color: (isDark ? Colors.black : effectiveTint).withValues(
            alpha: isDark ? (isAmoled ? 0.45 : 0.25) : 0.06,
          ),
          blurRadius: shadowElevation * 4.0 + 8.0,
          spreadRadius: -1.0,
          offset: Offset(0, shadowElevation * 1.5),
        ),
        if (!isAmoled)
          BoxShadow(
            color: effectiveTint.withValues(alpha: isDark ? 0.04 : 0.03),
            blurRadius: shadowElevation * 6.0 + 12.0,
            spreadRadius: 1.0,
            offset: const Offset(0, 1),
          ),
      ];
    } else if (!useGlass && shadowElevation > 0.0) {
      shadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
          blurRadius: shadowElevation * 2.0 + 2.0,
          spreadRadius: 0.0,
          offset: Offset(0, shadowElevation),
        ),
      ];
    } else {
      shadow = null;
    }

    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: useGlass
            ? glassColor.withValues(alpha: isSelected ? opacity + 0.1 : opacity)
            : (isSelected
                  ? (color?.withValues(alpha: 0.2) ??
                        (tintColor?.withValues(alpha: 0.2) ??
                            theme.colorScheme.primary.withValues(alpha: 0.12)))
                  : (color ?? theme.colorScheme.surfaceContainerLow)),
        borderRadius: radius,
        border: glassBorder,
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );

    // blur <= 0 keeps the glass tint but skips the BackdropFilter, for
    // surfaces that animate over a dimmed barrier where a live blur only
    // costs frames.
    if (!useGlass || blur <= 0) {
      return Container(margin: margin, child: innerContainer);
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: innerContainer,
        ),
      ),
    );
  }
}
