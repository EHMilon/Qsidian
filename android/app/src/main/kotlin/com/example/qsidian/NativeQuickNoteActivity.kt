package com.example.qsidian

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import android.util.Log
import android.content.pm.ActivityInfo
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
 
class NativeQuickNoteActivity : Activity() {
 
    private lateinit var titleEditText: EditText
    private lateinit var contentEditText: EditText
    private lateinit var saveButton: Button
    private lateinit var cancelButton: Button
 
    private val CHANNEL = "com.example.qsidian/native_quick_note"
    private lateinit var methodChannel: MethodChannel
 
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_native_quick_note)
 
        // Set the activity to be a translucent dialog
        window.setBackgroundDrawableResource(android.R.color.transparent)
        setFinishOnTouchOutside(true) // Dismiss when touching outside
 
        // Lock screen orientation to portrait
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
 
        titleEditText = findViewById(R.id.quick_note_title)
        contentEditText = findViewById(R.id.quick_note_content)
        saveButton = findViewById(R.id.save_button)
        cancelButton = findViewById(R.id.cancel_button)
 
        // Initialize MethodChannel
        val flutterEngine = FlutterEngineCache.getInstance().get(QsidianApplication.FLUTTER_ENGINE_ID)
        if (flutterEngine != null) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        } else {
            Log.e("NativeQuickNote", "FlutterEngine not pre-warmed! Cannot send data to Flutter.")
            Toast.makeText(this, "Error: App not ready.", Toast.LENGTH_LONG).show()
            finish()
            return
        }
 
        saveButton.setOnClickListener {
            saveNote()
        }
 
        cancelButton.setOnClickListener {
            finish() // Close the activity
        }
    }
 
    private fun saveNote() {
        val title = titleEditText.text.toString().trim()
        val content = contentEditText.text.toString().trim()
 
        if (title.isEmpty() && content.isEmpty()) {
            Toast.makeText(this, "Please enter a title or content for your note", Toast.LENGTH_SHORT).show()
            return
        }
 
        // Send data to Flutter
        val noteData = mapOf("title" to title, "content" to content)
        methodChannel.invokeMethod("saveQuickNote", noteData, object : MethodChannel.Result {
            override fun success(result: Any?) {
                Log.d("NativeQuickNote", "Note data sent to Flutter successfully.")
                Toast.makeText(this@NativeQuickNoteActivity, "Note saved!", Toast.LENGTH_SHORT).show()
                finish()
            }
 
            override fun error(code: String, message: String?, details: Any?) {
                Log.e("NativeQuickNote", "Error sending note data to Flutter: $code, $message, $details")
                Toast.makeText(this@NativeQuickNoteActivity, "Failed to save note: $message", Toast.LENGTH_LONG).show()
            }
 
            override fun notImplemented() {
                Log.e("NativeQuickNote", "Method 'saveQuickNote' not implemented in Flutter.")
                Toast.makeText(this@NativeQuickNoteActivity, "Error: Feature not implemented.", Toast.LENGTH_LONG).show()
            }
        })
    }
}