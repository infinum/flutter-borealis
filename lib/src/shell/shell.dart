/// Composition root: the floating [BorealisOverlay] that hosts every feature
/// page, the gamified popup layer, and the top-level [Borealis] entry API.
/// Depends on foundation and every feature library.
library;

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_loggy_dio/flutter_loggy_dio.dart';
import 'package:loggy/loggy.dart';

import '../foundation/foundation.dart';
import '../wiretap/wiretap.dart';

part 'borealis_api.dart';
part 'borealis_gamified_overlay.dart';
part 'borealis_overlay.dart';
part 'debug_panel.dart';
part 'borealis_settings.dart';
