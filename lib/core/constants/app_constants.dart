class AppConstants {
  const AppConstants._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supabaseFunctionsBaseUrl =
      String.fromEnvironment('SUPABASE_FUNCTIONS_URL');
  static const appTitle = 'FlowStock WMS';
  static const currencyCode = 'EGP';
}
