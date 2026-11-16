import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_theme.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.rpc('get_super_admin_overview');
      if (mounted) {
        setState(() => _overview = Map<String, dynamic>.from(res as Map));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateMerchantSub(
    String userId,
    String plan,
    String status,
    int days,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_update_merchant_subscription',
        params: {
          '_merchant_user_id': userId,
          '_plan': plan,
          '_status': status,
          '_days_to_extend': days,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated merchant subscription to $status ($plan)')),
        );
      }
      await _loadOverview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Widget _buildKpi(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.mutedFg)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final merchants = (_overview?['merchants'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin • Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOverview,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOverview,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _buildKpi('Total Merchants', '${_overview?['total_merchants'] ?? 0}'),
                          const SizedBox(width: 10),
                          _buildKpi('Active Plans', '${_overview?['active_merchants'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildKpi('Verified Payments', '${_overview?['total_verified_tx'] ?? 0}'),
                          const SizedBox(width: 10),
                          _buildKpi('Verified Volume', 'TZS ${_overview?['total_verified_volume'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'INTEGRATED MERCHANTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: AppTheme.mutedFg,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (merchants.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('No merchants configured yet.', style: TextStyle(color: AppTheme.mutedFg)),
                            ),
                          ),
                        ),
                      ...merchants.map((raw) {
                        final m = Map<String, dynamic>.from(raw as Map);
                        final isActive = m['subscription_status'] == 'active';
                        final expires = (m['subscription_expires_at']?.toString() ?? '').substring(0, 10);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${m['business_name']} • Lipa #${m['lipa_namba']}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? AppTheme.emerald.withValues(alpha: 0.15)
                                              : Colors.redAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${m['subscription_plan']} • ${m['subscription_status']}'.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isActive ? AppTheme.emerald : Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${m['email']} • Recipient: ${m['recipient_name']}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Verified: ${m['verified_count']} tx (TZS ${m['verified_volume']}) • SMS Synced: ${m['sms_count']} • Expires: $expires',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: AppTheme.steel1,
                                    ),
                                  ),
                                  const Divider(height: 22, color: AppTheme.border),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _updateMerchantSub(
                                          m['user_id'].toString(),
                                          'monthly',
                                          'active',
                                          30,
                                        ),
                                        child: const Text('+30d Monthly', style: TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isActive)
                                        TextButton(
                                          onPressed: () => _updateMerchantSub(
                                            m['user_id'].toString(),
                                            m['subscription_plan'].toString(),
                                            'suspended',
                                            0,
                                          ),
                                          child: const Text(
                                            'Suspend',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}