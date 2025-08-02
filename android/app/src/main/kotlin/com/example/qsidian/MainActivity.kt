package com.example.qsidian

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.app.Activity
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri // Added import for Uri

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.qsidian/vault"
    private val REQUEST_CODE_OPEN_DIRECTORY = 1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "openDirectoryPicker") {
                openDirectoryPicker()
                result.success(null)
            } else if (call.method == "listMarkdownFiles") {
                val vaultUriString = call.argument<String>("vaultUri")
                if (vaultUriString != null) {
                    val vaultUri = Uri.parse(vaultUriString)
                    DocumentFileHelper.listAllMarkdownFilesRecursiveAsync(applicationContext, vaultUri) { fileUris ->
                        result.success(fileUris.map { it.uri.toString() })
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Vault URI cannot be null", null)
                }
            } else if (call.method == "readFileContent") {
                val fileUriString = call.argument<String>("fileUri")
                if (fileUriString != null) {
                    val fileUri = Uri.parse(fileUriString)
                    DocumentFileHelper.readFileContentAsync(applicationContext, fileUri) { content ->
                        result.success(content)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File URI cannot be null", null)
                }
            } else if (call.method == "writeFileContent") {
                val fileUriString = call.argument<String>("fileUri")
                val content = call.argument<String>("content")
                if (fileUriString != null && content != null) {
                    val fileUri = Uri.parse(fileUriString)
                    DocumentFileHelper.writeFileContentAsync(applicationContext, fileUri, content) { success ->
                        result.success(success)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File URI or content cannot be null", null)
                }
            } else if (call.method == "listFolderContents") {
                val folderUriString = call.argument<String>("folderUri")
                if (folderUriString != null) {
                    val folderUri = Uri.parse(folderUriString)
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
            } else if (call.method == "createFile") {
                val parentUriString = call.argument<String>("parentUri")
                val fileName = call.argument<String>("fileName")
                val content = call.argument<String>("content")
                if (parentUriString != null && fileName != null && content != null) {
                    val parentUri = Uri.parse(parentUriString)
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
            } else if (call.method == "deleteFile") {
                val fileUriString = call.argument<String>("uri")
                if (fileUriString != null) {
                    val fileUri = Uri.parse(fileUriString)
                    DocumentFileHelper.deleteFileAsync(applicationContext, fileUri) { success ->
                        result.success(success)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File URI cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openDirectoryPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        }
        startActivityForResult(intent, REQUEST_CODE_OPEN_DIRECTORY)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_OPEN_DIRECTORY && resultCode == Activity.RESULT_OK) {
            data?.data?.let { uri ->
                Log.d("MainActivity", "Selected directory URI: $uri")
                // Persist access to the URI
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                // Send the URI back to Flutter
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("vaultSelected", uri.toString())
            }
        }
    }
}
