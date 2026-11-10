// Routes between AdminLoginScreen and VerifierDashboard based on auth state

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_login_screen.dart';
import 'verifier_dashboard.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() => _session = data.session);
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const AdminLoginScreen();
    }
    return const VerifierDashboard();
  }
}