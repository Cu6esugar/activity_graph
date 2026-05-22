package com.example.activity_it

import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val metadataChannel = "video_metadata_channel"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, metadataChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCreationTime" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val creationTime = getVideoCreationTime(path)
                        result.success(creationTime)
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getVideoCreationTime(path: String): String? {
        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(path)
            
            val dateString = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE)
            retriever.release()
            
            if (dateString != null) {
                android.util.Log.d("MainActivity", "Raw date string: $dateString")
                return parseVideoDate(dateString)
            }
            
            return null
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting video creation time: ${e.message}")
            return null
        }
    }

    private fun parseVideoDate(dateString: String): String {
        try {
            val cleanDateString = dateString.trim()
            
            if (cleanDateString.contains("T") && cleanDateString.length >= 15) {
                val inputFormat = SimpleDateFormat("yyyyMMdd'T'HHmmss", Locale.US)
                inputFormat.timeZone = TimeZone.getTimeZone("UTC")
                
                val dateStr = cleanDateString.substring(0, 15)
                val date: Date? = inputFormat.parse(dateStr)
                
                if (date != null) {
                    val outputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                    outputFormat.timeZone = TimeZone.getTimeZone("UTC")
                    return outputFormat.format(date)
                }
            }
            
            val numericOnly = cleanDateString.replace(Regex("[^0-9]"), "")
            if (numericOnly.length >= 14) {
                val inputFormat2 = SimpleDateFormat("yyyyMMddHHmmss", Locale.US)
                inputFormat2.timeZone = TimeZone.getTimeZone("UTC")
                
                val date: Date? = inputFormat2.parse(numericOnly.substring(0, 14))
                if (date != null) {
                    val outputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                    outputFormat.timeZone = TimeZone.getTimeZone("UTC")
                    return outputFormat.format(date)
                }
            }
            
            return if (cleanDateString.contains("Z")) cleanDateString else "${cleanDateString}Z"
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to parse date: $dateString")
            return dateString
        }
    }
}