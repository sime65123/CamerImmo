class AppConstants {
  // Supabase
  static const String supabaseUrl = 'https://wlchfwyipocgpvxjpxji.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsY2hmd3lpcG9jZ3B2eGpweGppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyNjYwMDIsImV4cCI6MjA4OTg0MjAwMn0.0La4d0KLWCuuLpAO46Cv4i28MbDx5dbuwrBnnCCRHuE';

  // App
  static const String appName = 'CamerImmo';
  static const String appSlogan = 'Votre chez-vous, simplement.';
  static const String appVersion = '1.0.0';

  // Cameroun
  static const String phonePrefix = '+237';
  static const String currency = 'FCFA';
  static const String defaultCity = 'Yaoundé';
  static const List<String> cities = [
    'Yaoundé', 'Douala', 'Bafoussam', 'Garoua',
    'Maroua', 'Ngaoundéré', 'Bertoua', 'Kribi',
    'Ebolowa', 'Bamenda',
  ];
  static const List<String> yaounde_neighborhoods = [
    'Bastos', 'Biyem-Assi', 'Melen', 'Omnisport',
    'Nlongkak', 'Essos', 'Mvog-Ada', 'Nsimeyong',
    'Mfandena', 'Tsinga', 'Ekounou', 'Nkoldongo',
  ];
  static const List<String> douala_neighborhoods = [
    'Bonanjo', 'Akwa', 'Makepe', 'Bonapriso',
    'Deido', 'Bali', 'Logpom', 'Kotto',
  ];

  // Paiement
  static const double cinetpayFeeRate = 0.015; // 1.5%
  static const int escrowDelayHours = 48;

  // Storage
  static const String propertyImagesBucket = 'property-images';
  static const String documentsBucket = 'documents';
  static const String avatarsBucket = 'avatars';

  // Pagination
  static const int pageSize = 10;

  // Credit Score
  static const int maxCreditScore = 1000;
  static const Map<String, List<int>> creditGradeRanges = {
    'A+': [850, 1000],
    'A':  [750, 849],
    'B':  [650, 749],
    'C':  [550, 649],
    'D':  [400, 549],
    'E':  [0,   399],
  };
}