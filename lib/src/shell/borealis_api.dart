part of 'shell.dart';

/// Top-level entry points for wiring Borealis into an app.
class Borealis {
  /// Attaches Borealis to [dioClient]: a Loggy interceptor that prints to the
  /// console, and a [WiretapInterceptor] that fills the **Network** tab.
  ///
  /// The boolean flags ([requestHeader], [requestBody], [responseHeader],
  /// [responseBody], [error]) and the level/width options configure the
  /// **console output only**. The Network tab captures every request and
  /// response in full regardless of them — turning [requestHeader] off does
  /// not stop headers reaching the tab or its exports. Use [redactHeaders] for
  /// that: it names the headers masked before capture, defaulting to
  /// [WiretapInterceptor.defaultRedactedHeaders]. Pass an empty set to capture
  /// everything verbatim. [redactBodyKeys] does the same for keys inside
  /// request and response bodies, and masks nothing unless you name something.
  ///
  /// Calling this again on the same client replaces the interceptors it added
  /// before rather than stacking a second pair.
  ///
  /// This does not check the build mode. Gate the call yourself if the app
  /// should not capture traffic in release builds — [BorealisSettings.enabled]
  /// hides the overlay but leaves the interceptor attached and recording.
  static void initNetworkLogger(
    dio.Dio dioClient, {
    bool requestHeader = false,
    bool requestBody = false,
    bool responseHeader = false,
    bool responseBody = true,
    bool error = true,
    int maxWidth = 90,
    LogLevel requestLevel = LogLevel.info,
    LogLevel responseLevel = LogLevel.info,
    LogLevel errorLevel = LogLevel.error,
    WiretapStore? wiretapStore,
    Set<String>? redactHeaders,
    Set<String>? redactBodyKeys,
  }) {
    dioClient.interceptors
      ..removeWhere((i) => i is LoggyDioInterceptor || i is WiretapInterceptor)
      ..addAll([
        LoggyDioInterceptor(
          requestHeader: requestHeader,
          requestBody: requestBody,
          responseHeader: responseHeader,
          responseBody: responseBody,
          error: error,
          maxWidth: maxWidth,
          requestLevel: requestLevel,
          responseLevel: responseLevel,
          errorLevel: errorLevel,
        ),
        WiretapInterceptor(store: wiretapStore, redactHeaders: redactHeaders, redactBodyKeys: redactBodyKeys),
      ]);
  }

  /// Closes the debug panel if it is open.
  static void hideDebugPanel() {
    OverlayNestedNavigation.hide();
  }
}
