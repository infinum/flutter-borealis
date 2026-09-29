part of 'device_info.dart';

/// The body of the **Device info** tab: the app flavor, the package data and
/// the platform's own device data, each loaded once when the tab mounts.
///
/// Internal to the package — reach it through [DeviceInfoBorealisPage].
class DeviceInfoPage extends StatelessWidget {
  const DeviceInfoPage({super.key});

  /// The platform-specific device info block, or a placeholder where
  /// `device_info_plus` has nothing to report.
  Widget _platformInfo() {
    if (kIsWeb) {
      return _DeviceInfoLoader<WebBrowserInfo>(
        loader: () => DeviceInfoPlugin().webBrowserInfo,
        mapper: (info) => info.data,
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _DeviceInfoLoader<AndroidDeviceInfo>(
        loader: () => DeviceInfoPlugin().androidInfo,
        mapper: (info) => info.data,
      ),
      TargetPlatform.iOS => _DeviceInfoLoader<IosDeviceInfo>(
        loader: () => DeviceInfoPlugin().iosInfo,
        mapper: (info) => info.data,
      ),
      _ => const Center(child: Text('Unsupported platform')),
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _InfoRow(label: 'appFlavor', value: appFlavor.toString()),
          _DeviceInfoLoader<PackageInfo>(loader: PackageInfo.fromPlatform, mapper: (info) => info.data),
          _platformInfo(),
        ],
      ),
    );
  }
}

/// One `label — value` line of the info table.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade800, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Flexible(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

/// The rows for a device-info map, skipping `systemFeatures` which is too
/// large to display usefully.
class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in data.entries)
          if (entry.key != 'systemFeatures') _InfoRow(label: entry.key, value: entry.value.toString()),
      ],
    );
  }
}

/// Loads [T] once via [loader] and renders its [mapper]-derived data as rows,
/// showing an error or spinner while the future is pending.
class _DeviceInfoLoader<T> extends StatefulWidget {
  const _DeviceInfoLoader({required this.loader, required this.mapper});

  final Future<T> Function() loader;
  final Map<String, dynamic> Function(T info) mapper;

  @override
  State<_DeviceInfoLoader<T>> createState() => _DeviceInfoLoaderState<T>();
}

class _DeviceInfoLoaderState<T> extends State<_DeviceInfoLoader<T>> {
  late final Future<T> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(padding: const EdgeInsets.all(16.0), child: Text(snapshot.error.toString())),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return _InfoRows(data: widget.mapper(data));
      },
    );
  }
}
