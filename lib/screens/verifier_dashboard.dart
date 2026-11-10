// Dedicated dashboard managing the real-time listener, 15s cron sweep, and manual paste dialog

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/background_sms_handler.dart';
import '../services/selcom_parser.dart';

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

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _initAndroidSmsListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addLog('ℹ️ Running on iOS: Use "Paste SMS" icon to test or verify manually.');
      });
    }
  }

  @override
  void dispose() {
    _cronTimer?.cancel();
    super.dispose();
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
    final parsed = SelcomPaymentSms.tryParse(sender, body);
    if (parsed == null) return;

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
            border: OutlineInputBorder(),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('HakikiPay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste_rounded),
            tooltip: 'Paste / Test SMS',
            onPressed: _showManualPasteDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: _listenerActive ? const Color(0xFF10B981) : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            Platform.isAndroid
                                ? (_listenerActive
                                    ? 'Listening: "Selcom" & "Selcom Pesa" (15s Cron)'
                                    : 'Waiting for SMS permission...')
                                : 'iOS Mode (Manual / Shortcut Sync)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lastSweepAt != null
                            ? 'Last inbox sweep: ${_lastSweepAt!.toLocal().toString().substring(0, 19)}'
                            : 'Initial sweep pending...',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _isSyncing ? null : _sweepInbox,
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(_isSyncing ? 'Scanning Inbox...' : 'Sweep Inbox Now'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Live Verification Log', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No Selcom messages processed yet.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.white10),
                        itemBuilder: (_, idx) => Text(
                          _logs[idx],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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