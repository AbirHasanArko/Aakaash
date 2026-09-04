package com.aakaash.aakaash

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Worker config + on-demand init is handled from Dart via
    // WorkManager().initialize(callbackDispatcher, ...). The plugin
    // requires the host Activity (this class) to be a FlutterActivity,
    // which it already is — no further glue is needed here.
}
