import 'package:flutter/material.dart';
import '../../core/services/id_card_form_service.dart' show IdCardFormService;

/// ID Card Form Submissions Viewer
///
/// Allows principals to view all form submissions from students and teachers
class IdCardFormSubmissionsScreen extends StatefulWidget {
  final String principalId;

  const IdCardFormSubmissionsScreen({
    Key? key,
    required this.principalId,
  }) : super(key: key);

  @override
  State<IdCardFormSubmissionsScreen> createState() =>
      _IdCardFormSubmissionsScreenState();
}

class _IdCardFormSubmissionsScreenState
    extends State<IdCardFormSubmissionsScreen> {
  final _formService = IdCardFormService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _submissions = [];
  String _selectedRole = 'all'; // 'student', 'teacher', 'all'

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final submissions = await _formService.getFormSubmissions(
        principalId: widget.principalId,
        role: _selectedRole,
      );
      setState(() => _submissions = submissions);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSubmissionDetails(Map<String, dynamic> submission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submission Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', submission['userName'] ?? 'N/A'),
              _buildDetailRow('Email', submission['userEmail'] ?? 'N/A'),
              _buildDetailRow(
                  'Role', submission['role']?.toUpperCase() ?? 'N/A'),
              _buildDetailRow(
                'Submitted',
                _formatDate(submission['submittedAt']),
              ),
              const SizedBox(height: 16),
              Text(
                'Form Data:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._buildFormDataRows(submission['formData'] ?? {}),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormDataRows(Map<String, dynamic> formData) {
    return formData.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.key,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              entry.value.toString(),
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is String) {
      return DateTime.parse(date).toString().split('.')[0];
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Submissions'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter by role
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRoleFilterButton('All', 'all'),
                  const SizedBox(width: 8),
                  _buildRoleFilterButton('Students', 'student'),
                  const SizedBox(width: 8),
                  _buildRoleFilterButton('Teachers', 'teacher'),
                ],
              ),
            ),
          ),

          // Submissions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _submissions.isEmpty
                    ? Center(
                        child: Text('No submissions found'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSubmissions,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _submissions.length,
                          itemBuilder: (context, index) {
                            final submission = _submissions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title:
                                    Text(submission['userName'] ?? 'Unknown'),
                                subtitle: Text(
                                  '${submission['role']?.toUpperCase()} • ${_formatDate(submission['submittedAt'])}',
                                ),
                                trailing:
                                    Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => _showSubmissionDetails(submission),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterButton(String label, String role) {
    final isSelected = _selectedRole == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedRole = role);
        _loadSubmissions();
      },
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey[300]!,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
