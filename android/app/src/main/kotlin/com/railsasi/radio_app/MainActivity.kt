package com.railsasi.radio_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal natif pour quitter l'application proprement
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hard_exit")
            .setMethodCallHandler { call, _ ->
                if (call.method == "quit") {
                    finishAndRemoveTask() // retire l'appli du multitâche
                    exitProcess(0)        // tue le processus
                }
            }
    }
}