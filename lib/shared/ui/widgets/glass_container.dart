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
  final bool isSelected;
  final Color? selectedBorderColor;
  final double? elevation;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.15,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.color,
    this.isSelected = false,
    this.selectedBorderColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final useGlass = themeService.useGlassmorphism && subscriptionService.isPremium && !kIsWeb;
    
    // Default glass color adapts to theme if not provided, with a beautiful primary/category tint
    final tintColor = color ?? theme.colorScheme.primary;
    final baseColor = isDark
        ? (themeService.useMaterialTheme ? theme.colorScheme.surface : const Color(0xFF151824))
        : (themeService.useMaterialTheme ? theme.colorScheme.surface : Colors.white);
    final glassColor = Color.lerp(baseColor, tintColor, isDark ? 0.18 : 0.12)!;
    
    final radius = borderRadius ?? BorderRadius.circular(24.0);
    
    // Default border if not provided, subtly tinted with the primary/category color
    final borderTint = color ?? theme.colorScheme.primary;
    final glassBorder = border ?? Border.all(
      color: isSelected 
        ? (selectedBorderColor ?? theme.colorScheme.primary)
        : (isDark 
            ? borderTint.withValues(alpha: 0.15) 
            : borderTint.withValues(alpha: 0.1)),
      width: isSelected ? 2.0 : 1.0,
    );

    final double shadowElevation = elevation ?? (useGlass ? 0.0 : 2.0);
    final List<BoxShadow>? shadow = (!useGlass && shadowElevation > 0.0)
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: shadowElevation * 2.0 + 2.0,
              spreadRadius: 0.0,
              offset: Offset(0, shadowElevation),
            ),
          ]
        : null;

    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: useGlass 
            ? glassColor.withValues(alpha: isSelected ? opacity + 0.1 : opacity)
            : (isSelected 
                ? (color?.withValues(alpha: 0.2) ?? theme.colorScheme.primaryContainer)
                : (color ?? theme.colorScheme.surfaceContainerLow)),
        borderRadius: radius,
        border: useGlass ? glassBorder : (isSelected ? glassBorder : Border.all(color: Colors.transparent)),
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );

    if (!useGlass) {
      return Container(
        margin: margin,
        child: innerContainer,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: innerContainer,
        ),
      ),
    );
  }
}
