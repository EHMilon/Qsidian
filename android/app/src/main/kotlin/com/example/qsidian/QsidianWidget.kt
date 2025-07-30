package com.example.qsidian

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.content.Intent
import android.widget.RemoteViewsService
import android.util.Log
import org.json.JSONArray
import android.app.PendingIntent
import android.content.ComponentName
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.documentfile.provider.DocumentFile

class QsidianWidget : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.initial_widget_layout).apply {
                // Set vault name
                val vaultPath = widgetData.getString("vaultPath", null)
                setTextViewText(R.id.vault_name_text, getVaultNameFromPath(vaultPath))

                // Set up the ListView for notes
                val serviceIntent = Intent(context, QsidianWidgetService::class.java)
                serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                serviceIntent.data = Uri.parse(serviceIntent.toUri(Intent.URI_INTENT_SCHEME))
                setRemoteAdapter(R.id.notes_list_view, serviceIntent)

                // Handle clicks on ListView items (notes)
                val clickIntent = Intent(context, QsidianWidget::class.java)
                clickIntent.action = "com.example.qsidian.OPEN_NOTE_ACTION"
                clickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                val clickPendingIntent = PendingIntent.getBroadcast(context, 0, clickIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setPendingIntentTemplate(R.id.notes_list_view, clickPendingIntent)

                // Read and display selected note content
                val selectedFileUriString = widgetData.getString("selectedNoteFileUri", null)
                if (selectedFileUriString != null) {
                    val selectedFileUri = Uri.parse(selectedFileUriString)
                    val fileContent = DocumentFileHelper.readFileContent(context, selectedFileUri)
                    if (fileContent != null) {
                        setTextViewText(R.id.note_content_edittext, fileContent)
                    } else {
                        setTextViewText(R.id.note_content_edittext, "Error loading note.")
                    }
                } else {
                    setTextViewText(R.id.note_content_edittext, "")
                }

                // Set click listener for the EditText to open the input activity
                val editNoteIntent = Intent(context, QsidianWidget::class.java).apply {
                    action = "com.example.qsidian.EDIT_NOTE_CONTENT_ACTION"
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    // Pass the current content to the activity
                    putExtra("currentNoteContent", widgetData.getString("note_content_edittext", ""))
                }
                val editNotePendingIntent = PendingIntent.getBroadcast(context, 0, editNoteIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setOnClickPendingIntent(R.id.note_content_edittext, editNotePendingIntent)

                // Open App on Vault Name Click (to select a new vault)
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(context,
                    MainActivity::class.java)
                setOnClickPendingIntent(R.id.vault_name_text, openAppIntent)

                // New Note Button
                val newNoteIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("qsidianwidget://new_note"))
                setOnClickPendingIntent(R.id.new_note_button, newNoteIntent)

                // Save Note Button
                val saveNoteIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("qsidianwidget://save_note"))
                setOnClickPendingIntent(R.id.save_note_button, saveNoteIntent)

                // More Options Button (placeholder for now)
                // val moreOptionsIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
                //     Uri.parse("qsidianwidget://more_options"))
                // setOnClickPendingIntent(R.id.more_options_button, moreOptionsIntent)

                // Formatting Toolbar buttons (placeholders for now)
                val formatHIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("qsidianwidget://format_h"))
                setOnClickPendingIntent(R.id.format_h_button, formatHIntent)
                val formatBIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("qsidianwidget://format_b"))
                setOnClickPendingIntent(R.id.format_b_button, formatBIntent)
                val formatIIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("qsidianwidget://format_i"))
                setOnClickPendingIntent(R.id.format_i_button, formatIIntent)
                val formatUIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("qsidianwidget://format_u"))
                setOnClickPendingIntent(R.id.format_u_button, formatUIntent)
                val formatSIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("qsidianwidget://format_s"))
                setOnClickPendingIntent(R.id.format_s_button, formatSIntent)

            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisAppWidget = ComponentName(context.packageName, QsidianWidget::class.java.name)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
        val widgetData = context.getSharedPreferences(context.packageName + "_preferences", Context.MODE_PRIVATE)

        when (intent.action) {
            "com.example.qsidian.OPEN_NOTE_ACTION" -> {
                val fileUriString = intent.getStringExtra("fileUri")
                if (fileUriString != null) {
                    with(widgetData.edit()) {
                        putString("selectedNoteFileUri", fileUriString)
                        apply()
                    }
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.notes_list_view)
                    onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
                }
            }
            "android.appwidget.action.APPWIDGET_UPDATE" -> {
                // Widget updated by system or HomeWidget.updateWidget
                onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
            }
            "qsidianwidget://new_note" -> {
                // Clear selected note and content for a new note
                with(widgetData.edit()) {
                    remove("selectedNoteFileUri")
                    apply()
                }
                onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
            }
            "qsidianwidget://save_note" -> {
                val currentNoteContent = widgetData.getString("note_content_edittext", "") ?: ""
                val selectedNoteFileUriString = widgetData.getString("selectedNoteFileUri", null)
                val vaultUriString = widgetData.getString("vaultPath", null)

                if (vaultUriString == null) {
                    Log.e("QsidianWidget", "Cannot save note: No vault selected.")
                    return
                }

                val vaultUri = Uri.parse(vaultUriString)
                val targetFileUri: Uri?

                if (selectedNoteFileUriString != null) {
                    // Edit existing note
                    targetFileUri = Uri.parse(selectedNoteFileUriString)
                    DocumentFileHelper.writeFileContent(context, targetFileUri, currentNoteContent)
                    Log.d("QsidianWidget", "Note updated: $targetFileUri")
                } else {
                    // Create new note
                    val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
                    val fileName = "quick_note_$timestamp.md"
                    val createdFile = DocumentFileHelper.createFile(context, vaultUri, "text/markdown", fileName)
                    if (createdFile != null) {
                        DocumentFileHelper.writeFileContent(context, createdFile.uri, currentNoteContent)
                        targetFileUri = createdFile.uri
                        Log.d("QsidianWidget", "New note created and saved: $targetFileUri")
                        with(widgetData.edit()) {
                            putString("selectedNoteFileUri", targetFileUri.toString())
                            apply()
                        }
                    } else {
                        Log.e("QsidianWidget", "Failed to create new file in vault: $vaultUri")
                        targetFileUri = null
                    }
                }

                if (targetFileUri != null) {
                    onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
                }
            }
            "com.example.qsidian.EDIT_NOTE_CONTENT_ACTION" -> {
                val currentContent = intent.getStringExtra("currentNoteContent") ?: ""
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

                val editIntent = Intent(context, WidgetInputActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra(WidgetInputActivity.EXTRA_INITIAL_TEXT, currentContent)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId) // Pass widget ID
                }
                context.startActivity(editIntent)
            }
            "com.example.qsidian.NOTE_CONTENT_UPDATED_ACTION" -> {
                val updatedContent = intent.getStringExtra(WidgetInputActivity.EXTRA_RESULT_TEXT) ?: ""
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

                // Save the updated content to SharedPreferences
                with(widgetData.edit()) {
                    putString("note_content_edittext", updatedContent)
                    apply()
                }

                // Trigger widget update to display the new content
                val ids = appWidgetManager.getAppWidgetIds(thisAppWidget)
                onUpdate(context, appWidgetManager, ids, widgetData)
            }
            // Handle other formatting actions here
            else -> {
                Log.d("QsidianWidget", "Unhandled intent action: ${intent.action}")
            }
        }
    }

    private fun getVaultNameFromPath(path: String?): String {
        return if (path.isNullOrEmpty()) {
            "No Vault Selected"
        } else {
            val uri = Uri.parse(path)
            uri.lastPathSegment ?: "Selected Vault"
        }
    }
}

class QsidianWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsService.RemoteViewsFactory {
        return QsidianWidgetFactory(this.applicationContext, intent)
    }
}

class QsidianWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    private var appWidgetId: Int = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
    private var markdownFileUris: List<Uri> = emptyList()

    override fun onCreate() {
        // In onCreate() you setup any data you need.
    }

    override fun onDataSetChanged() {
        val widgetData = context.getSharedPreferences(context.packageName + "_preferences", Context.MODE_PRIVATE)
        val vaultUriString = widgetData.getString("vaultPath", null)

        if (vaultUriString != null) {
            val vaultUri = Uri.parse(vaultUriString)
            val files = DocumentFileHelper.listFilesInDirectory(context, vaultUri)
            markdownFileUris = files.filter { it.name?.endsWith(".md", true) == true || it.name?.endsWith(".markdown", true) == true }.map { it.uri }
            Log.d("QsidianWidgetFactory", "Data set changed. Vault: $vaultUriString, Files found: ${markdownFileUris.size}")
        } else {
            markdownFileUris = emptyList()
            Log.d("QsidianWidgetFactory", "Data set changed. No vault selected.")
        }
    }

    override fun onDestroy() {
        // In onDestroy() you clean up anything that was set up in onCreate().
    }

    override fun getCount(): Int {
        return markdownFileUris.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_list_item).apply {
            val fileUri = markdownFileUris[position]
            val fileName = DocumentFileHelper.getDocumentFileFromUri(context, fileUri)?.name ?: fileUri.lastPathSegment ?: "Unknown File"
            setTextViewText(R.id.widget_list_item_text, fileName)

            val fillInIntent = Intent()
            fillInIntent.putExtra("fileUri", fileUri.toString())
            setOnClickFillInIntent(R.id.widget_list_item_text, fillInIntent)
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null // You can return a loading view here
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    // Removed parseJsonArray as it's no longer needed for file paths
}
