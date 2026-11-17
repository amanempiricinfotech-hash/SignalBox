package com.signalbox.signalbox

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * Reads the applications actually installed on this device.
 *
 * SignalBox does not ship a hard-coded list of applications: everything the
 * Applications screen shows comes from here.
 *
 * Package visibility: on Android 11 (API 30) and above an app can only see
 * other packages it declares an interest in. Rather than request the
 * restricted QUERY_ALL_PACKAGES permission, the manifest declares a <queries>
 * entry for the launcher intent. That makes every launchable application
 * visible, which covers everything a user would recognise as an app, and it
 * needs no special Play Store justification.
 */
object InstalledAppsReader {

    private const val ICON_SIZE_PX = 128

    /**
     * Every launchable application on the device, excluding SignalBox itself,
     * sorted by display label.
     */
    fun installedApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN, null)
            .addCategory(Intent.CATEGORY_LAUNCHER)

        return pm.queryIntentActivities(launcherIntent, 0)
            .mapNotNull { resolveInfo ->
                val info = resolveInfo.activityInfo?.applicationInfo
                    ?: return@mapNotNull null
                if (info.packageName == context.packageName) return@mapNotNull null

                mapOf(
                    "packageName" to info.packageName,
                    "appLabel" to pm.getApplicationLabel(info).toString(),
                    "isSystemApp" to ((info.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                )
            }
            .distinctBy { it["packageName"] as String }
            .sortedBy { (it["appLabel"] as String).lowercase() }
    }

    /**
     * Resolves the user visible label for one package.
     *
     * Falls back to the package name when the application is not installed or
     * is not visible to us.
     */
    fun appLabel(context: Context, packageName: String): String {
        return try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    /**
     * The application's launcher icon as PNG bytes, or null when it cannot be
     * resolved. Icons are rasterised at [ICON_SIZE_PX] so that adaptive and
     * vector drawables cross the platform channel as plain bitmaps.
     */
    fun appIcon(context: Context, packageName: String): ByteArray? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            drawable.toPngBytes()
        } catch (e: Exception) {
            null
        }
    }

    private fun Drawable.toPngBytes(): ByteArray? {
        val bitmap = if (this is BitmapDrawable && this.bitmap != null) {
            Bitmap.createScaledBitmap(this.bitmap, ICON_SIZE_PX, ICON_SIZE_PX, true)
        } else {
            val created = Bitmap.createBitmap(
                ICON_SIZE_PX,
                ICON_SIZE_PX,
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(created)
            setBounds(0, 0, canvas.width, canvas.height)
            draw(canvas)
            created
        }

        return ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        }
    }
}
