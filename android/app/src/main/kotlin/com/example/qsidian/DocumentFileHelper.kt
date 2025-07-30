package com.example.qsidian

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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

    suspend fun listAllMarkdownFilesRecursive(context: Context, directoryUri: Uri): List<DocumentFile> = withContext(Dispatchers.IO) {
        val documentFile = getDocumentFileFromUri(context, directoryUri)
        val markdownFiles = mutableListOf<DocumentFile>()
        
        if (documentFile == null || !documentFile.isDirectory) {
            return@withContext markdownFiles
        }
        
        val files = documentFile.listFiles()
        
        files.forEach { file ->
            if (file.isFile && (file.name?.endsWith(".md", true) == true || file.name?.endsWith(".markdown", true) == true)) {
                markdownFiles.add(file)
            } else if (file.isDirectory) {
                markdownFiles.addAll(listAllMarkdownFilesRecursive(context, file.uri))
            }
        }
        
        markdownFiles
    }

    fun listAllMarkdownFilesRecursiveAsync(context: Context, directoryUri: Uri, callback: (List<DocumentFile>) -> Unit) {
        CoroutineScope(Dispatchers.Main).launch {
            val files = listAllMarkdownFilesRecursive(context, directoryUri)
            callback(files)
        }
    }

    suspend fun readFileContent(context: Context, fileUri: Uri): String? = withContext(Dispatchers.IO) {
        return@withContext try {
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

    fun readFileContentAsync(context: Context, fileUri: Uri, callback: (String?) -> Unit) {
        CoroutineScope(Dispatchers.Main).launch {
            val content = readFileContent(context, fileUri)
            callback(content)
        }
    }

    suspend fun writeFileContent(context: Context, fileUri: Uri, content: String): Boolean = withContext(Dispatchers.IO) {
        return@withContext try {
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

    fun writeFileContentAsync(context: Context, fileUri: Uri, content: String, callback: (Boolean) -> Unit) {
        CoroutineScope(Dispatchers.Main).launch {
            val success = writeFileContent(context, fileUri, content)
            callback(success)
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

    suspend fun listFolderContents(context: Context, directoryUri: Uri): List<DocumentFile> = withContext(Dispatchers.IO) {
        val documentFile = getDocumentFileFromUri(context, directoryUri)
        val contents = mutableListOf<DocumentFile>()
        if (documentFile != null && documentFile.isDirectory) {
            documentFile.listFiles().forEach { file ->
                contents.add(file)
            }
        }
        return@withContext contents
    }

    fun listFolderContentsAsync(context: Context, directoryUri: Uri, callback: (List<DocumentFile>) -> Unit) {
        CoroutineScope(Dispatchers.Main).launch {
            val contents = listFolderContents(context, directoryUri)
            callback(contents)
        }
    }

}
