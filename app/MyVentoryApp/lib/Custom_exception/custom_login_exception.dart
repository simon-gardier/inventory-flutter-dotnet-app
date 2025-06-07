class CustomLoginException implements Exception {
  final String message;
  CustomLoginException(this.message);

  @override
  String toString() => message; // Retourne uniquement le message
}
