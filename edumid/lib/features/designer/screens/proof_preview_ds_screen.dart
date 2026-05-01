import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_widgets.dart';

class ProofPreviewDsScreen extends StatelessWidget {
  final String projectId;
  const ProofPreviewDsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Proof Preview – $projectId')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 300,
                height: 420,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.error, size: 64),
                    const SizedBox(height: 16),
                    Text('Proof Document',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.black87,
                        )),
                    const SizedBox(height: 4),
                    Text('Tap to zoom',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.black54,
                        )),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GradientButton(
              label: 'Submit for Approval',
              onTap: () => context.go('/designer/$projectId/submit-proof'),
            ),
          ),
        ],
      ),
    );
  }
}
