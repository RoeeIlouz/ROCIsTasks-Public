import 'package:flutter/material.dart';

/// App-wide messenger so non-widget code (providers, services) can surface a
/// snackbar regardless of which screen triggered the action.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
