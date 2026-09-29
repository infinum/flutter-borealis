/// Loggy-backed log capture: the [BorealisPrinter], in-memory event store and
/// the logs Borealis page.
library;

import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loggy/loggy.dart';

import '../foundation/foundation.dart';

part 'auto_update.dart';
part 'logs_borealis_page.dart';
part 'logs_config.dart';
part 'logs_export_utils.dart';
part 'logs_page.dart';
part 'terminal_logger.dart';
