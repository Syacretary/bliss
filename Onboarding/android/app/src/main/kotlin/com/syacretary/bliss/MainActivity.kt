package com.syacretary.bliss

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val pdfExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bliss/local_pdf")
            .setMethodCallHandler { call, result ->
                if (call.method != "extractText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "Lokasi file PDF tidak tersedia.", null)
                    return@setMethodCallHandler
                }
                pdfExecutor.execute {
                    try {
                        PDFBoxResourceLoader.init(applicationContext)
                        val text = PDDocument.load(File(path)).use { document ->
                            PDFTextStripper().apply {
                                startPage = 1
                                endPage = minOf(document.numberOfPages, 100)
                            }.getText(document).take(180_000)
                        }
                        Handler(Looper.getMainLooper()).post { result.success(text) }
                    } catch (_: Throwable) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("PDF_EXTRACTION_FAILED", "PDF tidak dapat diekstrak di perangkat.", null)
                        }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NodeRuntimeState.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRuntime" -> try {
                        result.success(NodeRuntimeState.launch(this))
                    } catch (_: Throwable) {
                        result.error("NODE_RUNTIME_START_FAILED", "Runtime Node.js Android belum siap.", null)
                    }
                    "stopForeground" -> {
                        NodeRuntimeState.stopForeground(this)
                        result.success(null)
                    }
                    "markRuntimeReady" -> {
                        NodeRuntimeState.markReady()
                        result.success(null)
                    }
                    "runtimeState" -> result.success(NodeRuntimeState.state)
                    else -> result.notImplemented()
                }
            }
    }
}
