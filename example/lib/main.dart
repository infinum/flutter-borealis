import 'dart:convert';

import 'package:borealis/borealis.dart';
import 'package:example/api_client.dart';
import 'package:example/screen_with_action.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loggy/loggy.dart';

/// Borealis is a debug tool: it records URLs, headers, bodies and every log
/// line, and it can export them. Gate it, and gate the capture separately —
/// turning the overlay off does not detach the Dio interceptor.
const _debugToolsEnabled = !kReleaseMode;

/// Index of the tab the panel opens on. Named rather than written as a literal,
/// so reordering [_pages] cannot silently change which tab appears first.
const _initialTab = 2; // Network

// Wiretap export hooks. Both actions stay hidden until a callback is set, so
// this also demonstrates the export UI in the Network tab.
final _wiretapConfig = WiretapConfig(
  urlDisplay: WiretapUrlDisplay.pathOnly,
  onExport: (path) => logInfo('Wiretap log exported to $path'),
  onCurlExport: (command) async {
    await Clipboard.setData(ClipboardData(text: command));
    logInfo('cURL copied to clipboard');
  },
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (_debugToolsEnabled) {
    Loggy.initLoggy(
      logPrinter: BorealisPrinter(forwardPrinter: const PrettyPrinter()),
      logOptions: const LogOptions(LogLevel.all, stackTraceLevel: LogLevel.error),
    );

    // Attaches the Borealis network logger to the client's Dio instance, which
    // is what fills the Network tab. Gated separately from the overlay above.
    ExampleApi.init();
  }

  runApp(
    MaterialApp(
      title: 'Borealis',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      builder: (context, child) {
        return BorealisOverlay(
          settings: const BorealisSettings(enabled: _debugToolsEnabled, initialPage: _initialTab, gamify: true),
          pages: _pages,
          child: child!,
        );
      },
      home: const MyHomePage(title: 'Borealis demo'),
    ),
  );
}

/// The tabs this demo shows, in order. [_initialTab] indexes into this list.
final List<BorealisPage> _pages = [
  const DeviceInfoBorealisPage(),
  const LogsBorealisPage(),
  WiretapBorealisPage(wiretapConfig: _wiretapConfig),
  const RenderingBorealisPage(),
  const AnnotationBorealisPage(exporter: _LoggingAnnotationExporter()),
  ActionsBorealisPage(actions: _globalActions),
];

/// Global debug actions — one of each widget type, so the Debug options tab
/// shows what they look like side by side.
final List<Widget> _globalActions = [
  ButtonActionWidget(
    label: 'Clear the counter',
    icon: Icons.restart_alt,
    action: () => logInfo('Counter cleared from the debug panel'),
  ),
  ToggleActionWidget(
    label: 'Pretend the user is offline',
    initialState: () => _fakeOffline,
    action: (value) {
      _fakeOffline = value;
      logInfo('Offline override: $value');
      return value;
    },
  ),
  InputActionWidget(
    label: 'Override the API base URL',
    dialogLabel: 'Enter base URL',
    initialValue: 'https://dummyjson.com',
    icon: Icons.link,
    action: (value) => logInfo('Base URL override: ${value ?? 'cleared'}'),
  ),
  SelectableActionWidget<String>(
    label: 'Environment',
    options: const ['dev', 'staging', 'prod'],
    initialSelection: () => _environment,
    onSelection: (value) {
      _environment = value ?? 'dev';
      logInfo('Environment: $_environment');
      return _environment;
    },
  ),
];

bool _fakeOffline = false;
String _environment = 'dev';

/// Shows the `AnnotationExporter` extension point: the default copies JSON to
/// the clipboard, this one logs it instead so the Logs tab shows the payload.
class _LoggingAnnotationExporter extends AnnotationExporter {
  const _LoggingAnnotationExporter();

  @override
  BorealisExportButtonReplacement get exportButtonReplacement =>
      const BorealisExportButtonReplacement(icon: Icons.terminal, label: 'Send to logs');

  @override
  Future<String> export(List<Annotation> annotations) async {
    logInfo(jsonEncode(annotations.map((a) => a.toExportJson()).toList()));
    return 'Logged ${annotations.length} annotations';
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with UiLoggy {
  final _counter = CounterLogic(0);
  final _api = ExampleApi.instance;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    loggy.debug('Init state called!');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loggy.debug('Did change dependencies called!');
  }

  Future<void> _sendRequests() async {
    if (_sending) return;

    setState(() => _sending = true);
    _toast('Sending ${_api.calls.length} requests — open the panel → Network');

    await _api.runAll();

    if (!mounted) return;
    setState(() => _sending = false);
    _toast('Requests finished');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _click({bool increase = true}) {
    loggy.info('Button clicked!');

    setState(() {
      if (increase) {
        _counter.increment();
      } else {
        _counter.decrement();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildHome(context);
  }

  Widget _buildHome(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('You have pushed the button this many times:', textAlign: TextAlign.center),
          Text('${_counter.value}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              loggy.debug('Navigating to next screen');
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScreenWithAction()));
            },
            child: const Icon(Icons.next_plan_outlined),
          ),
          const SizedBox(height: 12.0),
          FloatingActionButton(
            heroTag: 'api_tag',
            // Null while a batch is in flight, so the button cannot be spammed.
            onPressed: _sending ? null : _sendRequests,
            tooltip: 'Send test requests',
            child: _sending
                ? const SizedBox.square(dimension: 20.0, child: CircularProgressIndicator(strokeWidth: 2.0))
                : const Icon(Icons.cloud_outlined),
          ),
          const SizedBox(height: 12.0),
          FloatingActionButton(
            heroTag: 'stateless_screen_tag',
            onPressed: () {
              loggy.debug('Navigating to stateless screen');
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatelessScreenWithAction()));
            },
            child: const Icon(Icons.widgets_outlined),
          ),
          const SizedBox(height: 12.0),
          FloatingActionButton(
            onPressed: _click,
            heroTag: 'increment_tag',
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12.0),
          FloatingActionButton(
            onPressed: () => _click(increase: false),
            tooltip: 'Decrement',
            heroTag: 'decrement_tag',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

mixin LogicLoggy implements LoggyType {
  @override
  Loggy<LogicLoggy> get loggy => Loggy<LogicLoggy>('Logic($runtimeType)');
}

class CounterLogic with LogicLoggy {
  CounterLogic(this._counter) {
    loggy.debug('Started new counter! Start count value is: $_counter');
  }

  int _counter;

  int get value => _counter;

  void increment() {
    _counter++;
    loggy.info('Incrementing counter! Current value: $_counter');

    if (_counter > 2) {
      loggy.debug(
        'Counter is over 2.\nThis is really long message: Lorem Ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
      );
    }

    if (_counter > 4) {
      loggy.warning('Counter is over 4');
    }

    if (_counter > 9) {
      loggy.error('Counter is over 9!');
    }
  }

  void decrement() {
    _counter--;
    loggy.warning('Decrementing counter! Current value: $_counter');

    if (_counter < 0) {
      loggy.error('Counter is less then 0 ($_counter). Counter should never be below 0');
      return;
    }
  }
}
