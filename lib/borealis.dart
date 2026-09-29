/// Borealis — in-app debugging overlay for Flutter.
///
/// This is the only entry point consumers import. It re-exports the public API;
/// everything under `src/` is internal and must not be imported directly.
library;

export 'src/rendering/rendering.dart' show RenderingBorealisPage;
export 'src/actions/actions.dart'
    show ActionsBorealisPage, ButtonActionWidget, InputActionWidget, SelectableActionWidget, ToggleActionWidget;
export 'src/annotation/annotation.dart'
    show
        Annotation,
        AnnotationExporter,
        ClipboardAnnotationExporter,
        BorealisExportButtonReplacement,
        AnnotationBorealisPage;
// Built-in pages and their public widgets.
export 'src/device_info/device_info.dart' show DeviceInfoBorealisPage;
// Core wiring: the overlay, its settings, the network-logger entry point and
// the page contract used to build custom pages.
export 'src/foundation/foundation.dart'
    show
        BorealisPage,
        BorealisExportCallback,
        BorealisButtonReplacement,
        MappedListenable,
        CountListenable,
        ScreenDebugActions,
        BorealisGamify,
        BorealisGamifyEvent;
export 'src/logs/logs.dart' show BorealisPrinter, LogsBorealisPage, LogsConfig, TerminalLogger;
export 'src/shell/shell.dart' show Borealis, BorealisOverlay, BorealisSettings;
export 'src/wiretap/wiretap.dart'
    show
        WiretapBorealisPage,
        WiretapConfig,
        WiretapUrlDisplay,
        WiretapEntry,
        WiretapBodyParser,
        WiretapStore,
        WiretapParsedBody,
        WiretapInterceptor;
