import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../config/supabase_config.dart';

class DeveloperGuideScreen extends StatefulWidget {
  final Map<String, dynamic>? merchantProfile;

  const DeveloperGuideScreen({super.key, this.merchantProfile});

  @override
  State<DeveloperGuideScreen> createState() => _DeveloperGuideScreenState();
}

class _DeveloperGuideScreenState extends State<DeveloperGuideScreen> {
  String _selectedLang = 'JavaScript';
  final List<String> _languages = ['JavaScript', 'cURL', 'Python', 'PHP'];

  String get _rpcBaseUrl {
    final cleanBase = SupabaseConfig.url.replaceAll(RegExp(r'/$'), '');
    return '$cleanBase/rest/v1/rpc';
  }

  String get _gatewayKey => SupabaseConfig.anonKey;

  String get _merchantApiKey =>
      widget.merchantProfile?['api_key']?.toString() ?? 'hk_live_YOUR_API_KEY';

  String get _lipaNamba =>
      widget.merchantProfile?['lipa_namba']?.toString() ?? '70000000';

  String get _recipientName =>
      widget.merchantProfile?['recipient_name']?.toString() ??
      'YOUR REGISTERED ACCOUNT NAME';

  bool get _hasProfile =>
      widget.merchantProfile != null &&
      (widget.merchantProfile?['api_key']?.toString().isNotEmpty ?? false);

  /// Personalized with the merchant's own Lipa Namba & Account Name,
  /// using a strictly generic placeholder customer phone & name.
  String get _sampleTestSms => '''Selcom Pay
$_recipientName
Merchant# $_lipaNamba
TZS 1,000.00
TransID 503-SAMPLE123456
Ref 1967000001
Channel TanQR (M-Pesa)
Payer SAMPLE CUSTOMER (0700***3456)
20/11/2026 10:30:00 AM''';

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  String _startVerificationSnippet() {
    final url = '$_rpcBaseUrl/start_payment_verification';
    switch (_selectedLang) {
      case 'JavaScript':
        return '''// You can rename this function to fit your app (e.g. initiateOrderPayment)
async function startPaymentVerification(amount, payerIdentifier, orderId) {
  const res = await fetch("$url", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": "$_gatewayKey"
    },
    body: JSON.stringify({
      _api_key: "$_merchantApiKey",
      _source_type: "order",
      _amount: amount,                 // e.g. 1000 (TZS integer)
      _payer_identifier: payerIdentifier, // e.g. "0700123456"
      _external_user_id: orderId,      // Optional: your order/user ID
      _external_user_email: "customer@example.com" // Optional
    })
  });

  return await res.json();
  // Returns: { "id": "transaction-uuid", "status": "pending" | "verified" }
}''';

      case 'Python':
        return '''import requests

# You can rename this function to fit your app (e.g. initiate_order_payment)
def start_payment_verification(amount, payer_identifier, order_id=None):
    res = requests.post(
        "$url",
        headers={
            "Content-Type": "application/json",
            "apikey": "$_gatewayKey",
        },
        json={
            "_api_key": "$_merchantApiKey",
            "_source_type": "order",
            "_amount": amount,  # e.g. 1000 (TZS integer)
            "_payer_identifier": payer_identifier,  # e.g. "0700123456"
            "_external_user_id": order_id,  # Optional
            "_external_user_email": "customer@example.com",  # Optional
        },
    )
    return res.json()
    # Returns: {"id": "transaction-uuid", "status": "pending" | "verified"}''';

      case 'PHP':
        return '''// You can rename this function to fit your app (e.g. initiateOrderPayment)
function startPaymentVerification(\$amount, \$payerIdentifier, \$orderId = null) {
    \$ch = curl_init("$url");
    curl_setopt_array(\$ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Content-Type: application/json",
            "apikey: $_gatewayKey"
        ],
        CURLOPT_POSTFIELDS => json_encode([
            "_api_key" => "$_merchantApiKey",
            "_source_type" => "order",
            "_amount" => \$amount,                 // e.g. 1000
            "_payer_identifier" => \$payerIdentifier, // e.g. "0700123456"
            "_external_user_id" => \$orderId,      // Optional
            "_external_user_email" => "customer@example.com" // Optional
        ])
    ]);
    return json_decode(curl_exec(\$ch), true);
    // Returns: ["id" => "transaction-uuid", "status" => "pending" | "verified"]
}''';

      case 'cURL':
      default:
        return '''curl -X POST "$url" \\
  -H "Content-Type: application/json" \\
  -H "apikey: $_gatewayKey" \\
  -d '{
    "_api_key": "$_merchantApiKey",
    "_source_type": "order",
    "_amount": 1000,
    "_payer_identifier": "0700123456",
    "_external_user_id": "order_001",
    "_external_user_email": "customer@example.com"
  }' ''';
    }
  }

  String _checkStatusSnippet() {
    final url = '$_rpcBaseUrl/get_payment_status';
    switch (_selectedLang) {
      case 'JavaScript':
        return '''// Poll this every 3-5 seconds until status === "verified"
async function getPaymentStatus(transactionId) {
  const res = await fetch("$url", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": "$_gatewayKey"
    },
    body: JSON.stringify({
      _api_key: "$_merchantApiKey",
      _transaction_id: transactionId
    })
  });

  return await res.json();
  // Returns: { "id": "...", "status": "pending" | "verified", "payment_reference": "..." }
}''';

      case 'Python':
        return '''import requests

# Poll this every 3-5 seconds until status == "verified"
def get_payment_status(transaction_id):
    res = requests.post(
        "$url",
        headers={
            "Content-Type": "application/json",
            "apikey": "$_gatewayKey",
        },
        json={
            "_api_key": "$_merchantApiKey",
            "_transaction_id": transaction_id,
        },
    )
    return res.json()
    # Returns: {"id": "...", "status": "pending" | "verified", "payment_reference": "..."}''';

      case 'PHP':
        return '''// Poll this every 3-5 seconds until status === "verified"
function getPaymentStatus(\$transactionId) {
    \$ch = curl_init("$url");
    curl_setopt_array(\$ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            "Content-Type: application/json",
            "apikey: $_gatewayKey"
        ],
        CURLOPT_POSTFIELDS => json_encode([
            "_api_key" => "$_merchantApiKey",
            "_transaction_id" => \$transactionId
        ])
    ]);
    return json_decode(curl_exec(\$ch), true);
    // Returns: ["id" => "...", "status" => "pending" | "verified", "payment_reference" => "..."]
}''';

      case 'cURL':
      default:
        return '''curl -X POST "$url" \\
  -H "Content-Type: application/json" \\
  -H "apikey: $_gatewayKey" \\
  -d '{
    "_api_key": "$_merchantApiKey",
    "_transaction_id": "PASTE_TRANSACTION_ID_HERE"
  }' ''';
    }
  }

  String _buildFullShareableGuide() {
    return '''=== HAKIKIPAY MERCHANT INTEGRATION GUIDE ===

HOW IT WORKS
1. Your app displays your Selcom Lipa Namba (#$_lipaNamba - $_recipientName) and the order total.
2. Customer pays via M-Pesa, Mixx by Yas, Airtel Money, or Bank, then enters their phone number, bank name, or receipt ref in your app.
3. Your backend calls POST /start_payment_verification. HakikiPay returns a transaction "id" and "status".
4. Your Android phone running HakikiPay reads the incoming Selcom SMS and marks the transaction "verified".
5. Your backend polls POST /get_payment_status every 3-5 seconds and unlocks the order once status is "verified".

YOUR CREDENTIALS
1. Base URL (Where you send requests):
   $_rpcBaseUrl
2. Gateway Header (Put in HTTP Header "apikey" on every call):
   $_gatewayKey
3. Merchant Secret Key (Put in JSON body as "_api_key" on every call — keep on backend only):
   $_merchantApiKey

ENDPOINT 1: START VERIFICATION
POST $_rpcBaseUrl/start_payment_verification
Headers:
  Content-Type: application/json
  apikey: $_gatewayKey
Body:
{
  "_api_key": "$_merchantApiKey",
  "_source_type": "order",
  "_amount": 1000,
  "_payer_identifier": "0700123456",
  "_external_user_id": "order_001",
  "_external_user_email": "customer@example.com"
}

ENDPOINT 2: CHECK PAYMENT STATUS
POST $_rpcBaseUrl/get_payment_status
Headers:
  Content-Type: application/json
  apikey: $_gatewayKey
Body:
{
  "_api_key": "$_merchantApiKey",
  "_transaction_id": "<id_from_endpoint_1>"
}

MANUAL TEST SMS (Paste inside HakikiPay App Dashboard)
$_sampleTestSms
''';
  }

  Widget _sectionHeader(String badge, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.steel1,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialBlock({
    required String title,
    required String whereUsed,
    required String explanation,
    required String value,
    required String copyLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  whereUsed,
                  style: const TextStyle(fontSize: 10, color: AppTheme.steel1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: AppTheme.steel1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copy(value, copyLabel),
                  child: const Icon(Icons.copy_rounded, size: 17, color: AppTheme.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBlock(String title, String code) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedFg,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _copy(code, title),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: AppTheme.steel1),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(fontSize: 11, color: AppTheme.steel1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.45,
                color: AppTheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paramItem(String name, String type, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '($type) — $desc',
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String number, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppTheme.secondary,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration & Testing Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: 'Copy Full Guide to Share',
            onPressed: () => _copy(_buildFullShareableGuide(), 'Full integration guide'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          if (!_hasProfile)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Save your Lipa Namba in Merchant Configuration first so your real API Key and personalized test SMS auto-fill below.',
                style: TextStyle(fontSize: 12, color: Colors.amber),
              ),
            ),

          // ===================================================================
          // OVERVIEW: PLAIN-ENGLISH EXPLANATION FIRST
          // ===================================================================
          _sectionHeader('OVERVIEW', 'How HakikiPay Works With Your App'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HakikiPay connects your Selcom Lipa Namba SMS alerts directly to your website or mobile app so customer payments verify automatically.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.foreground, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  _stepRow(
                    '1',
                    'Customer pays your Lipa Namba',
                    'Your app shows your Lipa Namba (#$_lipaNamba) and order amount. The customer sends money via M-Pesa, Mixx by Yas, Airtel Money, or Bank.',
                  ),
                  _stepRow(
                    '2',
                    'Your app asks HakikiPay to watch for the payment',
                    'The customer enters their phone number, bank account name, or receipt reference in your app. Your backend sends that info + exact amount to HakikiPay.',
                  ),
                  _stepRow(
                    '3',
                    'This Android app reads your Selcom SMS',
                    'When Selcom sends the confirmation SMS to your phone, HakikiPay automatically parses it and matches the amount and payer.',
                  ),
                  _stepRow(
                    '4',
                    'Your app unlocks the order automatically',
                    'Your backend checks the status every few seconds. As soon as HakikiPay responds with "verified", your app completes the checkout.',
                  ),
                  const Divider(height: 22, color: AppTheme.border),
                  const Text(
                    'What HakikiPay gives you:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _bulletPoint('3 connection credentials (Base URL, Gateway Header, Merchant Secret Key).'),
                  _bulletPoint('2 simple API endpoints: one to start verification, one to check status.'),
                  _bulletPoint('A real-time status response ("pending" or "verified") plus the Selcom receipt reference.'),
                  const SizedBox(height: 10),
                  const Text(
                    'What your app must send to HakikiPay:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _bulletPoint('Your Merchant Secret Key (_api_key) so we know the payment belongs to you.'),
                  _bulletPoint('The exact expected amount in TZS (_amount, whole numbers only).'),
                  _bulletPoint('The customer identifier (_payer_identifier): phone number, 2+ word bank name, or Selcom TransID/Ref.'),
                  _bulletPoint('A short label (_source_type) describing what they bought (e.g. "order", "ticket", "subscription").'),
                ],
              ),
            ),
          ),

          // ===================================================================
          // STEP 1: CONNECTION CREDENTIALS EXPLAINED
          // ===================================================================
          _sectionHeader('STEP 1', 'Your 3 Connection Credentials'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Every time your app talks to HakikiPay (both when starting verification AND when checking payment status), it uses all 3 values below from your backend server:',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  _credentialBlock(
                    title: '1. Base URL',
                    whereUsed: 'Request URL',
                    explanation:
                        'The server address where your backend sends POST requests. Add /start_payment_verification or /get_payment_status to the end of this URL.',
                    value: _rpcBaseUrl,
                    copyLabel: 'Base URL',
                  ),
                  _credentialBlock(
                    title: '2. Gateway Header (apikey)',
                    whereUsed: 'HTTP Header',
                    explanation:
                        'The public front-door key that lets your request reach the HakikiPay server. Always include it as an HTTP header named "apikey" on every call.',
                    value: _gatewayKey,
                    copyLabel: 'Gateway Header',
                  ),
                  _credentialBlock(
                    title: '3. Merchant Secret Key (_api_key)',
                    whereUsed: 'JSON Body',
                    explanation:
                        'Your private account key linked to Lipa Namba #$_lipaNamba. Put this inside the JSON body on every call. Keep it strictly on your backend server — never expose it in public browser/mobile code.',
                    value: _merchantApiKey,
                    copyLabel: 'Merchant Secret Key',
                  ),
                ],
              ),
            ),
          ),

          // ===================================================================
          // STEP 2 & 3: CODE SNIPPETS
          // ===================================================================
          const SizedBox(height: 18),
          const Text(
            'CHOOSE YOUR BACKEND LANGUAGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppTheme.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _languages.map((lang) {
              final selected = _selectedLang == lang;
              return ChoiceChip(
                label: Text(lang, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primaryFg : AppTheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _selectedLang = lang),
              );
            }).toList(),
          ),

          _sectionHeader('STEP 2', 'Start Payment Verification (At Checkout)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Call this from your backend the moment the customer clicks "I Have Paid". The function name in your own code can be anything you prefer (e.g., startPaymentVerification, initiateOrderPayment, or createPaymentIntent).',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _paramItem('_api_key', 'required', 'Your secret hk_live_... Merchant Key.'),
                  _paramItem('_amount', 'required, integer', 'Exact TZS amount expected (no commas or decimals, e.g. 1000).'),
                  _paramItem('_payer_identifier', 'required', 'Customer phone (e.g. "0700123456"), bank name (2+ words), or TransID/Ref.'),
                  _paramItem('_source_type', 'required', 'Any short category label for your records (e.g. "order", "booking", "ticket").'),
                  _paramItem('_external_user_id', 'optional', 'Your app\'s order ID or customer ID.'),
                  _paramItem('_external_user_email', 'optional', 'Customer email for your logs.'),
                  _codeBlock(
                    'POST /start_payment_verification ($_selectedLang)',
                    _startVerificationSnippet(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Fast-path tip: If the Selcom SMS arrived before the customer clicked Verify, this call immediately returns {"status": "verified"} — unlock their order right away!',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.emerald, height: 1.35),
                  ),
                ],
              ),
            ),
          ),

          _sectionHeader('STEP 3', 'Check Payment Status (Until Verified)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'If Step 2 returns {"status": "pending"}, save the returned "id" and call this endpoint every 3–5 seconds until "status" changes to "verified":',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
                  ),
                  _codeBlock(
                    'POST /get_payment_status ($_selectedLang)',
                    _checkStatusSnippet(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Bonus endpoint: POST /list_merchant_transactions with {"_api_key": "..."} returns your latest 200 transactions for your admin dashboard.',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.mutedFg),
                  ),
                ],
              ),
            ),
          ),

          // ===================================================================
          // STEP 4: MANUAL TESTING (ZERO COST)
          // ===================================================================
          _sectionHeader('STEP 4', 'How to Test Manually (No Real Money)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Before sending real money, simulate a full checkout using the Paste SMS tool built into this app:',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    '1',
                    'Send a test request from your app',
                    'Call /start_payment_verification with _amount: 1000 and _payer_identifier: "0700123456". Save the returned transaction "id" (status will be "pending").',
                  ),
                  _stepRow(
                    '2',
                    'Copy your personalized sample SMS below',
                    'This fake SMS uses your real Lipa Namba (#$_lipaNamba) and Registered Name ($_recipientName), with a sample customer number (0700***3456) paying TZS 1,000.',
                  ),
                  _stepRow(
                    '3',
                    'Paste it in the HakikiPay Dashboard',
                    'Go back to the main Dashboard, tap the Paste icon in the top bar, paste the sample SMS, and tap "Parse & Verify".',
                  ),
                  _stepRow(
                    '4',
                    'Confirm automatic unlock',
                    'The Dashboard log will show "VERIFIED & UNLOCKED!", and calling /get_payment_status with your transaction "id" will now return "verified".',
                  ),
                  _codeBlock('Sample Test SMS (For Lipa #$_lipaNamba)', _sampleTestSms),
                ],
              ),
            ),
          ),

          // ===================================================================
          // STEP 5: REAL-TIME LIVE TESTING & GO-LIVE
          // ===================================================================
          _sectionHeader('STEP 5', 'Go Live: Real-Time SMS Verification'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Once manual testing succeeds, prepare the Android phone that receives your Selcom Lipa Namba SMS messages:',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedFg, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    '1',
                    'Enable SMS Permissions (Android 13–15)',
                    'If SMS permission is blocked, open Phone Settings → Apps → HakikiPay → tap the 3 dots (top right) → Allow restricted settings, then turn on SMS permission.',
                  ),
                  _stepRow(
                    '2',
                    'Set Battery Usage to Unrestricted',
                    'Open Phone Settings → Apps → HakikiPay → Battery → select "Unrestricted" so the phone listens for incoming Selcom SMS messages even when the screen is off.',
                  ),
                  _stepRow(
                    '3',
                    'Run one small live transaction',
                    'Trigger a real checkout in your app for TZS 100–200, send that exact amount to Lipa Namba #$_lipaNamba from your mobile money wallet, and watch HakikiPay verify and unlock it automatically within seconds.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}