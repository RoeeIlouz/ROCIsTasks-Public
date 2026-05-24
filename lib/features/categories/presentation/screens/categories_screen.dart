import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_tasks/features/tasks/presentation/providers/task_provider.dart';
import 'package:rocis_tasks/core/services/subscription_service.dart';
import 'package:rocis_tasks/features/categories/domain/models/category.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/core/services/validation_service.dart';
import 'package:rocis_tasks/core/utils/icon_utils.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.categories,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          final categories = provider.categories;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 80,
                    color: theme.disabledColor.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.noCategoriesYet,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showCategorySheet(context),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      l10n.addCategory,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.brightness == Brightness.light
                        ? Colors.grey.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Semantics(
                  label: 'Category: ${category.name}',
                  hint: 'Double tap to edit category',
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () =>
                        _showCategorySheet(context, category: category),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(
                          category.colorValue,
                        ).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconUtils.getIconData(category.iconCode),
                        color: Color(category.colorValue),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (category.isPrivate)
                          Icon(
                            Icons.lock_rounded,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                            size: 18,
                          ),
                        Semantics(
                          label: 'Delete category',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            onPressed: () {
                              provider.deleteCategory(category.id);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          final isAtLimit = !provider.canAddCategory;
          return FloatingActionButton.extended(
            onPressed: () => _showCategorySheet(context),
            icon: isAtLimit
                ? const Icon(Icons.lock_rounded, size: 18)
                : const Icon(Icons.add_rounded),
            label: Row(
              children: [
                Text(
                  l10n.addCategory,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                if (isAtLimit)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "PRO",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  void _showCategorySheet(BuildContext context, {Category? category}) {
    final provider = Provider.of<TaskProvider>(context, listen: false);

    // Check limit only if creating new category (not editing)
    if (category == null && !provider.canAddCategory) {
      final subscriptionService = Provider.of<SubscriptionService>(
        context,
        listen: false,
      );
      subscriptionService.showPaywall();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategorySheet(category: category),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final Category? category;

  const _CategorySheet({this.category});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late int _selectedColor;
  late int _selectedIcon;
  late bool _isPrivate;

  final List<Color> _colors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF84CC16), // Lime
    const Color(0xFFEAB308), // Yellow
    const Color(0xFFF97316), // Orange
    const Color(0xFF78350F), // Brown
    const Color(0xFF64748B), // Slate
  ];

  final List<IconData> _icons = IconUtils.categoryIcons;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.colorValue ?? _colors.first.toARGB32();
    _selectedIcon = widget.category?.iconCode ?? Icons.category.codePoint;
    _isPrivate = widget.category?.isPrivate ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: true,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.category == null ? l10n.newCategory : l10n.editCategory,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Preview Section
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(_selectedColor).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconUtils.getIconData(_selectedIcon),
                  color: Color(_selectedColor),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 32),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                onChanged: (value) => setState(() {}),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: l10n.name,
                  labelStyle: GoogleFonts.outfit(),
                  prefixIcon: const Icon(Icons.edit_rounded, size: 22),
                  filled: true,
                  fillColor: theme.brightness == Brightness.light
                      ? Colors.grey.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(18),
                ),
                maxLength: 30,
                validator: (value) {
                  return ValidationService.validateCategoryName(value);
                },
              ),
            ),
            const SizedBox(height: 28),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
              ),
              title: Text(
                l10n.privateCategory,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.privateCategorySubtitle,
                style: GoogleFonts.outfit(fontSize: 13),
              ),
              value: _isPrivate,
              onChanged: (value) {
                if (!subscriptionService.isPremium) {
                  subscriptionService.showPaywall();
                  return;
                }
                setState(() => _isPrivate = value);
              },
            ),
            const SizedBox(height: 16),

            Text(
              l10n.color,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  final isSelected = _selectedColor == color.toARGB32();
                  return Semantics(
                    label: 'Color option ${index + 1}',
                    selected: isSelected,
                    button: true,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColor = color.toARGB32()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 24,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            Text(
              l10n.icon,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _icons.length,
              itemBuilder: (context, index) {
                final icon = _icons[index];
                final isSelected = _selectedIcon == icon.codePoint;
                return Semantics(
                  label: 'Icon option ${index + 1}',
                  selected: isSelected,
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon.codePoint),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColor).withValues(alpha: 0.1)
                            : theme.brightness == Brightness.light
                            ? Colors.grey.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Color(_selectedColor)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? Color(_selectedColor)
                            : theme.disabledColor,
                        size: 24,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final taskProvider = Provider.of<TaskProvider>(
                          context,
                          listen: false,
                        );

                        if (widget.category != null) {
                          taskProvider.updateCategory(
                            widget.category!,
                            name: _nameController.text.trim(),
                            colorValue: _selectedColor,
                            iconCode: _selectedIcon,
                            isPrivate: _isPrivate,
                          );
                        } else {
                          taskProvider.addCategory(
                            _nameController.text.trim(),
                            _selectedColor,
                            _selectedIcon,
                            isPrivate: _isPrivate,
                          );
                        }
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Color(_selectedColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      widget.category == null ? l10n.add : l10n.save,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
