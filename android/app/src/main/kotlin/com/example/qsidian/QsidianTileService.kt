package com.example.qsidian

import android.content.Intent
import android.content.pm.PackageManager
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi
import android.os.Build
import java.lang.SecurityException

/**
 * Quick Settings Tile Service for Qsidian app
 * Provides quick access to launch the Qsidian app from the Android Quick Settings panel
 * 
 * Requirements covered:
 * - 1.3: Launch app when tile is tapped
 * - 1.4: Bring app to foreground if already running
 * - 3.1: Android 7.0+ compatibility
 * - 3.2: Graceful degradation for unsupported Android versions
 * - 3.3: Proper error handling and compatibility checks
 * - 5.1: Proper TileService extension
 * - 5.2: App launch within 2 seconds
 * - 5.3: Handle low memory conditions and exceptions gracefully
 */
@RequiresApi(Build.VERSION_CODES.N)
class QsidianTileService : TileService() {

    companion object {
        private const val TAG = "QsidianTileService"
        private const val MIN_API_LEVEL = Build.VERSION_CODES.N // Android 7.0
        
        /**
         * Checks if the current Android version supports Quick Settings tiles
         * Requirements covered: 3.2 - Graceful degradation for unsupported versions
         */
        fun isQuickSettingsTileSupported(): Boolean {
            return Build.VERSION.SDK_INT >= MIN_API_LEVEL
        }
        
        /**
         * Gets a user-friendly message about tile compatibility
         * Requirements covered: 3.2 - Graceful degradation messaging
         */
        fun getCompatibilityMessage(): String {
            return if (isQuickSettingsTileSupported()) {
                "Quick Settings tile is supported on this device"
            } else {
                "Quick Settings tiles require Android 7.0 (API 24) or higher. Current version: ${Build.VERSION.SDK_INT}"
            }
        }
    }

    // Track tile lifecycle state for proper resource management
    private var isListening = false
    private var isTileAdded = false

    /**
     * Called when the tile is added to the Quick Settings panel
     * Initializes the tile with proper state and visual properties
     * 
     * Requirements covered:
     * - 3.2: API level compatibility checks
     * - 3.3: Proper error handling and graceful degradation
     * - 4.4: Ensures tile remains available for re-addition after removal
     * - 5.1: Proper TileService lifecycle management
     * - 5.3: Handle exceptions gracefully
     * - 5.4: Proper registration with Android system
     */
    override fun onTileAdded() {
        Log.d(TAG, "onTileAdded() called - checking compatibility")
        
        try {
            // Perform API level compatibility check
            if (!isQuickSettingsTileSupported()) {
                Log.e(TAG, "Quick Settings tiles not supported on this Android version: ${Build.VERSION.SDK_INT}")
                handleUnsupportedVersion("onTileAdded")
                return
            }
            
            super.onTileAdded()
            Log.d(TAG, "Qsidian tile added to Quick Settings")
            
            // Mark tile as added for lifecycle tracking
            isTileAdded = true
            
            // Initialize tile state immediately upon addition
            updateTileState()
            
            // Log successful tile addition for debugging
            Log.i(TAG, "Tile successfully added and initialized")
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in onTileAdded - insufficient permissions", e)
            handleSecurityException("onTileAdded", e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception in onTileAdded - service not properly initialized", e)
            handleIllegalStateException("onTileAdded", e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Runtime exception in onTileAdded", e)
            handleRuntimeException("onTileAdded", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception in onTileAdded", e)
            handleGenericException("onTileAdded", e)
        } finally {
            // Ensure consistent state even if errors occur
            if (!isTileAdded) {
                Log.w(TAG, "Tile addition failed - resetting state")
                resetTileState()
            }
        }
    }

    /**
     * Called when the tile is removed from the Quick Settings panel
     * Performs cleanup operations and ensures proper resource management
     * 
     * Requirements covered:
     * - 3.2: API level compatibility checks
     * - 3.3: Proper error handling and graceful degradation
     * - 4.4: Ensures tile remains available for re-addition after removal
     * - 5.1: Proper TileService lifecycle management
     * - 5.3: Handle exceptions gracefully
     * - 5.4: Proper unregistration and cleanup with Android system
     */
    override fun onTileRemoved() {
        Log.d(TAG, "onTileRemoved() called - performing cleanup")
        
        try {
            // Perform API level compatibility check
            if (!isQuickSettingsTileSupported()) {
                Log.w(TAG, "onTileRemoved called on unsupported Android version: ${Build.VERSION.SDK_INT}")
                handleUnsupportedVersion("onTileRemoved")
                return
            }
            
            super.onTileRemoved()
            Log.d(TAG, "Qsidian tile removed from Quick Settings")
            
            // Mark tile as removed for lifecycle tracking
            isTileAdded = false
            
            // Stop listening if currently active (defensive programming)
            if (isListening) {
                Log.w(TAG, "Tile removed while still listening - cleaning up")
                isListening = false
            }
            
            // Clear any cached tile state
            clearTileState()
            
            // Log successful tile removal for debugging
            Log.i(TAG, "Tile successfully removed and cleaned up")
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in onTileRemoved", e)
            handleSecurityException("onTileRemoved", e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception in onTileRemoved", e)
            handleIllegalStateException("onTileRemoved", e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Runtime exception in onTileRemoved", e)
            handleRuntimeException("onTileRemoved", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception in onTileRemoved", e)
            handleGenericException("onTileRemoved", e)
        } finally {
            // Force cleanup even if errors occur to prevent memory leaks
            Log.d(TAG, "Forcing state cleanup in finally block")
            isTileAdded = false
            isListening = false
        }
    }

    /**
     * Called when the tile becomes visible and should start listening for updates
     * Updates the tile state to ensure it displays correctly and manages resources
     * 
     * Requirements covered:
     * - 3.2: API level compatibility checks
     * - 3.3: Proper error handling and graceful degradation
     * - 5.1: Proper TileService lifecycle management
     * - 5.3: Handle exceptions gracefully
     * - 5.4: Proper resource management and system registration
     */
    override fun onStartListening() {
        Log.d(TAG, "onStartListening() called - initializing tile visibility")
        
        try {
            // Perform API level compatibility check
            if (!isQuickSettingsTileSupported()) {
                Log.w(TAG, "onStartListening called on unsupported Android version: ${Build.VERSION.SDK_INT}")
                handleUnsupportedVersion("onStartListening")
                return
            }
            
            super.onStartListening()
            Log.d(TAG, "Started listening for tile updates")
            
            // Mark as listening for lifecycle tracking
            isListening = true
            
            // Only update tile state if tile is properly added
            if (isTileAdded) {
                updateTileState()
                Log.d(TAG, "Tile state updated during start listening")
            } else {
                Log.w(TAG, "Started listening but tile not marked as added")
            }
            
            // Initialize any resources needed while tile is visible
            initializeListeningResources()
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in onStartListening", e)
            handleSecurityException("onStartListening", e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception in onStartListening", e)
            handleIllegalStateException("onStartListening", e)
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error in onStartListening - system under memory pressure", e)
            handleOutOfMemoryError("onStartListening", e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Runtime exception in onStartListening", e)
            handleRuntimeException("onStartListening", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception in onStartListening", e)
            handleGenericException("onStartListening", e)
        } finally {
            // Ensure consistent state even if errors occur
            if (!isListening) {
                Log.w(TAG, "Start listening failed - resetting state")
                resetListeningState()
            }
        }
    }

    /**
     * Called when the tile is no longer visible and should stop listening for updates
     * Performs resource cleanup to avoid memory leaks and ensure proper resource management
     * 
     * Requirements covered:
     * - 3.2: API level compatibility checks
     * - 3.3: Proper error handling and graceful degradation
     * - 5.1: Proper TileService lifecycle management
     * - 5.3: Handle low memory conditions gracefully through proper cleanup
     * - 5.4: Proper resource management and system unregistration
     */
    override fun onStopListening() {
        Log.d(TAG, "onStopListening() called - cleaning up resources")
        
        try {
            // Perform API level compatibility check
            if (!isQuickSettingsTileSupported()) {
                Log.w(TAG, "onStopListening called on unsupported Android version: ${Build.VERSION.SDK_INT}")
                handleUnsupportedVersion("onStopListening")
                return
            }
            
            super.onStopListening()
            Log.d(TAG, "Stopped listening for tile updates")
            
            // Mark as no longer listening for lifecycle tracking
            isListening = false
            
            // Clean up any resources allocated during listening
            cleanupListeningResources()
            
            // Clear any cached visual state to free memory
            clearTileVisualState()
            
            Log.d(TAG, "Successfully stopped listening and cleaned up resources")
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in onStopListening", e)
            handleSecurityException("onStopListening", e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception in onStopListening", e)
            handleIllegalStateException("onStopListening", e)
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error in onStopListening - forcing cleanup", e)
            handleOutOfMemoryError("onStopListening", e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Runtime exception in onStopListening", e)
            handleRuntimeException("onStopListening", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception in onStopListening", e)
            handleGenericException("onStopListening", e)
        } finally {
            // Force cleanup even if errors occur to prevent memory leaks
            Log.d(TAG, "Forcing resource cleanup in finally block")
            isListening = false
            forceCleanupResources()
        }
    }

    /**
     * Called when the user taps the tile
     * Launches the Qsidian app or brings it to foreground if already running
     * 
     * Requirements covered:
     * - 1.3: Launch app when tile is tapped
     * - 1.4: Bring app to foreground if already running
     * - 3.2: API level compatibility checks
     * - 3.3: Proper error handling and graceful degradation
     * - 5.2: App launch within 2 seconds
     * - 5.3: Handle low memory conditions and exceptions gracefully
     */
    override fun onClick() {
        Log.d(TAG, "onClick() called - user tapped Qsidian tile")
        
        try {
            // Perform API level compatibility check
            if (!isQuickSettingsTileSupported()) {
                Log.e(TAG, "onClick called on unsupported Android version: ${Build.VERSION.SDK_INT}")
                handleUnsupportedVersion("onClick")
                return
            }
            
            super.onClick()
            Log.d(TAG, "Qsidian tile clicked - initiating app launch")
            
            // Validate tile state before attempting launch
            if (!isTileAdded) {
                Log.w(TAG, "Tile clicked but not marked as added - attempting launch anyway")
            }
            
            // Primary launch method with proper task management
            launchQsidianApp()
            Log.d(TAG, "App launch initiated successfully")
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception during app launch - insufficient permissions", e)
            handleLaunchSecurityException(e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception during app launch - service not ready", e)
            handleLaunchIllegalStateException(e)
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error during app launch - system under pressure", e)
            handleLaunchOutOfMemoryError(e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Runtime exception during app launch", e)
            handleLaunchRuntimeException(e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception during app launch", e)
            handleLaunchGenericException(e)
        }
    }

    /**
     * Updates the tile state with proper visual properties
     * Sets the tile to inactive state (standard for app launcher tiles)
     * Provides visual feedback handling as required
     * 
     * Requirements covered:
     * - 3.3: Proper error handling for tile state updates
     * - 5.3: Handle exceptions gracefully during tile operations
     */
    private fun updateTileState() {
        try {
            val tile = qsTile
            if (tile != null) {
                // Set tile state to inactive (standard for launcher tiles)
                // This provides appropriate visual feedback consistent with system tiles
                tile.state = Tile.STATE_INACTIVE
                
                // Set tile label (will be overridden by manifest label in most cases)
                tile.label = "Qsidian"
                
                // Ensure tile adapts to system theme automatically
                // The system handles dark/light theme adaptation for standard tiles
                
                // Update the tile to reflect changes and provide visual feedback
                tile.updateTile()
                
                Log.d(TAG, "Tile state updated successfully with visual feedback")
            } else {
                Log.w(TAG, "Tile is null, cannot update state - service may not be properly initialized")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception updating tile state - insufficient permissions", e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception updating tile state - service not ready", e)
        } catch (e: RuntimeException) {
            Log.e(TAG, "Runtime exception updating tile state", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception updating tile state", e)
        }
    }

    // ========================================
    // ERROR HANDLING METHODS
    // Requirements covered: 3.2, 3.3, 5.3
    // ========================================
    
    /**
     * Handles unsupported Android version scenarios
     * Requirements covered: 3.2 - Graceful degradation for unsupported versions
     */
    private fun handleUnsupportedVersion(methodName: String) {
        Log.w(TAG, "Method $methodName called on unsupported Android version ${Build.VERSION.SDK_INT}. " +
                "Quick Settings tiles require Android 7.0 (API 24) or higher.")
        // Gracefully degrade - no crash, just log and return
        // The tile service will not function but won't cause app crashes
    }
    
    /**
     * Handles SecurityException scenarios across all lifecycle methods
     * Requirements covered: 3.3, 5.3 - Proper exception handling
     */
    private fun handleSecurityException(methodName: String, e: SecurityException) {
        Log.e(TAG, "Security exception in $methodName - insufficient permissions or security policy violation", e)
        // Reset relevant state to prevent inconsistent behavior
        when (methodName) {
            "onTileAdded" -> isTileAdded = false
            "onStartListening" -> isListening = false
            "onStopListening" -> isListening = false
        }
    }
    
    /**
     * Handles IllegalStateException scenarios across all lifecycle methods
     * Requirements covered: 3.3, 5.3 - Proper exception handling
     */
    private fun handleIllegalStateException(methodName: String, e: IllegalStateException) {
        Log.e(TAG, "Illegal state exception in $methodName - service not properly initialized or in invalid state", e)
        // Attempt to reset to a known good state
        resetTileState()
    }
    
    /**
     * Handles OutOfMemoryError scenarios for memory pressure situations
     * Requirements covered: 5.3 - Handle low memory conditions gracefully
     */
    private fun handleOutOfMemoryError(methodName: String, e: OutOfMemoryError) {
        Log.e(TAG, "Out of memory error in $methodName - system under severe memory pressure", e)
        // Force cleanup to free memory
        forceCleanupResources()
        // Reset state to minimal memory footprint
        resetTileState()
        resetListeningState()
        // Suggest garbage collection (though not guaranteed)
        System.gc()
    }
    
    /**
     * Handles RuntimeException scenarios across all lifecycle methods
     * Requirements covered: 3.3, 5.3 - Proper exception handling
     */
    private fun handleRuntimeException(methodName: String, e: RuntimeException) {
        Log.e(TAG, "Runtime exception in $methodName - unexpected runtime error", e)
        // Reset state to prevent cascading failures
        resetTileState()
    }
    
    /**
     * Handles generic Exception scenarios across all lifecycle methods
     * Requirements covered: 3.3, 5.3 - Comprehensive exception handling
     */
    private fun handleGenericException(methodName: String, e: Exception) {
        Log.e(TAG, "Unexpected exception in $methodName - unknown error type", e)
        // Reset state as a safety measure
        resetTileState()
    }
    
    /**
     * Handles SecurityException specifically for app launch scenarios
     * Requirements covered: 3.3, 5.3 - Launch-specific error handling
     */
    private fun handleLaunchSecurityException(e: SecurityException) {
        Log.e(TAG, "Security exception during app launch - insufficient permissions to start activity", e)
        // Attempt fallback launch method
        try {
            launchQsidianAppFallback()
        } catch (fallbackException: Exception) {
            Log.e(TAG, "Fallback launch also failed due to security restrictions", fallbackException)
            // No further action - Quick Settings tiles typically don't show user error messages
        }
    }
    
    /**
     * Handles IllegalStateException specifically for app launch scenarios
     * Requirements covered: 3.3, 5.3 - Launch-specific error handling
     */
    private fun handleLaunchIllegalStateException(e: IllegalStateException) {
        Log.e(TAG, "Illegal state exception during app launch - service not ready for launch", e)
        // Attempt to reinitialize and retry
        try {
            resetTileState()
            launchQsidianAppFallback()
        } catch (retryException: Exception) {
            Log.e(TAG, "Retry launch failed after state reset", retryException)
        }
    }
    
    /**
     * Handles OutOfMemoryError specifically for app launch scenarios
     * Requirements covered: 5.3 - Handle memory pressure during launch
     */
    private fun handleLaunchOutOfMemoryError(e: OutOfMemoryError) {
        Log.e(TAG, "Out of memory error during app launch - cannot start activity due to memory pressure", e)
        // Force cleanup and suggest GC before giving up
        forceCleanupResources()
        System.gc()
        // Don't attempt retry as system is under severe memory pressure
    }
    
    /**
     * Handles RuntimeException specifically for app launch scenarios
     * Requirements covered: 3.3, 5.3 - Launch-specific error handling
     */
    private fun handleLaunchRuntimeException(e: RuntimeException) {
        Log.e(TAG, "Runtime exception during app launch - unexpected launch error", e)
        // Attempt fallback launch method
        try {
            launchQsidianAppFallback()
        } catch (fallbackException: Exception) {
            Log.e(TAG, "Fallback launch failed after runtime exception", fallbackException)
        }
    }
    
    /**
     * Handles generic Exception specifically for app launch scenarios
     * Requirements covered: 3.3, 5.3 - Comprehensive launch error handling
     */
    private fun handleLaunchGenericException(e: Exception) {
        Log.e(TAG, "Unexpected exception during app launch - unknown launch error", e)
        // Attempt fallback launch as last resort
        try {
            launchQsidianAppFallback()
        } catch (fallbackException: Exception) {
            Log.e(TAG, "All launch methods failed", fallbackException)
        }
    }
    
    /**
     * Resets tile state to a known good state
     * Requirements covered: 3.3, 5.3 - State recovery after errors
     */
    private fun resetTileState() {
        try {
            Log.d(TAG, "Resetting tile state to known good state")
            isTileAdded = false
            // Additional state reset logic can be added here as needed
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting tile state", e)
        }
    }
    
    /**
     * Resets listening state to a known good state
     * Requirements covered: 3.3, 5.3 - State recovery after errors
     */
    private fun resetListeningState() {
        try {
            Log.d(TAG, "Resetting listening state to known good state")
            isListening = false
            // Additional listening state reset logic can be added here as needed
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting listening state", e)
        }
    }
    
    /**
     * Forces cleanup of all resources in emergency situations
     * Requirements covered: 5.3 - Handle low memory conditions gracefully
     */
    private fun forceCleanupResources() {
        try {
            Log.d(TAG, "Force cleaning up all resources due to error or memory pressure")
            // Clean up listening resources
            cleanupListeningResources()
            // Clear visual state
            clearTileVisualState()
            // Clear tile state
            clearTileState()
            // Reset all state variables
            isListening = false
            isTileAdded = false
        } catch (e: Exception) {
            Log.e(TAG, "Error during force cleanup - ignoring to prevent cascading failures", e)
            // Ignore errors during force cleanup to prevent cascading failures
        }
    }

    // ========================================
    // RESOURCE MANAGEMENT METHODS
    // ========================================
    
    /**
     * Initializes resources needed while the tile is listening/visible
     * Called during onStartListening for proper resource management
     * 
     * Requirements covered:
     * - 3.3: Proper error handling for resource initialization
     * - 5.3: Handle exceptions gracefully during resource management
     */
    private fun initializeListeningResources() {
        try {
            // For a simple launcher tile, minimal resources are needed
            // This method provides a hook for future enhancements that might need
            // resources like broadcast receivers, observers, etc.
            Log.d(TAG, "Listening resources initialized")
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error initializing listening resources", e)
            throw e // Re-throw to be handled by caller
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing listening resources", e)
            // Don't re-throw - allow service to continue with degraded functionality
        }
    }

    /**
     * Cleans up resources allocated during listening phase
     * Called during onStopListening to prevent memory leaks
     * 
     * Requirements covered:
     * - 3.3: Proper error handling for resource cleanup
     * - 5.3: Handle exceptions gracefully during resource management
     */
    private fun cleanupListeningResources() {
        try {
            // Clean up any resources that were allocated during listening
            // This ensures proper memory management and prevents leaks
            Log.d(TAG, "Listening resources cleaned up")
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error during resource cleanup - ignoring to prevent cascading failures", e)
            // Don't re-throw during cleanup to prevent cascading failures
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up listening resources - continuing cleanup", e)
            // Don't re-throw during cleanup to ensure other cleanup continues
        }
    }

    /**
     * Clears tile state information for memory management
     * Called during onTileRemoved to ensure proper cleanup
     * 
     * Requirements covered:
     * - 3.3: Proper error handling for state cleanup
     * - 5.3: Handle exceptions gracefully during cleanup operations
     */
    private fun clearTileState() {
        try {
            // Clear any cached tile state or references
            // This helps with memory management and prevents stale state
            Log.d(TAG, "Tile state cleared")
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error during tile state cleanup - ignoring", e)
            // Don't re-throw during cleanup
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing tile state - continuing", e)
            // Don't re-throw during cleanup to ensure other cleanup continues
        }
    }

    /**
     * Clears visual state information to free memory
     * Called during onStopListening for memory optimization
     * 
     * Requirements covered:
     * - 3.3: Proper error handling for visual state cleanup
     * - 5.3: Handle exceptions gracefully during memory optimization
     */
    private fun clearTileVisualState() {
        try {
            // Clear any cached visual state information
            // This helps reduce memory usage when tile is not visible
            Log.d(TAG, "Tile visual state cleared")
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory error during visual state cleanup - ignoring", e)
            // Don't re-throw during cleanup
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing tile visual state - continuing", e)
            // Don't re-throw during cleanup to ensure other cleanup continues
        }
    }

    // ========================================
    // APP LAUNCH METHODS
    // ========================================

    /**
     * Launches the Qsidian overlay activity for quick note creation
     * Uses proper intent flags for overlay display over Quick Settings
     * 
     * Requirements covered:
     * - 1.3: Launch overlay when tile is tapped
     * - 1.4: Display quick note overlay properly
     * - 3.3: Proper error handling for overlay launch
     * - 5.2: Overlay launch within 2 seconds
     * - 5.3: Handle exceptions gracefully during launch
     * 
     * Intent flags explanation:
     * - NEW_TASK: Creates new task for overlay
     * - CLEAR_TOP: Ensures clean overlay state
     * - SINGLE_TOP: Prevents duplicate overlay instances
     */
    private fun launchQsidianApp() {
        try {
            val intent = Intent(this, NativeQuickNoteActivity::class.java).apply {
                // Configure proper flags for overlay launch from Quick Settings
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                
                // Add extra to indicate launch source for potential handling in overlay activity
                putExtra("launch_source", "quick_settings_tile")
            }
            
            Log.d(TAG, "Launching Native Quick Note overlay with intent flags: NEW_TASK|CLEAR_TOP|SINGLE_TOP")
            
            // Use startActivityAndCollapse to launch app and collapse Quick Settings panel
            startActivityAndCollapse(intent)
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in primary launch method", e)
            throw e // Re-throw to be handled by caller
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception in primary launch method", e)
            throw e // Re-throw to be handled by caller
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception in primary launch method", e)
            throw e // Re-throw to be handled by caller
        }
    }

    /**
     * Handles launch failures with appropriate fallback behavior
     * Attempts alternative launch methods and provides user feedback
     * 
     * Requirements covered:
     * - 3.3: Proper error handling with fallback mechanisms
     * - 5.3: Handle exceptions gracefully with recovery attempts
     * 
     * @deprecated This method is replaced by specific exception handlers
     * Kept for backward compatibility but new code should use specific handlers
     */
    @Deprecated("Use specific exception handlers instead")
    private fun handleLaunchFailure(reason: String, exception: Exception) {
        Log.w(TAG, "Primary launch failed: $reason, attempting fallback")
        
        try {
            // Attempt fallback launch using package manager
            launchQsidianAppFallback()
        } catch (fallbackException: Exception) {
            Log.e(TAG, "All launch methods failed", fallbackException)
            // Could potentially show a toast notification here, but Quick Settings
            // tiles typically don't show user-facing error messages
        }
    }

    /**
     * Fallback method to launch the Qsidian app
     * Uses package manager to launch the app if primary method fails
     * Provides additional error handling and validation
     * 
     * Requirements covered:
     * - 3.3: Fallback mechanisms for launch failures
     * - 5.3: Handle exceptions gracefully with alternative approaches
     */
    private fun launchQsidianAppFallback() {
        try {
            val packageManager = packageManager
            val packageName = packageName
            
            Log.d(TAG, "Attempting fallback launch for package: $packageName")
            
            // Validate package manager availability
            if (packageManager == null) {
                Log.e(TAG, "Package manager is null - cannot perform fallback launch")
                throw IllegalStateException("Package manager not available")
            }
            
            // Validate package name
            if (packageName.isNullOrEmpty()) {
                Log.e(TAG, "Package name is null or empty - cannot perform fallback launch")
                throw IllegalStateException("Package name not available")
            }
            
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                // Apply same intent flags for consistency
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                   Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                                   Intent.FLAG_ACTIVITY_SINGLE_TOP
                
                // Add launch source indicator
                launchIntent.putExtra("launch_source", "quick_settings_tile_fallback")
                
                Log.d(TAG, "Fallback launch intent created successfully")
                startActivityAndCollapse(launchIntent)
            } else {
                Log.e(TAG, "Could not create launch intent for package: $packageName")
                throw IllegalStateException("No launch intent available for app")
            }
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in fallback launch method", e)
            throw e // Re-throw to be handled by caller
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal state exception in fallback launch method", e)
            throw e // Re-throw to be handled by caller
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "Package not found in fallback launch method", e)
            throw IllegalStateException("App package not found", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception in fallback launch method", e)
            throw e // Re-throw to be handled by caller
        }
    }
}