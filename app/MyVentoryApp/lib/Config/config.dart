class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue:
          'https://myventory-api-route-myventory.apps.speam.montefiore.uliege.be/api');
}
