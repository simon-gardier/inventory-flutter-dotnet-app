class DeepLinkHandler {
  /// Extracts email and token from a reset password deep link
  static Map<String, String?> extractResetPasswordParams(String link) {
    String? email;
    String? token;

    try {
      final uri = Uri.parse(link);

      email = uri.queryParameters['email'];
      token = uri.queryParameters['token'];

      if (email == null || token == null) {
        final fragmentString = uri.fragment;
        if (fragmentString.isNotEmpty) {
          try {
            final fragmentUri = Uri.parse('http://dummy.com$fragmentString');
            email = email ?? fragmentUri.queryParameters['email'];
            token = token ?? fragmentUri.queryParameters['token'];
          } catch (e) {
            // Do nothing
          }
        }
      }
    } catch (e) {
      // Do nothing
    }

    return {
      'email': email,
      'token': token,
    };
  }

  static bool isResetPasswordLink(String link) {
    try {
      final uri = Uri.parse(link);
      String normalizedPath = uri.path;
      while (normalizedPath.contains('//')) {
        normalizedPath = normalizedPath.replaceAll('//', '/');
      }

      return normalizedPath.contains('/reset-password') ||
          uri.fragment.contains('reset-password');
    } catch (e) {
      return false;
    }
  }
}
