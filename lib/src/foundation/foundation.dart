/// Shared primitives every Borealis feature builds on: the [BorealisPage]
/// contract, gamify pub/sub, the nested-navigation overlay host and
/// screen-dependent debug actions. Depends on nothing else internal.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// `dart:io`/`dart:isolate` live behind this conditional import so the package
// still compiles for web, where the export falls back to a throwing stub.
import 'export/export_file_stub.dart' if (dart.library.io) 'export/export_file_io.dart' as export_file;

part 'borealis_page.dart';
part 'borealis_gamify.dart';
part 'borealis_export.dart';
part 'borealis_loading_overlay.dart';
part 'borealis_search_bar.dart';
part 'overlay_nested_navigation.dart';
part 'screen_dependent_debug_actions.dart';
part 'screen_widget_lookup.dart';
