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
import android.app.PendingIntent
import android.content.ComponentName
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.documentfile.provider.DocumentFile

class QsidianWidget : HomeWidgetProvider() {

    companion object {
        private const val TAG = "QsidianWidget"
        private const val VAULT_PATH_KEY = "vaultPath"
        private const val CURRENT_FOLDER_URI_KEY = "currentFolderUri"
        private const val SELECTED_NOTE_FILE_URI_KEY = "selectedNoteFileUri"
        
        // Action constants
        private const val ACTION_ITEM_CLICK = "com.example.qsidian.ITEM_CLICK_ACTION"
        private const val ACTION_NEW_NOTE = "qsidianwidget://new_note"
        private const val ACTION_SAVE_NOTE = "qsidianwidget://save_note"
        private const val ACTION_BACK = "qsidianwidget://back"
        private const val ACTION_OPEN_APP = "qsidianwidget://open_app"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        
        appWidgetIds.forEach { widgetId ->
            try {
                updateWidget(context, appWidgetManager, widgetId, widgetData)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget $widgetId", e)
                // Show error state
                showErrorState(context, appWidgetManager, widgetId, "Widget Error")
            }
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.initial_widget_layout)
        
        // Get vault information
        val vaultPath = widgetData.getString(VAULT_PATH_KEY, null)
        val currentFolderUri = widgetData.getString(CURRENT_FOLDER_URI_KEY, vaultPath)
        
        // Set vault name
        val vaultName = getVaultNameFromPath(context, currentFolderUri ?: vaultPath)
        views.setTextViewText(R.id.vault_name_text, vaultName)
        
        // Setup file list if vault is available
        if (vaultPath != null) {
            setupFileList(context, views, widgetId)
        } else {
            showNoVaultState(views)
        }
        
        // Setup click handlers
        setupClickHandlers(context, views, widgetId)
        
        // Update the widget
        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "Widget $widgetId updated successfully")
    }

    private fun setupFileList(context: Context, views: RemoteViews, widgetId: Int) {
        try {
            val serviceIntent = Intent(context, QsidianWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.notes_list_view, serviceIntent)

            // Setup click template for list items
            val clickIntent = Intent(context, QsidianWidget::class.java).apply {
                action = ACTION_ITEM_CLICK
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            val clickPendingIntent = PendingIntent.getBroadcast(
                context,
                widgetId,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.notes_list_view, clickPendingIntent)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up file list", e)
        }
    }

    private fun setupClickHandlers(context: Context, views: RemoteViews, widgetId: Int) {
        // Open app when clicking vault name
        val openAppIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.vault_name_text, openAppIntent)

        // New note button
        val newNoteIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(ACTION_NEW_NOTE))
        views.setOnClickPendingIntent(R.id.new_note_button, newNoteIntent)

        // Save note button
        val saveNoteIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(ACTION_SAVE_NOTE))
        views.setOnClickPendingIntent(R.id.save_note_button, saveNoteIntent)

        // Back button
        val backIntent = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(ACTION_BACK))
        views.setOnClickPendingIntent(R.id.back_button, backIntent)
    }

    private fun showNoVaultState(views: RemoteViews) {
        views.setTextViewText(R.id.vault_name_text, "No Vault Selected")
        // Could add empty state handling here
    }

    private fun showErrorState(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, message: String) {
        val views = RemoteViews(context.packageName, R.layout.initial_widget_layout)
        views.setTextViewText(R.id.vault_name_text, message)
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        Log.d(TAG, "onReceive: ${intent.action}")
        
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, QsidianWidget::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            val widgetData = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)

            when (intent.action) {
                ACTION_ITEM_CLICK -> handleItemClick(context, intent, appWidgetManager, appWidgetIds, widgetData)
                ACTION_NEW_NOTE -> handleNewNote(context, appWidgetManager, appWidgetIds, widgetData)
                ACTION_SAVE_NOTE -> handleSaveNote(context, appWidgetManager, appWidgetIds, widgetData)
                ACTION_BACK -> handleBack(context, appWidgetManager, appWidgetIds, widgetData)
                "android.appwidget.action.APPWIDGET_UPDATE" -> {
                    onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
                }
                else -> Log.d(TAG, "Unhandled action: ${intent.action}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onReceive", e)
        }
    }

    private fun handleItemClick(context: Context, intent: Intent, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val itemUriString = intent.getStringExtra("itemUri")
        val isDirectory = intent.getBooleanExtra("isDirectory", false)
        
        if (itemUriString != null) {
            if (isDirectory) {
                // Navigate into folder
                with(widgetData.edit()) {
                    putString(CURRENT_FOLDER_URI_KEY, itemUriString)
                    remove(SELECTED_NOTE_FILE_URI_KEY)
                    apply()
                }
                refreshWidget(context, appWidgetManager, appWidgetIds, widgetData)
            } else {
                // Open note in main app
                val openNoteIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    putExtra("openNote", itemUriString)
                }
                context.startActivity(openNoteIntent)
            }
        }
    }

    private fun handleNewNote(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val vaultUriString = widgetData.getString(VAULT_PATH_KEY, null)
        val currentFolderUriString = widgetData.getString(CURRENT_FOLDER_URI_KEY, vaultUriString)
        
        if (currentFolderUriString != null) {
            try {
                val currentFolderUri = Uri.parse(currentFolderUriString)
                val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
                val fileName = "quick_note_$timestamp.md"
                
                val createdFile = DocumentFileHelper.createFile(context, currentFolderUri, "text/markdown", fileName)
                if (createdFile != null) {
                    val initialContent = "# Quick Note\n\nCreated: ${SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date())}\n\n"
                    DocumentFileHelper.writeFileContentAsync(context, createdFile.uri, initialContent) { success ->
                        if (success) {
                            // Open the new note in the main app
                            val openNoteIntent = Intent(context, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                putExtra("openNote", createdFile.uri.toString())
                            }
                            context.startActivity(openNoteIntent)
                            
                            refreshWidget(context, appWidgetManager, appWidgetIds, widgetData)
                            Log.d(TAG, "New note created: $fileName")
                        } else {
                            Log.e(TAG, "Failed to write initial content to new note")
                        }
                    }
                } else {
                    Log.e(TAG, "Failed to create new note")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error creating new note", e)
            }
        }
    }

    private fun handleSaveNote(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        // This could be used for quick save functionality
        Log.d(TAG, "Save note action triggered")
    }

    private fun handleBack(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val vaultUriString = widgetData.getString(VAULT_PATH_KEY, null)
        val currentFolderUriString = widgetData.getString(CURRENT_FOLDER_URI_KEY, vaultUriString)
        
        if (currentFolderUriString != null && vaultUriString != null) {
            val currentFolderUri = Uri.parse(currentFolderUriString)
            val vaultUri = Uri.parse(vaultUriString)
            
            if (currentFolderUri != vaultUri) {
                try {
                    val parentFile = DocumentFile.fromTreeUri(context, currentFolderUri)?.parentFile
                    if (parentFile != null) {
                        with(widgetData.edit()) {
                            putString(CURRENT_FOLDER_URI_KEY, parentFile.uri.toString())
                            remove(SELECTED_NOTE_FILE_URI_KEY)
                            apply()
                        }
                        refreshWidget(context, appWidgetManager, appWidgetIds, widgetData)
                        Log.d(TAG, "Navigated back to parent folder")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error navigating back", e)
                }
            }
        }
    }

    private fun refreshWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.notes_list_view)
        onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
    }

    private fun getVaultNameFromPath(context: Context, path: String?): String {
        return if (path.isNullOrEmpty()) {
            "No Vault Selected"
        } else {
            try {
                val uri = Uri.parse(path)
                val documentFile = DocumentFile.fromTreeUri(context, uri)
                documentFile?.name ?: "Selected Vault"
            } catch (e: Exception) {
                Log.e(TAG, "Error getting vault name from path: $path", e)
                "Error"
            }
        }
    }
}

class QsidianWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsService.RemoteViewsFactory {
        return QsidianWidgetFactory(this.applicationContext, intent)
    }
}

class QsidianWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    
    companion object {
        private const val TAG = "QsidianWidgetFactory"
        private const val VAULT_PATH_KEY = "vaultPath"
        private const val CURRENT_FOLDER_URI_KEY = "currentFolderUri"
    }
    
    private var appWidgetId: Int = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
    private var folderContents: List<DocumentFile> = emptyList()

    override fun onCreate() {
        Log.d(TAG, "onCreate")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged")
        
        try {
            val widgetData = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
            val vaultUriString = widgetData.getString(VAULT_PATH_KEY, null)
            val currentFolderUriString = widgetData.getString(CURRENT_FOLDER_URI_KEY, vaultUriString)

            if (currentFolderUriString != null) {
                val currentFolderUri = Uri.parse(currentFolderUriString)
                DocumentFileHelper.listFolderContentsAsync(context, currentFolderUri) { contents ->
                    folderContents = contents.filter { it.name != null } // Filter out items with null names
                    Log.d(TAG, "Loaded ${folderContents.size} items from folder")
                    // Notify widget manager that data set has changed after async operation
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val thisAppWidget = ComponentName(context, QsidianWidget::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.notes_list_view)
                }
            } else {
                folderContents = emptyList()
                Log.d(TAG, "No folder selected")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading folder contents", e)
            folderContents = emptyList()
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
    }

    override fun getCount(): Int = folderContents.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= folderContents.size) {
            return getLoadingView() ?: RemoteViews(context.packageName, R.layout.widget_list_item)
        }
        
        val item = folderContents[position]
        val itemName = item.name ?: "Unknown Item"
        
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)
        views.setTextViewText(R.id.widget_list_item_text, itemName)

        // Set icon based on type
        if (item.isDirectory) {
            views.setImageViewResource(R.id.item_icon, R.drawable.ic_folder)
        } else {
            views.setImageViewResource(R.id.item_icon, R.drawable.ic_note)
        }

        // Set click intent
        val fillInIntent = Intent().apply {
            putExtra("itemUri", item.uri.toString())
            putExtra("isDirectory", item.isDirectory)
        }
        views.setOnClickFillInIntent(R.id.widget_list_item_text, fillInIntent)
        
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)
        views.setTextViewText(R.id.widget_list_item_text, "Loading...")
        return views
    }

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
