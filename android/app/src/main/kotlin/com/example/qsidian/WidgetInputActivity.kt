package com.example.qsidian

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import android.widget.EditText
import android.widget.Button
import android.widget.LinearLayout
import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.appwidget.AppWidgetManager // Added import for AppWidgetManager

class WidgetInputActivity : Activity() {

    private lateinit var editText: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make activity transparent
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)

        // Create a simple layout for the dialog
        val layout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                setMargins(
                    dpToPx(16f, context),
                    dpToPx(16f, context),
                    dpToPx(16f, context),
                    dpToPx(16f, context)
                )
            }
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            setPadding(
                dpToPx(16f, context),
                dpToPx(16f, context),
                dpToPx(16f, context),
                dpToPx(16f, context)
            )
        }

        editText = EditText(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(200f, context) // Fixed height for the EditText
            )
            hint = "Enter your note here..."
            gravity = Gravity.TOP or Gravity.START
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setBackgroundColor(Color.parseColor("#F0F0F0")) // Light grey background
            setPadding(
                dpToPx(8f, context),
                dpToPx(8f, context),
                dpToPx(8f, context),
                dpToPx(8f, context)
            )
            // Set initial text if provided
            setText(intent.getStringExtra(EXTRA_INITIAL_TEXT))
        }
        layout.addView(editText)

        val saveButton = Button(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.END
                topMargin = dpToPx(16f, context)
            }
            text = "Save"
            setOnClickListener {
                val updatedContent = editText.text.toString()
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

                val updateIntent = Intent("com.example.qsidian.NOTE_CONTENT_UPDATED_ACTION").apply {
                    putExtra(EXTRA_RESULT_TEXT, updatedContent)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                sendBroadcast(updateIntent)
                finish()
            }
        }
        layout.addView(saveButton)

        setContentView(layout)
    }

    private fun dpToPx(dp: Float, context: Context): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            context.resources.displayMetrics
        ).toInt()
    }

    companion object {
        const val EXTRA_INITIAL_TEXT = "initial_text"
        const val EXTRA_RESULT_TEXT = "result_text"
    }
}
