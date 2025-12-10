package com.example.qsidian

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import android.util.Log

class QsidianApplication : FlutterApplication() {

    companion object {
        const val FLUTTER_ENGINE_ID = "qsidian_flutter_engine"
    }

    override fun onCreate() {
        super.onCreate()
        // Instantiate a FlutterEngine.
        val flutterEngine = FlutterEngine(this)

        // Configure an initial route.
        flutterEngine.navigationChannel.setInitialRoute("/overlay");

        // Start executing Dart code to pre-warm the FlutterEngine.
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Cache the FlutterEngine to be used by other FlutterActivity(s).
        FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine)
        Log.d("QsidianApplication", "FlutterEngine pre-warmed and cached.")
    }

    override fun onTerminate() {
        super.onTerminate()
        // Clean up the cached FlutterEngine when the application terminates
        FlutterEngineCache.getInstance().remove(FLUTTER_ENGINE_ID)
        Log.d("QsidianApplication", "FlutterEngine removed from cache.")
    }
}