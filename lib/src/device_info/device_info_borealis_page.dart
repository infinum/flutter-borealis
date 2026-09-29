part of 'device_info.dart';

/// Debug panel page listing the app's flavor and package data alongside the
/// device and OS metadata reported by `device_info_plus`.
///
/// Android, iOS and web report real data; every other platform shows an
/// "Unsupported platform" placeholder.
class DeviceInfoBorealisPage extends BorealisPage {
  const DeviceInfoBorealisPage({super.useAppTheme = false})
    : super(title: 'Device info', icon: Icons.bug_report_outlined);

  @override
  Widget build(BuildContext context) => const DeviceInfoPage();
}
