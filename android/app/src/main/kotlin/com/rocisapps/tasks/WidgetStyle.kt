package com.rocisapps.tasks

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.util.Locale

/**
 * Shared design system for every home screen widget: the app's card (GlassContainer
 * colors synced from MyApp), Outfit type, tinted icons, RTL and the localized free-tier
 * overlay. Widgets color themselves from one [FullCalendarWidgetUtils.Palette].
 */
object WidgetStyle {

    // Task priority colors, same as the app's task tiles / kanban cards.
    val PRIORITY_HIGH = Color.parseColor("#EF4444")
    val PRIORITY_MEDIUM = Color.parseColor("#F59E0B")
    val PRIORITY_LOW = Color.parseColor("#10B981")

    fun theme(widgetData: SharedPreferences): String =
        widgetData.getString(FullCalendarWidgetUtils.PREF_THEME, FullCalendarWidgetUtils.DEFAULT_THEME)
            ?: FullCalendarWidgetUtils.DEFAULT_THEME

    fun palette(context: Context, widgetData: SharedPreferences): FullCalendarWidgetUtils.Palette =
        FullCalendarWidgetUtils.resolvePalette(widgetData, theme(widgetData), context)

    /** [color] with its alpha replaced by [alpha] (0..255). */
    fun withAlpha(color: Int, alpha: Int): Int = (color and 0x00FFFFFF) or (alpha shl 24)

    /** Parses "#RRGGBB"/"#AARRGGBB", or returns [fallback]. */
    fun parseColor(hex: String?, fallback: Int): Int {
        if (hex.isNullOrEmpty() || !hex.startsWith("#")) return fallback
        return try { Color.parseColor(hex) } catch (_: Exception) { fallback }
    }

    /**
     * Colors a card made of a `widget_card_fill` + `widget_card_stroke` ImageView pair:
     * surfaceContainerLow fill (80% when glassmorphic) and a 12% primary border.
     */
    fun applyCard(views: RemoteViews, palette: FullCalendarWidgetUtils.Palette, fillId: Int, strokeId: Int) {
        views.setInt(fillId, "setColorFilter", palette.surface)
        views.setInt(fillId, "setImageAlpha", if (palette.translucent) 0xCC else 0xFF)
        views.setInt(strokeId, "setColorFilter", palette.primary)
        views.setInt(strokeId, "setImageAlpha", 0x1F)
    }

    /** Colors a tile made of a fill + optional stroke ImageView (list rows, buttons). */
    fun applyTile(views: RemoteViews, fillId: Int, fill: Int, fillAlpha: Int, strokeId: Int? = null, stroke: Int = fill, strokeAlpha: Int = 0) {
        views.setInt(fillId, "setColorFilter", fill)
        views.setInt(fillId, "setImageAlpha", fillAlpha)
        if (strokeId != null) {
            views.setInt(strokeId, "setColorFilter", stroke)
            views.setInt(strokeId, "setImageAlpha", strokeAlpha)
        }
    }

    fun tint(views: RemoteViews, color: Int, vararg imageIds: Int) {
        imageIds.forEach { views.setInt(it, "setColorFilter", color) }
    }

    fun applyDirection(views: RemoteViews, rootId: Int, locale: Locale) {
        views.setInt(
            rootId, "setLayoutDirection",
            if (WidgetLocaleHelper.isRtl(locale)) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        )
    }

    /** Color for a task priority string ("high"/"medium"/"low"), or null for none. */
    fun priorityColor(priority: String?): Int? = when (priority?.lowercase()) {
        "high" -> PRIORITY_HIGH
        "medium" -> PRIORITY_MEDIUM
        "low" -> PRIORITY_LOW
        else -> null
    }

    fun priorityLabel(priority: String?, locale: Locale): String? {
        val lang = WidgetLocaleHelper.getNormalizedLanguage(locale)
        return when (priority?.lowercase()) {
            "high" -> when (lang) {
                "he" -> "גבוהה"; "es" -> "Alta"; "de" -> "Hoch"; "fr" -> "Haute"
                "ar" -> "عالية"; "sv" -> "Hög"; "hi" -> "उच्च"; else -> "High"
            }
            "medium" -> when (lang) {
                "he" -> "בינונית"; "es" -> "Media"; "de" -> "Mittel"; "fr" -> "Moyenne"
                "ar" -> "متوسطة"; "sv" -> "Medel"; "hi" -> "मध्यम"; else -> "Medium"
            }
            "low" -> when (lang) {
                "he" -> "נמוכה"; "es" -> "Baja"; "de" -> "Niedrig"; "fr" -> "Basse"
                "ar" -> "منخفضة"; "sv" -> "Låg"; "hi" -> "निम्न"; else -> "Low"
            }
            else -> null
        }
    }

    fun overdueText(locale: Locale): String = when (WidgetLocaleHelper.getNormalizedLanguage(locale)) {
        "he" -> "באיחור"; "es" -> "Vencida"; "de" -> "Überfällig"; "fr" -> "En retard"
        "ar" -> "متأخرة"; "sv" -> "Försenad"; "hi" -> "अतिदेय"; else -> "Overdue"
    }

    private fun proTitle(lang: String) = when (lang) {
        "he" -> "מגבלת וידג׳ט אחד"; "es" -> "Límite de 1 widget"; "de" -> "Limit: 1 Widget"
        "fr" -> "Limite de 1 widget"; "ar" -> "حد الأداة الواحدة"; "sv" -> "Gräns: 1 widget"
        "hi" -> "1 विजेट की सीमा"; else -> "Free 1-Widget Limit"
    }

    private fun proDesc(lang: String) = when (lang) {
        "he" -> "בגרסה החינמית וידג׳ט פעיל אחד. שדרגו ל-Pro לווידג׳טים ללא הגבלה."
        "es" -> "El plan gratuito incluye 1 widget activo. Pasa a Pro para widgets ilimitados."
        "de" -> "Kostenlos ist 1 aktives Widget enthalten. Mit Pro unbegrenzt viele Widgets."
        "fr" -> "L'offre gratuite inclut 1 widget actif. Passez à Pro pour des widgets illimités."
        "ar" -> "الخطة المجانية تتضمن أداة واحدة نشطة. رقِّ إلى Pro لأدوات غير محدودة."
        "sv" -> "Gratis ingår 1 aktiv widget. Uppgradera till Pro för obegränsat antal."
        "hi" -> "मुफ़्त प्लान में 1 सक्रिय विजेट है। असीमित विजेट के लिए Pro लें।"
        else -> "Free includes 1 active widget. Upgrade to Pro for unlimited widgets."
    }

    private fun proButton(lang: String) = when (lang) {
        "he" -> "שדרוג ל-Pro"; "es" -> "Obtener Pro"; "de" -> "Pro holen"; "fr" -> "Passer à Pro"
        "ar" -> "الترقية إلى Pro"; "sv" -> "Skaffa Pro"; "hi" -> "Pro लें"; else -> "Get Pro"
    }

    /**
     * Shows or hides the shared `widget_pro_overlay` include: card-colored scrim, localized
     * text, accent button, opens the paywall.
     */
    fun setupProOverlay(
        context: Context,
        views: RemoteViews,
        isAllowed: Boolean,
        palette: FullCalendarWidgetUtils.Palette,
        locale: Locale
    ) {
        if (isAllowed) {
            views.setViewVisibility(R.id.widget_pro_overlay, View.GONE)
            return
        }
        val lang = WidgetLocaleHelper.getNormalizedLanguage(locale)
        views.setViewVisibility(R.id.widget_pro_overlay, View.VISIBLE)
        views.setInt(R.id.widget_pro_overlay_scrim, "setColorFilter", palette.surface)
        views.setInt(R.id.widget_pro_overlay_scrim, "setImageAlpha", 0xF2)
        views.setInt(R.id.widget_pro_overlay_icon, "setColorFilter", palette.primary)
        views.setTextViewText(R.id.widget_pro_overlay_title, proTitle(lang))
        views.setTextColor(R.id.widget_pro_overlay_title, palette.onSurface)
        views.setTextViewText(R.id.widget_pro_overlay_desc, proDesc(lang))
        views.setTextColor(R.id.widget_pro_overlay_desc, palette.onSurfaceMuted)
        views.setInt(R.id.widget_pro_overlay_btn_fill, "setColorFilter", palette.primary)
        views.setTextViewText(R.id.widget_pro_overlay_btn_text, proButton(lang))
        views.setTextColor(R.id.widget_pro_overlay_btn_text, onColor(palette.primary))
        val paywall = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://paywall"))
        views.setOnClickPendingIntent(R.id.widget_pro_overlay_btn, paywall)
        views.setOnClickPendingIntent(R.id.widget_pro_overlay, paywall)
    }

    /** Black or white, whichever reads better on [background]. */
    fun onColor(background: Int): Int {
        val luminance = (0.299 * Color.red(background) + 0.587 * Color.green(background) + 0.114 * Color.blue(background)) / 255
        return if (luminance > 0.6) Color.BLACK else Color.WHITE
    }
}
