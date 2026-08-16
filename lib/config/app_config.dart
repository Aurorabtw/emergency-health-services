/// Build-time configuration.
///
/// Pass the prescription gateway URL at build/run time, e.g.:
///   flutter run -d chrome \
///     --dart-define=PRESCRIPTION_API_URL=https://your-project.vercel.app
///
/// When [prescriptionApiUrl] is empty the app keeps using the legacy inline
/// Firestore-blob prescription flow, so nothing breaks before the API is
/// deployed and configured.
class AppConfig {
  const AppConfig._();

  static const String prescriptionApiUrl = String.fromEnvironment(
    'PRESCRIPTION_API_URL',
  );

  /// True once a prescription upload gateway has been configured.
  static bool get usePrescriptionApi => prescriptionApiUrl.isNotEmpty;
}
