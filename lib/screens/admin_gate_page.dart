import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import 'admin_dashboard_page.dart';
import 'admin_login_page.dart';

/// The only identity allowed into the admin dashboard. Enforced for real by
/// the matching check in firestore.rules — this client-side check is just
/// what decides which screen to show, not what makes writes secure.
const String kAdminEmail = 'cheikhmow10@gmail.com';

/// Routed at /admin. Storefront users never see this — MainScreen has no
/// link or gesture pointing here.
class AdminGatePage extends StatelessWidget {
  const AdminGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const AdminLoginPage();
        }

        if (user.email != kAdminEmail) {
          // No public sign-up exists, so this shouldn't happen — defense in
          // depth only. Defer signOut() to after this frame so we don't
          // trigger a new stream emission mid-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const _AdminLoadingScreen();
        }

        return const AdminDashboardPage();
      },
    );
  }
}

class _AdminLoadingScreen extends StatelessWidget {
  const _AdminLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
