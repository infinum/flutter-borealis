import 'package:borealis/borealis.dart';
import 'package:flutter/material.dart';

/// Wraps a [BorealisPage] in a minimal MaterialApp/Scaffold for widget tests.
Widget host(BorealisPage page) => hostWidget(Builder(builder: page.build));

/// The same shell for a page body built directly, rather than through a
/// [BorealisPage].
Widget hostWidget(Widget child) => MaterialApp(home: Scaffold(body: child));
