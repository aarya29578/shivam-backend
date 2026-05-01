import 'package:flutter/material.dart';

import '../../../shared/widgets/user_profile_screen.dart';

// -------------------------------------------------------------------
// VENDOR PROFILE SCREEN  Route: /vendor/profile
// Uses real backend data via /api/auth/profile
// -------------------------------------------------------------------

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const SharedUserProfileScreen();
}
