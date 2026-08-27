/// Product identity strings used by the client foundation.
///
/// This is a branding foundation only. It does not remove or replace any
/// RustDesk or third-party licensing and attribution notices.
class ProductIdentity {
  ProductIdentity._();

  static const String productName = 'Ultimate Remote';
  static const String legalProductName = 'Ultimate Solutions Remote';
  static const String upstreamProjectName = 'RustDesk';
  static const String attributionNotice =
      'Ultimate Remote is built on RustDesk. See the included licensing and '
      'third-party notices for attribution details.';

  static String windowTitle({String? context}) {
    final normalizedContext = context?.trim();
    if (normalizedContext == null || normalizedContext.isEmpty) {
      return productName;
    }
    return '$normalizedContext - $productName';
  }
}

/// Stable product-facing labels for future localization.
class ProductLabels {
  ProductLabels._();

  static const String signIn = 'Sign in';
  static const String signOut = 'Sign out';
  static const String devices = 'Devices';
  static const String sessions = 'Sessions';
}
