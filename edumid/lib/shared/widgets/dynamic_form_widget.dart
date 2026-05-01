import 'package:flutter/material.dart';
import '../../core/services/id_card_form_service.dart'
    show IdCardForm, IdCardFormField;

/// Dynamic Form Widget
///
/// Renders form fields dynamically based on form definition
/// Supports text, dropdown, number, and date field types
class DynamicFormWidget extends StatefulWidget {
  final IdCardForm form;
  final VoidCallback? onSubmit;
  final Function(Map<String, dynamic>)? onFormDataChange;
  final bool isReadOnly;

  const DynamicFormWidget({
    Key? key,
    required this.form,
    this.onSubmit,
    this.onFormDataChange,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  late Map<String, dynamic> formData;
  late Map<String, TextEditingController> controllers;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    formData = {};
    controllers = {};

    for (final field in widget.form.formFields) {
      formData[field.fieldName] = '';
      controllers[field.fieldId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateField(IdCardFormField field, String? value) {
    if (field.isRequired && (value == null || value.isEmpty)) {
      return '${field.fieldName} is required';
    }

    if (field.fieldType == 'email' && value != null && value.isNotEmpty) {
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      if (!emailRegex.hasMatch(value)) {
        return 'Please enter a valid email';
      }
    }

    if (field.fieldType == 'number' && value != null && value.isNotEmpty) {
      if (int.tryParse(value) == null) {
        return 'Please enter a valid number';
      }
    }

    return null;
  }

  Widget _buildField(IdCardFormField field) {
    switch (field.fieldType) {
      case 'text':
        return _buildTextField(field);
      case 'dropdown':
        return _buildDropdownField(field);
      case 'number':
        return _buildNumberField(field);
      case 'date':
        return _buildDateField(field);
      default:
        return _buildTextField(field);
    }
  }

  Widget _buildTextField(IdCardFormField field) {
    return TextFormField(
      controller: controllers[field.fieldId],
      enabled: !widget.isReadOnly,
      decoration: InputDecoration(
        labelText: field.fieldName,
        hintText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: field.isRequired
            ? const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'This field is required',
                  child: Text('*',
                      style: TextStyle(color: Colors.red, fontSize: 18)),
                ),
              )
            : null,
      ),
      validator: (value) => _validateField(field, value),
      onChanged: (value) {
        formData[field.fieldName] = value;
        widget.onFormDataChange?.call(formData);
      },
    );
  }

  Widget _buildNumberField(IdCardFormField field) {
    return TextFormField(
      controller: controllers[field.fieldId],
      enabled: !widget.isReadOnly,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: field.fieldName,
        hintText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: field.isRequired
            ? const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('*',
                    style: TextStyle(color: Colors.red, fontSize: 18)),
              )
            : null,
      ),
      validator: (value) => _validateField(field, value),
      onChanged: (value) {
        formData[field.fieldName] = value;
        widget.onFormDataChange?.call(formData);
      },
    );
  }

  Widget _buildDateField(IdCardFormField field) {
    return TextFormField(
      controller: controllers[field.fieldId],
      enabled: !widget.isReadOnly,
      readOnly: true,
      decoration: InputDecoration(
        labelText: field.fieldName,
        hintText: 'Select date',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: const Icon(Icons.calendar_today),
        prefixIcon: field.isRequired
            ? const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('*',
                    style: TextStyle(color: Colors.red, fontSize: 18)),
              )
            : null,
      ),
      onTap: widget.isReadOnly
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                controllers[field.fieldId]!.text =
                    picked.toString().split(' ')[0]; // YYYY-MM-DD format
                formData[field.fieldName] = controllers[field.fieldId]!.text;
                widget.onFormDataChange?.call(formData);
              }
            },
      validator: (value) => _validateField(field, value),
    );
  }

  Widget _buildDropdownField(IdCardFormField field) {
    final currentValue = formData[field.fieldName];
    final isValidValue = currentValue == null || currentValue == '';

    return DropdownButtonFormField<String>(
      value: isValidValue ? currentValue : null,
      isExpanded: true,
      onChanged: widget.isReadOnly
          ? null
          : (value) {
              setState(() {
                formData[field.fieldName] = value ?? '';
                controllers[field.fieldId]!.text = value ?? '';
              });
              widget.onFormDataChange?.call(formData);
            },
      decoration: InputDecoration(
        labelText: field.fieldName,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: field.isRequired
            ? const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('*',
                    style: TextStyle(color: Colors.red, fontSize: 18)),
              )
            : null,
      ),
      items: <DropdownMenuItem<String>>[],
      validator: (value) => _validateField(field, value),
      hint: Text('Select ${field.fieldName}'),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      print('[DynamicForm] Form validated successfully');
      print('[DynamicForm] Form data: $formData');
      widget.onSubmit?.call();
    } else {
      print('[DynamicForm] Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form title
              Text(
                widget.form.formTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (widget.form.formDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.form.formDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
              const SizedBox(height: 24),

              // Form fields
              ...widget.form.formFields.map((field) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(field),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // Submit button
              if (!widget.isReadOnly)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit Form',
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
      ),
    );
  }
}
