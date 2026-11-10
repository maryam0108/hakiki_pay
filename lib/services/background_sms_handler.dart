// Handles incoming SMS when the app is minimized or the screen is locked:
import 'package:flutter/widgets.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'selcom_parser.dart';

@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  final parsed = SelcomPaymentSms.tryParse(message.address, message.body);
  if (parsed == null) return;

  try {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (_) {}

  try {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    await client.rpc('record_and_match_selcom_sms', params: {
      '_reference': parsed.reference,
      '_selcom_ref': parsed.selcomRef,
      '_amount': parsed.amount,
      '_sender_name': parsed.senderName,
      '_channel': parsed.channel,
      '_sender_phone': parsed.rawPhone,
      '_phone_prefix3': parsed.phonePrefix3,
      '_phone_last4': parsed.phoneLast4,
      '_tx_timestamp': parsed.transactionTime,
    });

    final prefs = await SharedPreferences.getInstance();
    final synced = prefs.getStringList('synced_refs') ?? [];
    if (!synced.contains(parsed.reference)) {
      synced.add(parsed.reference);
      await prefs.setStringList('synced_refs', synced);
    }
  } catch (_) {}
}