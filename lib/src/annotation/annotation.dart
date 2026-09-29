/// Widget annotation capture: the [Annotation] model, exporters, in-memory
/// store, the capture overlay and the annotation Borealis page.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../foundation/foundation.dart';

part 'annotation_borealis_page.dart';
part 'annotation_exporter.dart';
part 'annotation_model.dart';
part 'annotation_store.dart';
part 'ui/annotation_info_window.dart';
part 'ui/annotation_marker_tracker.dart';
part 'ui/annotation_markers.dart';
part 'ui/annotation_note_sheet.dart';
part 'ui/annotation_overlay.dart';
part 'ui/annotation_resolver.dart';
part 'ui/annotation_style.dart';
part 'ui/annotation_target.dart';
part 'ui/annotation_widget_filters.dart';
