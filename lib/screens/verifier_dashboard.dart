// Dedicated dashboard managing the real-time listener, 15s cron sweep, and manual paste dialog

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_theme.dart';
import '../services/background_sms_handler.dart';
import '../services/selcom_parser.dart';
import 'merchant_config_screen.dart';
import 'super_admin_screen.dart';

class VerifierDashboard extends StatefulWidget {
  const VerifierDashboard({super.key});

  @override
  State<VerifierDashboard> createState() => _VerifierDashboardState();
}

class _VerifierDashboardState extends State<VerifierDashboard> {
  final Telephony? telephony = Platform.isAndroid ? Telephony.instance : null;
  Timer? _cronTimer;
  bool _isSyncing = false;
  bool _listenerActive = false;
  DateTime? _lastSweepAt;
  final List<String> _logs = [];
  bool _isSuperAdmin = false;

  Map<String, dynamic>? _merchantProfile;
  bool _loadingProfile = true;

  String get _configuredLipa => _merchantProfile?['lipa_namba']?.toString() ?? '';
  String get _configuredRecipient => _merchantProfile?['recipient_name']?.toString() ?? '';
  String get _businessName => _merchantProfile?['business_name']?.toString() ?? 'Unconfigured';

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  @override
  void dispose() {
    _cronTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    await _loadMerchantProfile();
    if (Platform.isAndroid) {
      await _initAndroidSmsListeners();
    } else {
      _addLog('ℹ️ iOS Mode: Use Paste icon to test or verify SMS.');
    }
  }

  Future<void> _loadMerchantProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Attempt to claim super admin (promotes the first user automatically)
      try {
        await Supabase.instance.client.rpc('claim_super_admin');
      } catch (_) {}

      // 2. Check if current user has super_admin role
      final adminCheck = await Supabase.instance.client.rpc('has_role', params: {
        '_user_id': user.id,
        '_role': 'super_admin',
      });
      if (mounted) setState(() => _isSuperAdmin = adminCheck == true);

      // 3. Load merchant profile data
      final data = await Supabase.instance.client
          .from('merchant_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('merchant_lipa_namba', data['lipa_namba'] ?? '');
        await prefs.setString('merchant_recipient_name', data['recipient_name'] ?? '');
        if (mounted) setState(() => _merchantProfile = data);
      }
    } catch (e) {
      _addLog('⚠️ Profile load warning: $e');
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _openConfigScreen() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantConfigScreen(initialProfile: _merchantProfile),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _merchantProfile = updated);
      _addLog('✅ Updated config: Lipa #${updated['lipa_namba']} (${updated['recipient_name']})');
      if (Platform.isAndroid) _sweepInbox();
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, '[$time] $msg');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _initAndroidSmsListeners() async {
    final granted = await telephony?.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      _addLog('⚠️ SMS Permissions denied. Grant SMS permissions in Android Settings.');
      return;
    }

    telephony!.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        _processSms(message.address, message.body, source: 'LIVE');
      },
      onBackgroundMessage: backgroundSmsHandler,
    );

    setState(() => _listenerActive = true);
    _addLog('✅ Listening for "Selcom" & "Selcom Pesa" SMS.');

    await _sweepInbox();
    _cronTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sweepInbox());
  }

  Future<void> _sweepInbox() async {
    if (!Platform.isAndroid || _isSyncing || telephony == null) return;
    if (_configuredLipa.isEmpty) return;

    setState(() => _isSyncing = true);
    try {
      final messages = await telephony!.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      for (final msg in messages.take(30)) {
        await _processSms(msg.address, msg.body, source: 'CRON');
      }
      if (mounted) setState(() => _lastSweepAt = DateTime.now());
    } catch (e) {
      _addLog('Sweep error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _processSms(String? sender, String? body, {required String source}) async {
    if (_configuredLipa.isEmpty) {
      if (source == 'MANUAL') {
        _addLog('⚠️ Configure your Lipa Namba in Settings before verifying.');
      }
      return;
    }

    final parsed = SelcomPaymentSms.tryParse(sender, body);
    if (parsed == null) return;

    if (!parsed.matchesMerchant(
      configuredLipaNamba: _configuredLipa,
      configuredRecipientName: _configuredRecipient,
    )) {
      if (source == 'MANUAL') {
        _addLog(
          '⚠️ Ignored SMS: Merchant# ${parsed.merchantNumber ?? "?"} does not match your configured Lipa Namba ($_configuredLipa).',
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final syncedRefs = prefs.getStringList('synced_refs') ?? [];

    if (source == 'CRON' && syncedRefs.contains(parsed.reference)) {
      return;
    }

    try {
      final matchedTxId = await Supabase.instance.client.rpc(
        'record_and_match_selcom_sms',
        params: {
          '_reference': parsed.reference,
          '_selcom_ref': parsed.selcomRef,
          '_amount': parsed.amount,
          '_sender_name': parsed.senderName,
          '_channel': parsed.channel,
          '_sender_phone': parsed.rawPhone,
          '_phone_prefix3': parsed.phonePrefix3,
          '_phone_last4': parsed.phoneLast4,
          '_tx_timestamp': parsed.transactionTime,
        },
      );

      if (!syncedRefs.contains(parsed.reference)) {
        syncedRefs.add(parsed.reference);
        await prefs.setStringList('synced_refs', syncedRefs);
      }

      if (matchedTxId != null) {
        _addLog(
            '🎉 [$source] VERIFIED & UNLOCKED! TZS ${parsed.amount} • ${parsed.senderName} (${parsed.rawPhone}) • TransID: ${parsed.reference}');
      } else {
        _addLog(
            '📥 [$source] Synced TZS ${parsed.amount} • ${parsed.senderName} (${parsed.rawPhone}) • TransID: ${parsed.reference}');
      }
    } catch (e) {
      _addLog('❌ Sync error (${parsed.reference}): $e');
    }
  }

  Future<void> _showManualPasteDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test / Paste Selcom SMS'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste a Selcom Pay or Selcom Pesa SMS here...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text;
              Navigator.pop(ctx);
              _processSms('Selcom', text, source: 'MANUAL');
            },
            child: const Text('Parse & Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasConfig = _configuredLipa.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 17, color: AppTheme.steel1),
            ),
            const SizedBox(width: 10),
            const Text('HakikiPay'),
          ],
        ),
        actions: [
          if (_isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: AppTheme.emerald),
              tooltip: 'Super Admin Insights',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuperAdminScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.paste_rounded, size: 20),
            tooltip: 'Paste / Test SMS',
            onPressed: _showManualPasteDialog,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Merchant Configuration',
            onPressed: _openConfigScreen,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_loadingProfile && !hasConfig)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Set up your Selcom Lipa Namba & Recipient Name to start verifying transactions.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _openConfigScreen,
                      child: const Text('Configure'),
                    ),
                  ],
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: (_listenerActive && hasConfig) ? AppTheme.emerald : Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hasConfig
                                  ? '$_businessName • Lipa #$_configuredLipa'
                                  : 'Awaiting Merchant Setup',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _openConfigScreen,
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.steel1,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasConfig) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Recipient: $_configuredRecipient',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppTheme.mutedFg,
                        ),
                      ),
                    ],
                    if (Platform.isAndroid) ...[
                      const Divider(height: 22, color: AppTheme.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _lastSweepAt != null
                                  ? 'Last sweep: ${_lastSweepAt!.toLocal().toString().substring(11, 19)}'
                                  : '15s inbox cron active',
                              style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: (_isSyncing || !hasConfig) ? null : _sweepInbox,
                            icon: const Icon(Icons.sync_rounded, size: 16),
                            label: Text(_isSyncing ? 'Scanning...' : 'Sweep Now'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'LIVE VERIFICATION LOG',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 1.1,
                color: AppTheme.mutedFg,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No Selcom messages processed yet.',
                          style: TextStyle(color: AppTheme.mutedFg, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 14, color: AppTheme.border),
                        itemBuilder: (_, idx) => Text(
                          _logs[idx],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}