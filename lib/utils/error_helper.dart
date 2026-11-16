class ErrorHelper {
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    
    final errStr = error.toString().toLowerCase();

    // Auth & Login errors
    if (errStr.contains('invalid login credentials') || errStr.contains('invalid grant')) {
      return 'Incorrect email or password. Please check your details.';
    }
    if (errStr.contains('user already registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (errStr.contains('password should be at least')) {
      return 'Password must be at least 6 characters long.';
    }
    if (errStr.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }

    // Subscription & API Key errors
    if (errStr.contains('subscription expired') || errStr.contains('subscription is inactive')) {
      return 'Your HakikiPay subscription has expired or is inactive. Please renew to continue.';
    }
    if (errStr.contains('invalid hakikipay api key')) {
      return 'Invalid API Key. Please check your merchant settings.';
    }
    if (errStr.contains('please configure your lipa namba')) {
      return 'Please set up your Lipa Namba and Recipient Name in settings first.';
    }

    // Network & Connection errors
    if (errStr.contains('socketexception') || errStr.contains('network is unreachable') || errStr.contains('connection refused')) {
      return 'Network connection error. Please check your internet connection.';
    }

    // Default clean fallback
    return 'Something went wrong. Please try again later.';
  }
}