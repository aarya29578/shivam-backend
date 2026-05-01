import 'package:flutter/material.dart';
import '../../core/services/id_card_form_service.dart'
    show IdCardForm, IdCardFormService;
import 'dynamic_form_widget.dart';

/// ID Card Form Fill Screen
///
/// Allows students and teachers to fill and submit the ID card form
/// Shows form to fill + submissions below based on role
class IdCardFormFillScreen extends StatefulWidget {
  final String principalId;
  final String userId;
  final String userEmail;
  final String userName;
  final String role; // 'student' or 'teacher'

  const IdCardFormFillScreen({
    Key? key,
    required this.principalId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.role,
  }) : super(key: key);

  @override
  State<IdCardFormFillScreen> createState() => _IdCardFormFillScreenState();
}

class _IdCardFormFillScreenState extends State<IdCardFormFillScreen> {
  final _formService = IdCardFormService();
  late Future<IdCardForm?> _formFuture;
  Map<String, dynamic> _currentFormData = {};
  bool _isSubmitting = false;
  bool _shouldRefreshSubmissions = false;

  bool _hasSubmittedCurrentForm(
    IdCardForm form,
    List<Map<String, dynamic>> submissions,
  ) {
    if (widget.role != 'student' && widget.role != 'teacher') return false;
    final formUpdatedAt = form.updatedAt;

    for (final sub in submissions) {
      if ((sub['userId']?.toString() ?? '') != widget.userId) continue;
      final submittedAt =
          DateTime.tryParse(sub['submittedAt']?.toString() ?? '');
      if (submittedAt == null) continue;
      if (formUpdatedAt == null || !submittedAt.isBefore(formUpdatedAt)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? _latestMySubmission(
    List<Map<String, dynamic>> submissions,
  ) {
    final mine = submissions
        .where((sub) => (sub['userId']?.toString() ?? '') == widget.userId)
        .toList();
    if (mine.isEmpty) return null;
    mine.sort((a, b) {
      final da = DateTime.tryParse(a['submittedAt']?.toString() ?? '') ??
          DateTime(2000);
      final db = DateTime.tryParse(b['submittedAt']?.toString() ?? '') ??
          DateTime(2000);
      return db.compareTo(da);
    });
    return mine.first;
  }

  @override
  void initState() {
    super.initState();
    _formFuture = _formService.getIdCardForm(principalId: widget.principalId);
  }

  void _handleFormDataChange(Map<String, dynamic> data) {
    setState(() {
      _currentFormData = data;
    });
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    try {
      print('[FormSubmission] Submitting form data: $_currentFormData');

      // Convert form data to Map<String, String>
      final formDataStrings = _currentFormData.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );

      final submissionId = await _formService.submitForm(
        principalId: widget.principalId,
        userId: widget.userId,
        userEmail: widget.userEmail,
        userName: widget.userName,
        role: widget.role,
        formData: formDataStrings,
      );

      if (submissionId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Form submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh submissions list after successful submission
          setState(() => _shouldRefreshSubmissions = true);
          // Clear form data
          setState(() => _currentFormData = {});
        }
      } else {
        throw Exception('Submission failed');
      }
    } catch (e) {
      print('[FormSubmission] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit form'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRelevantSubmissions() async {
    print('[FormFill] Fetching submissions for role: ${widget.role}');

    if (widget.role == 'student') {
      // Student sees only their own submissions
      final submissions = await _formService.getUserSubmissions(
        principalId: widget.principalId,
        userId: widget.userId,
      );
      return _filterSubmissionsForRole(submissions);
    } else if (widget.role == 'teacher') {
      // Teacher also sees only their own submissions for this form section
      final submissions = await _formService.getUserSubmissions(
        principalId: widget.principalId,
        userId: widget.userId,
      );
      return _filterSubmissionsForRole(submissions);
    }

    return [];
  }

  List<Map<String, dynamic>> _filterSubmissionsForRole(
      List<Map<String, dynamic>> submissions) {
    if (widget.role != 'student' && widget.role != 'teacher') {
      return submissions;
    }
    return submissions
        .where((sub) => (sub['userId']?.toString() ?? '') == widget.userId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card Form'),
        elevation: 0,
      ),
      body: FutureBuilder<IdCardForm?>(
        future: _formFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load form'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _formFuture = _formService.getIdCardForm(
                          principalId: widget.principalId);
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final form = snapshot.data;
          if (form == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info, size: 48, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text('No form available'),
                  const SizedBox(height: 8),
                  Text(
                    'Please contact your principal to set up the ID card form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchRelevantSubmissions(),
                      builder: (context, submissionsSnap) {
                        final submissions = _filterSubmissionsForRole(
                            submissionsSnap.data ?? []);
                        final hasSubmitted =
                            _hasSubmittedCurrentForm(form, submissions);
                        final latest = _latestMySubmission(submissions);

                        if ((widget.role == 'student' ||
                                widget.role == 'teacher') &&
                            hasSubmitted) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Form submitted',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  latest == null
                                      ? 'Your latest submission is already recorded.'
                                      : 'Submitted at ${_formatDate(latest['submittedAt'])}. You can submit again only after principal updates the form.',
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                                if (latest != null) ...[
                                  const SizedBox(height: 10),
                                  _buildSubmissionPreview(
                                    Map<String, dynamic>.from(
                                        latest['formData'] ?? {}),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return DynamicFormWidget(
                          form: form,
                          onFormDataChange: _handleFormDataChange,
                          onSubmit: _isSubmitting ? null : _submitForm,
                        );
                      },
                    ),

                    const Divider(
                        height: 32, thickness: 2, indent: 16, endIndent: 16),

                    // ── Submissions Section ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.role == 'student' ||
                                    widget.role == 'teacher')
                                ? 'Your Submission Details'
                                : 'Your Submissions',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (widget.role == 'teacher')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Only your submitted details are shown here.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          _shouldRefreshSubmissions
                              ? _buildSubmissionsList()
                              : FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _fetchRelevantSubmissions(),
                                  builder: (context, submSnap) {
                                    if (submSnap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    if (submSnap.hasError) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'Failed to load submissions',
                                          style:
                                              TextStyle(color: Colors.red[600]),
                                        ),
                                      );
                                    }

                                    final submissions =
                                        _filterSubmissionsForRole(
                                            submSnap.data ?? []);
                                    if (submissions.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            children: [
                                              Icon(Icons.info,
                                                  color: Colors.blue[300]),
                                              const SizedBox(height: 8),
                                              Text(
                                                'No submissions yet',
                                                style: TextStyle(
                                                    color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: submissions.length,
                                      itemBuilder: (context, index) {
                                        final sub = submissions[index];
                                        final isMySubmission =
                                            sub['userId'] == widget.userId;

                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          color: isMySubmission
                                              ? Colors.blue.withOpacity(0.05)
                                              : null,
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: isMySubmission
                                                  ? Colors.blue
                                                  : Colors.grey[400],
                                              child: Text(
                                                sub['userName']
                                                            ?.toString()
                                                            .isEmpty ??
                                                        true
                                                    ? '?'
                                                    : sub['userName']
                                                        .toString()[0]
                                                        .toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                            title: Text(
                                                sub['userName'] ?? 'Unknown'),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${(sub['role'] as String?)?.toUpperCase() ?? 'UNKNOWN'} • ${_formatDate(sub['submittedAt'])}',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600]),
                                                ),
                                                if (isMySubmission)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    child: Text(
                                                      '(Your submission)',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.blue[600],
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                if (widget.role == 'student' ||
                                                    widget.role == 'teacher')
                                                  _buildSubmissionPreview(
                                                    Map<String, dynamic>.from(
                                                        sub['formData'] ?? {}),
                                                  ),
                                              ],
                                            ),
                                            trailing: Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey[400]),
                                            onTap: () =>
                                                _showSubmissionDetails(sub),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (_isSubmitting)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmissionsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRelevantSubmissions(),
      builder: (context, submSnap) {
        if (submSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (submSnap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load submissions',
              style: TextStyle(color: Colors.red[600]),
            ),
          );
        }

        final submissions = _filterSubmissionsForRole(submSnap.data ?? []);
        if (submissions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.info, color: Colors.blue[300]),
                  const SizedBox(height: 8),
                  Text(
                    'No submissions yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            final sub = submissions[index];
            final isMySubmission = sub['userId'] == widget.userId;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isMySubmission ? Colors.blue.withOpacity(0.05) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isMySubmission ? Colors.blue : Colors.grey[400],
                  child: Text(
                    sub['userName']?.toString().isEmpty ?? true
                        ? '?'
                        : sub['userName'].toString()[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(sub['userName'] ?? 'Unknown'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(sub['role'] as String?)?.toUpperCase() ?? 'UNKNOWN'} • ${_formatDate(sub['submittedAt'])}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (isMySubmission)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '(Your submission)',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (widget.role == 'student' || widget.role == 'teacher')
                      _buildSubmissionPreview(
                        Map<String, dynamic>.from(sub['formData'] ?? {}),
                      ),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
                onTap: () => _showSubmissionDetails(sub),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubmissionDetails(Map<String, dynamic> submission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(submission['userName'] ?? 'Submission Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Role',
                  (submission['role'] as String?)?.toUpperCase() ?? 'N/A'),
              _buildDetailRow(
                  'Submitted', _formatDate(submission['submittedAt'])),
              const SizedBox(height: 16),
              Text(
                'Form Data:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSubmissionPreview(Map<String, dynamic> formData) {
    final nonEmptyEntries = formData.entries
        .where((entry) =>
            entry.value != null && entry.value.toString().trim().isNotEmpty)
        .toList();

    if (nonEmptyEntries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'No submitted field data',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: nonEmptyEntries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${entry.key}: ${entry.value}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
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
      try {
        final dt = DateTime.parse(date).toLocal();
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final year = dt.year.toString();
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        final second = dt.second.toString().padLeft(2, '0');
        return '$day/$month/$year $hour:$minute:$second';
      } catch (e) {
        return date;
      }
    }
    return 'N/A';
  }
}
