import 'package:flutter/material.dart';

import '../../../shared/widgets/user_profile_screen.dart';

// -------------------------------------------------------------------
// STUDENT OWN PROFILE SCREEN
// Route: /student/profile
// Delegates to the shared UserProfileScreen which fetches real data
// from the backend via /api/auth/profile.
// -------------------------------------------------------------------

class StudentOwnProfileScreen extends StatelessWidget {
  const StudentOwnProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const SharedUserProfileScreen();
}
