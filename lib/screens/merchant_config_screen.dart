import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hakiki_pay/screens/developer_guide_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_theme.dart';
import '../utils/error_helper.dart';

class MerchantConfigScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const MerchantConfigScreen({super.key, this.initialProfile});

  @override
  State<MerchantConfigScreen> createState() => _MerchantConfigScreenState();
}

class _MerchantConfigScreenState extends State<MerchantConfigScreen> {
  final _businessCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _lipaCtrl = TextEditingController();

  bool _saving = false;
  String? _apiKey;
  String _plan = 'trial';
  String _status = 'active';
  String? _expiresAt;

  @override
  void initState() {
    super.initState();
    _populateFromProfile(widget.initialProfile);
    if (widget.initialProfile == null) {
      _loadProfile();
    }
  }

  void _populateFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return;
    _businessCtrl.text = profile['business_name']?.toString() ?? '';
    _recipientCtrl.text = profile['recipient_name']?.toString() ?? '';
    _lipaCtrl.text = profile['lipa_namba']?.toString() ?? '';
    _apiKey = profile['api_key']?.toString();
    _plan = profile['subscription_plan']?.toString() ?? 'trial';
    _status = profile['subscription_status']?.toString() ?? 'active';
    _expiresAt = profile['subscription_expires_at']?.toString();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('merchant_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (mounted && data != null) {
      setState(() => _populateFromProfile(data));
    }
  }

  Future<void> _saveConfig() async {
    final business = _businessCtrl.text.trim();
    final recipient = _recipientCtrl.text.trim().toUpperCase();
    final lipa = _lipaCtrl.text.trim();

    if (recipient.isEmpty || lipa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both your Lipa Namba and Recipient Name.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final saved = await Supabase.instance.client
          .from('merchant_profiles')
          .upsert(
            {
              'user_id': user.id,
              'email': user.email,
              'business_name': business.isEmpty ? 'My Business' : business,
              'recipient_name': recipient,
              'lipa_namba': lipa,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id',
          )
          .select()
          .single();

      // Cache locally for the background SMS listener isolate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('merchant_lipa_namba', lipa);
      await prefs.setString('merchant_recipient_name', recipient);
      await prefs.setString('merchant_business_name', business);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved!')),
        );
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _recipientCtrl.dispose();
    _lipaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Configuration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subscription Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.steel1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Plan: ${_plan.toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _status == 'active'
                                      ? AppTheme.emerald.withValues(alpha: 0.15)
                                      : Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _status == 'active' ? AppTheme.emerald : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _expiresAt != null
                                ? 'Valid until ${_expiresAt!.substring(0, 10)}'
                                : '14-day free trial included on setup',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Parsing Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selcom Lipa Namba Details',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'HakikiPay uses these details to filter incoming Selcom SMS alerts on your phone and verify payments for your app.',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedFg),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _businessCtrl,
                      decoration: const InputDecoration(
                        labelText: 'App / Business Name',
                        hintText: 'e.g., My Online Shop',
                        prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _lipaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Selcom Lipa Namba (Merchant #) *',
                        hintText: 'e.g., 70012345',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _recipientCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Registered Recipient Name (as shown in SMS) *',
                        hintText: 'e.g., JANE DOE JOHN',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveConfig,
                        child: Text(_saving ? 'Saving...' : 'Save Configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Developer API Key Card (shown once profile is saved)
            if (_apiKey != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Developer Integration Key',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use this key alongside your Lipa Namba to connect your website or mobile app to HakikiPay.',
                        style: TextStyle(fontSize: 12, color: AppTheme.mutedFg),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _apiKey!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppTheme.steel1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _apiKey!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('API Key copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton.icon(
                       onPressed: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => DeveloperGuideScreen(
                               merchantProfile: {
                                 'api_key': _apiKey,
                                 'lipa_namba': _lipaCtrl.text.trim(),
                                 'recipient_name': _recipientCtrl.text.trim().toUpperCase(),
                               },
                             ),
                           ),
                         );
                       },
                       icon: const Icon(Icons.code_rounded, size: 18),
                       label: const Text('Open Integration & Testing Guide'),
                     ),
                   ),
          ],
        ),
      ),
    );
  }
}