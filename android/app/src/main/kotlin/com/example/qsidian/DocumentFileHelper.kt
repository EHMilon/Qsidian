package com.example.qsidian

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter

object DocumentFileHelper {

    private const val TAG = "DocumentFileHelper"

    fun getDocumentFileFromUri(context: Context, uri: Uri): DocumentFile? {
        return DocumentFile.fromTreeUri(context, uri)
    }

    fun listFilesInDirectory(context: Context, directoryUri: Uri): List<DocumentFile> {
        val documentFile = getDocumentFileFromUri(context, directoryUri)
        val files = mutableListOf<DocumentFile>()
        if (documentFile != null && documentFile.isDirectory) {
            documentFile.listFiles().forEach { file ->
                // Only add files, not directories, to the list
                if (file.isFile) {
                    files.add(file)
                }
            }
        }
        return files
    }

    fun readFileContent(context: Context, fileUri: Uri): String? {
        return try {
            context.contentResolver.openInputStream(fileUri)?.use { inputStream ->
                BufferedReader(InputStreamReader(inputStream)).use { reader ->
                    reader.readText()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading file content from URI: $fileUri", e)
            null
        }
    }

    fun writeFileContent(context: Context, fileUri: Uri, content: String): Boolean {
        return try {
            context.contentResolver.openOutputStream(fileUri)?.use { outputStream ->
                OutputStreamWriter(outputStream).use { writer ->
                    writer.write(content)
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error writing file content to URI: $fileUri", e)
            false
        }
    }

    fun createFile(context: Context, parentUri: Uri, mimeType: String, displayName: String): DocumentFile? {
        return try {
            val parentDocument = DocumentFile.fromTreeUri(context, parentUri)
            parentDocument?.createFile(mimeType, displayName)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating file in URI: $parentUri", e)
            null
        }
    }

    fun getFileUri(context: Context, parentUri: Uri, fileName: String): Uri? {
        val parentDocument = DocumentFile.fromTreeUri(context, parentUri)
        val file = parentDocument?.findFile(fileName)
        return file?.uri
    }
}
