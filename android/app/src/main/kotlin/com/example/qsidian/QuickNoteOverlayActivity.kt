package com.example.qsidian

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Overlay activity for displaying the Quick Note widget from Quick Settings tile
 * 
 * This activity provides a transparent overlay that displays the QuickNoteWidget
 * while keeping the Quick Settings panel visible in the background.
 * 
 * Requirements covered:
 * - 1.4: Quick note overlay displays properly
 * - 1.5: Overlay shows title and content fields as specified
 * - 8.1: Consistent visual design with transparent background
 * - 8.2: Material Design 3 theming maintained
 */
class QuickNoteOverlayActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "QuickNoteOverlayActivity"
        private const val CHANNEL = "com.example.qsidian/overlay"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "QuickNoteOverlayActivity onCreate called")
        super.onCreate(savedInstanceState)
        
        // Set up the overlay-specific behavior
        setupOverlayBehavior()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for overlay-specific communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "dismissOverlay" -> {
                    Log.d(TAG, "Dismissing overlay via method channel")
                    finish()
                    result.success(null)
                }
                "getInitialRoute" -> {
                    // Return the overlay route path
                    result.success("/overlay")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Also configure the main vault channel for file operations
        configureVaultChannel(flutterEngine)
    }

    /**
     * Configure the vault method channel for file operations
     * Reuses the same channel implementation as MainActivity for consistency
     */
    private fun configureVaultChannel(flutterEngine: FlutterEngine) {
        val vaultChannel = "com.example.qsidian/vault"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vaultChannel).setMethodCallHandler { call, result ->
            // Handle file operations - reuse the same logic as MainActivity
            when (call.method) {
                "createFile" -> {
                    val parentUriString = call.argument<String>("parentUri")
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (parentUriString != null && fileName != null && content != null) {
                        val parentUri = android.net.Uri.parse(parentUriString)
                        DocumentFileHelper.createFileAsync(applicationContext, parentUri, fileName, content) { fileUri ->
                            if (fileUri != null) {
                                result.success(fileUri.toString())
                            } else {
                                result.error("CREATE_FAILED", "Failed to create file", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Parent URI, file name, or content cannot be null", null)
                    }
                }
                "listFolderContents" -> {
                    val folderUriString = call.argument<String>("folderUri")
                    if (folderUriString != null) {
                        val folderUri = android.net.Uri.parse(folderUriString)
                        DocumentFileHelper.listFolderContentsAsync(applicationContext, folderUri) { contents ->
                            val contentsList = contents.map { file ->
                                mapOf(
                                    "uri" to file.uri.toString(),
                                    "name" to (file.name ?: "Unknown"),
                                    "isDirectory" to file.isDirectory
                                )
                            }
                            result.success(contentsList)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Folder URI cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Set up overlay-specific behavior and window properties
     */
    private fun setupOverlayBehavior() {
        try {
            // Configure window properties for overlay behavior
            window?.let { window ->
                // Make the activity appear over other apps (like Quick Settings)
                window.setFlags(
                    android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                )
                
                // Allow touches outside the activity to be received by underlying activities
                window.setFlags(
                    android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                    android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                )
            }
            
            Log.d(TAG, "Overlay behavior configured successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error configuring overlay behavior", e)
        }
    }

    override fun getInitialRoute(): String {
        // Return the overlay route to display the QuickNoteOverlayRoute
        return "/overlay"
    }

    override fun onBackPressed() {
        Log.d(TAG, "Back button pressed - dismissing overlay")
        super.onBackPressed()
        finish()
    }

    override fun onDestroy() {
        Log.d(TAG, "QuickNoteOverlayActivity onDestroy called")
        super.onDestroy()
    }
}