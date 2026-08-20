import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rocis_tasks/features/tasks/domain/models/custom_field.dart';
import 'package:rocis_tasks/features/tasks/domain/services/custom_field_action_service.dart';
import 'package:rocis_tasks/l10n/app_localizations.dart';
import 'package:rocis_tasks/shared/ui/widgets/glass_container.dart';

class TaskCustomFieldsSection extends StatelessWidget {
  final List<TaskCustomField> customFields;
  final Function(CustomFieldType type) onAddField;
  final Function(int index) onRemoveField;
  final Function(int index, String label, String value) onUpdateField;

  const TaskCustomFieldsSection({
    super.key,
    required this.customFields,
    required this.onAddField,
    required this.onRemoveField,
    required this.onUpdateField,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.customFields,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            if (customFields.isNotEmpty)
              Text(
                '${customFields.length}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Quick add buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAddChip(
                context,
                type: CustomFieldType.contact,
                label: l10n.contact,
                icon: Icons.phone_outlined,
              ),
              const SizedBox(width: 8),
              _buildAddChip(
                context,
                type: CustomFieldType.location,
                label: l10n.location,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(width: 8),
              _buildAddChip(
                context,
                type: CustomFieldType.url,
                label: l10n.link,
                icon: Icons.link_rounded,
              ),
              const SizedBox(width: 8),
              _buildAddChip(
                context,
                type: CustomFieldType.text,
                label: l10n.note,
                icon: Icons.notes_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (customFields.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              l10n.noCustomFieldsAdded,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...List.generate(customFields.length, (index) {
            final field = customFields[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _CustomFieldItemEditor(
                key: ValueKey(field.id),
                field: field,
                onRemove: () => onRemoveField(index),
                onUpdate: (label, value) => onUpdateField(index, label, value),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAddChip(
    BuildContext context, {
    required CustomFieldType type,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(
        '+ $label',
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      side: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.18),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onAddField(type);
      },
    );
  }
}

class _CustomFieldItemEditor extends StatefulWidget {
  final TaskCustomField field;
  final VoidCallback onRemove;
  final Function(String label, String value) onUpdate;

  const _CustomFieldItemEditor({
    super.key,
    required this.field,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_CustomFieldItemEditor> createState() => _CustomFieldItemEditorState();
}

class _CustomFieldItemEditorState extends State<_CustomFieldItemEditor> {
  late TextEditingController _labelController;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.field.label);
    _valueController = TextEditingController(text: widget.field.value);
  }

  @override
  void didUpdateWidget(covariant _CustomFieldItemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.label != widget.field.label &&
        _labelController.text != widget.field.label) {
      _labelController.text = widget.field.label;
    }
    if (oldWidget.field.value != widget.field.value &&
        _valueController.text != widget.field.value) {
      _valueController.text = widget.field.value;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  String _getValueHint(CustomFieldType type, AppLocalizations l10n) {
    switch (type) {
      case CustomFieldType.contact:
        return l10n.enterContactInfo;
      case CustomFieldType.location:
        return l10n.enterLocation;
      case CustomFieldType.url:
        return l10n.enterUrl;
      case CustomFieldType.text:
        return l10n.enterNote;
    }
  }

  TextInputType _getKeyboardType(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.contact:
        return TextInputType.emailAddress;
      case CustomFieldType.location:
        return TextInputType.streetAddress;
      case CustomFieldType.url:
        return TextInputType.url;
      case CustomFieldType.text:
        return TextInputType.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final icon = CustomFieldActionService.getIcon(
      widget.field.type,
      _valueController.text,
    );

    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label input
                TextField(
                  controller: _labelController,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    hintText: l10n.fieldLabel,
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    widget.onUpdate(val, _valueController.text);
                  },
                ),
                // Value input
                TextField(
                  controller: _valueController,
                  keyboardType: _getKeyboardType(widget.field.type),
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintText: _getValueHint(widget.field.type, l10n),
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    widget.onUpdate(_labelController.text, val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          // 48dp removal button
          Semantics(
            label: 'Remove field',
            button: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onRemove();
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: theme.colorScheme.error.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
