import 'package:flutter/material.dart';
import '../../core/services/id_card_form_service.dart'
    show IdCardFormService, IdCardFormField;

/// ID Card Form Builder Screen
///
/// Allows principals to create and manage the dynamic ID card form
class IdCardFormBuilderScreen extends StatefulWidget {
  final String principalId;
  final VoidCallback? onFormSaved;

  const IdCardFormBuilderScreen({
    Key? key,
    required this.principalId,
    this.onFormSaved,
  }) : super(key: key);

  @override
  State<IdCardFormBuilderScreen> createState() =>
      _IdCardFormBuilderScreenState();
}

class _IdCardFormBuilderScreenState extends State<IdCardFormBuilderScreen> {
  final _formService = IdCardFormService();
  final _formTitleController = TextEditingController();
  final _formDescriptionController = TextEditingController();
  final List<IdCardFormField> _fields = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingForm();
  }

  Future<void> _loadExistingForm() async {
    setState(() => _isLoading = true);
    try {
      final form =
          await _formService.getIdCardForm(principalId: widget.principalId);
      if (form != null) {
        setState(() {
          _formTitleController.text = form.formTitle;
          _formDescriptionController.text = form.formDescription;
          _fields.clear();
          _fields.addAll(form.formFields);
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addField() {
    print(
        '[FormBuilder] ► Adding new field (structure only - not for data entry)');

    final newField = IdCardFormField(
      fieldId: 'field_${_fields.length + 1}',
      fieldName: 'New Field',
      fieldType: 'text',
      order: _fields.length,
    );

    setState(() => _fields.add(newField));
    _showFieldDialog(newField, _fields.length - 1);
  }

  void _editField(int index) {
    print('[FormBuilder] ► Editing field configuration (label & type only)');
    _showFieldDialog(_fields[index], index);
  }

  void _showFieldDialog(IdCardFormField field, int index) {
    final nameController = TextEditingController(text: field.fieldName);
    String? selectedType = field.fieldType;
    bool isRequired = field.isRequired;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Configure Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Field name input (NO VALIDATION)
                TextField(
                  controller: nameController,
                  enabled: true,
                  decoration: const InputDecoration(
                    labelText: 'Field Name',
                    hintText: 'e.g., Full Name, Class',
                    border: OutlineInputBorder(),
                  ),
                  // NO validator property
                ),
                const SizedBox(height: 12),

                // Field type selector (replaced FormField with regular button)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Field Type',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedType,
                      onChanged: (value) =>
                          setState(() => selectedType = value),
                      items: ['text', 'dropdown', 'number', 'date']
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Note: placeholder and options removed from field schema

                const SizedBox(height: 12),

                // Required checkbox (NO VALIDATION)
                CheckboxListTile(
                  value: isRequired,
                  onChanged: (value) =>
                      setState(() => isRequired = value ?? true),
                  title: const Text('Required Field'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                print(
                    '[FormBuilder] Saving field configuration (NO VALIDATION)');

                final updatedField = IdCardFormField(
                  fieldId: field.fieldId,
                  fieldName: nameController.text.isEmpty
                      ? 'Field ${index + 1}'
                      : nameController.text,
                  fieldType: selectedType ?? 'text',
                  isRequired: isRequired,
                  order: index,
                );

                print(
                    '[FormBuilder] Field config saved: ${updatedField.fieldName} (${updatedField.fieldType})');

                _fields[index] = updatedField;
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
      // Reorder fields
      for (int i = 0; i < _fields.length; i++) {
        final field = _fields[i];
        _fields[i] = IdCardFormField(
          fieldId: field.fieldId,
          fieldName: field.fieldName,
          fieldType: field.fieldType,
          isRequired: field.isRequired,
          order: i,
        );
      }
    });
  }

  void _moveField(int index, int direction) {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _fields.length) return;

    setState(() {
      final temp = _fields[index];
      _fields[index] = _fields[newIndex];
      _fields[newIndex] = temp;

      // Update orders
      for (int i = 0; i < _fields.length; i++) {
        final field = _fields[i];
        _fields[i] = IdCardFormField(
          fieldId: field.fieldId,
          fieldName: field.fieldName,
          fieldType: field.fieldType,
          isRequired: field.isRequired,
          order: i,
        );
      }
    });
  }

  Future<void> _saveForm() async {
    print('═══════════════════════════════════════════════════════════');
    print('[FormBuilder] SAVING FORM STRUCTURE (NO VALIDATION)');
    print('═══════════════════════════════════════════════════════════');
    print('[FormBuilder] Principal ID: ${widget.principalId}');
    print(
        '[FormBuilder] Form Title: ${_formTitleController.text.isEmpty ? "ID Card Form (auto)" : _formTitleController.text}');
    print('[FormBuilder] Description: ${_formDescriptionController.text}');
    print('[FormBuilder] Total Fields: ${_fields.length}');

    // Print each field configuration (structure only - NO DATA)
    for (int i = 0; i < _fields.length; i++) {
      final field = _fields[i];
      print(
          '[FormBuilder] Field $i: "${field.fieldName}" (type: ${field.fieldType}, required: ${field.isRequired})');
    }

    setState(() => _isSaving = true);
    try {
      // DIRECTLY SAVE - NO VALIDATION CHECKS
      print('[FormBuilder] ► Calling saveIdCardForm (NO VALIDATION)');

      final success = await _formService.saveIdCardForm(
        principalId: widget.principalId,
        formFields: _fields,
        formTitle: _formTitleController.text.isEmpty
            ? 'ID Card Form'
            : _formTitleController.text,
        formDescription: _formDescriptionController.text,
      );

      if (success != null) {
        print('[FormBuilder] ✅ Form saved successfully!');
        print('[FormBuilder] Saved Form ID: $success');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Form structure saved! Students/Teachers can now fill it.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          widget.onFormSaved?.call();

          // Small delay to show success message
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context);
        }
      } else {
        print('[FormBuilder] ❌ Failed to save form');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save form'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('[FormBuilder] ❌ Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      print('═══════════════════════════════════════════════════════════');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card Form Builder'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ROLE-BASED HEADER
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PRINCIPAL ROLE: Configure form fields only. No data entry.',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form title and description
            TextField(
              controller: _formTitleController,
              decoration: InputDecoration(
                labelText: 'Form Title',
                hintText: 'e.g., Student ID Card Form',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _formDescriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Form Description (Optional)',
                hintText: 'Add a description for the form',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Form Fields (${_fields.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Field'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_fields.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No fields added yet. Tap "Add Field" to get started.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _fields.length,
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Field info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.fieldName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Chip(
                                      label: Text(
                                        field.fieldType,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.blue[100],
                                    ),
                                    const SizedBox(width: 8),
                                    if (field.isRequired)
                                      const Chip(
                                        label: Text(
                                          'Required',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.red,
                                        labelStyle:
                                            TextStyle(color: Colors.white),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Actions
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editField(index),
                              ),
                              Row(
                                children: [
                                  if (index > 0)
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward,
                                          size: 18),
                                      onPressed: () => _moveField(index, -1),
                                    ),
                                  if (index < _fields.length - 1)
                                    IconButton(
                                      icon: const Icon(Icons.arrow_downward,
                                          size: 18),
                                      onPressed: () => _moveField(index, 1),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeField(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Form Structure',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _formTitleController.dispose();
    _formDescriptionController.dispose();
    super.dispose();
  }
}
