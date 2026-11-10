// Parses both multi-line Selcom Pay (Lipa Namba / TanQR) and single-line Selcom Pesa messages

class SelcomPaymentSms {
  final String reference;
  final String? selcomRef;
  final int amount;
  final String senderName;
  final String channel;
  final String rawPhone;
  final String phonePrefix3;
  final String phoneLast4;
  final String transactionTime;

  SelcomPaymentSms({
    required this.reference,
    this.selcomRef,
    required this.amount,
    required this.senderName,
    required this.channel,
    required this.rawPhone,
    required this.phonePrefix3,
    required this.phoneLast4,
    required this.transactionTime,
  });

  static ({String prefix3, String last4}) extractPhoneParts(String raw) {
    final trimmed = raw.trim();

    if (trimmed.contains('*')) {
      final parts = trimmed.split(RegExp(r'\*+'));
      final leftDigits = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
      final rightDigits = parts.last.replaceAll(RegExp(r'[^0-9]'), '');

      final last4 = rightDigits.length >= 4
          ? rightDigits.substring(rightDigits.length - 4)
          : rightDigits;

      String prefix3 = '';
      if (leftDigits.startsWith('0') && leftDigits.length >= 4) {
        prefix3 = leftDigits.substring(1, 4);
      } else if (leftDigits.startsWith('255') && leftDigits.length >= 6) {
        prefix3 = leftDigits.substring(3, 6);
      }
      return (prefix3: prefix3, last4: last4);
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    String prefix3 = '';
    if (digits.length >= 9) {
      final last9 = digits.substring(digits.length - 9);
      prefix3 = last9.substring(0, 3);
    }
    return (prefix3: prefix3, last4: last4);
  }

  static SelcomPaymentSms? tryParse(String? sender, String? body) {
    if (body == null || body.trim().isEmpty) return null;
    final text = body.trim();

    // Format 1: Multi-line "Selcom Pay" (Lipa Namba / TanQR)
    if (text.toLowerCase().startsWith('selcom pay')) {
      final amountMatch = RegExp(r'TZS\s+([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(text);
      final transIdMatch = RegExp(r'TransID\s+([^\r\n]+)', caseSensitive: false).firstMatch(text);
      final refMatch = RegExp(r'Ref\s+([^\r\n]+)', caseSensitive: false).firstMatch(text);
      final channelMatch = RegExp(r'Channel\s+([^\r\n]+)', caseSensitive: false).firstMatch(text);
      final payerMatch = RegExp(r'Payer\s+(.+?)\s*\(([^)]+)\)', caseSensitive: false).firstMatch(text);
      final fromMatch = RegExp(r'From\s+([0-9+]+)', caseSensitive: false).firstMatch(text);
      final timeMatch = RegExp(r'(\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}:\d{2}\s*[AP]M)', caseSensitive: false).firstMatch(text);

      if (amountMatch == null || transIdMatch == null) return null;

      final amountStr = amountMatch.group(1)!.replaceAll(',', '').split('.').first;
      final amount = int.tryParse(amountStr) ?? 0;
      final transId = transIdMatch.group(1)!.trim().toUpperCase();
      final selcomRef = refMatch?.group(1)?.trim().toUpperCase();
      final channel = channelMatch?.group(1)?.trim() ?? 'Selcom Pay';

      String senderName = 'SELCOM PAYER';
      String rawPhone = '';

      if (payerMatch != null) {
        senderName = payerMatch.group(1)!.trim().toUpperCase();
        rawPhone = payerMatch.group(2)!.trim();
      } else if (fromMatch != null) {
        rawPhone = fromMatch.group(1)!.trim();
        senderName = rawPhone;
      }

      final parts = extractPhoneParts(rawPhone);

      return SelcomPaymentSms(
        reference: transId,
        selcomRef: selcomRef,
        amount: amount,
        senderName: senderName,
        channel: channel,
        rawPhone: rawPhone,
        phonePrefix3: parts.prefix3,
        phoneLast4: parts.last4,
        transactionTime: timeMatch?.group(1)?.trim() ?? DateTime.now().toIso8601String(),
      );
    }

    // Format 2: Single-line "Selcom Pesa" notification
    final singleLineRegex = RegExp(
      r'^([A-Z0-9]+)\s+Confirmed\.\s+You have received TZS\s+([\d,]+(?:\.\d{2})?)\s+from\s+(.+?)\s+-\s+(.+?)\s+\(([^)]+)\)\s+on\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})',
      caseSensitive: false,
    );

    final match = singleLineRegex.firstMatch(text);
    if (match != null) {
      final ref = match.group(1)!.trim().toUpperCase();
      final amountStr = match.group(2)!.replaceAll(',', '').split('.').first;
      final amount = int.tryParse(amountStr) ?? 0;
      final senderName = match.group(3)!.trim().toUpperCase();
      final channel = match.group(4)!.trim();
      final rawPhone = match.group(5)!.trim();
      final txTime = match.group(6)!.trim();

      final parts = extractPhoneParts(rawPhone);

      return SelcomPaymentSms(
        reference: ref,
        selcomRef: null,
        amount: amount,
        senderName: senderName,
        channel: channel,
        rawPhone: rawPhone,
        phonePrefix3: parts.prefix3,
        phoneLast4: parts.last4,
        transactionTime: txTime,
      );
    }

    return null;
  }
}