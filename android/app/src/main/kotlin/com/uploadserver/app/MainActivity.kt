package com.uploadserver.app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val SERVER_CHANNEL = "com.uploadserver.app/server"
    private val UPDATE_CHANNEL = "com.uploadserver.app/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Chaquopy init ────────────────────────────────────────────
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        val py     = Python.getInstance()
        val bridge = py.getModule("server_bridge")

        // ── Server channel ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVER_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val dir         = call.argument<String>("directory")   ?: "/storage/emulated/0"
                            val port        = call.argument<Int>("port")           ?: 8000
                            val theme       = call.argument<String>("theme")       ?: "auto"
                            val basicAuth   = call.argument<String>("basicAuth")   ?: ""
                            val basicAuthUp = call.argument<String>("basicAuthUp") ?: ""
                            val res = bridge.callAttr("start", dir, port, theme, basicAuth, basicAuthUp).toString()
                            result.success(res)
                        }
                        "pause"     -> { bridge.callAttr("pause");     result.success(null) }
                        "resume"    -> { bridge.callAttr("resume");    result.success(null) }
                        "stop"      -> { bridge.callAttr("stop");      result.success(null) }
                        "getStatus" -> { result.success(bridge.callAttr("get_status").toString()) }
                        else        -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("BRIDGE_ERROR", e.message, null)
                }
            }

        // ── Update channel ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installApk" -> {
                            val path = call.argument<String>("path")
                            if (path == null) {
                                result.error("INVALID_ARG", "path is null", null)
                                return@setMethodCallHandler
                            }
                            val file = File(path)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "APK file not found: $path", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("UPDATE_ERROR", e.message, null)
                }
            }
    }
}
