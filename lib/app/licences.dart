import 'package:bah_francais/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lists the licences of what ships inside the app, beyond the packages the
/// licence page finds by itself:
///
/// - Poppins, under the SIL Open Font License, which travels with the font;
/// - the FSRS scheduler, ported from py-fsrs under the MIT licence.
void registerLicences() {
  LicenseRegistry.addLicense(
    () => _fromAsset(const [AppTheme.fontFamily], 'assets/fonts/OFL.txt'),
  );
  LicenseRegistry.addLicense(
    () => _fromAsset(const ['py-fsrs'], 'assets/licences/py-fsrs.txt'),
  );
}

Stream<LicenseEntry> _fromAsset(List<String> packages, String asset) async* {
  final licence = await rootBundle.loadString(asset);
  yield LicenseEntryWithLineBreaks(packages, licence);
}
