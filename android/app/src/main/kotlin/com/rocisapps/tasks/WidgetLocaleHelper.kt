package com.rocisapps.tasks

import android.content.SharedPreferences
import java.text.DateFormatSymbols
import java.util.Calendar
import java.util.Locale

object WidgetLocaleHelper {

    fun getWidgetLocale(widgetData: SharedPreferences): Locale {
        val langCode = widgetData.getString("app_language", null)
            ?: widgetData.getString("language_code", null)

        if (!langCode.isNullOrEmpty() && langCode != "system") {
            return try {
                if (langCode.contains("_")) {
                    val parts = langCode.split("_")
                    Locale(parts[0], parts[1])
                } else if (langCode.contains("-")) {
                    val parts = langCode.split("-")
                    Locale(parts[0], parts[1])
                } else {
                    Locale(langCode)
                }
            } catch (_: Exception) {
                Locale.getDefault()
            }
        }
        return Locale.getDefault()
    }

    /**
     * Returns a 7-element list of single-letter or short weekday abbreviations for columns 0..6
     * given the user's chosen [startOfWeek] (1 = Mon, ..., 7 = Sun) and the widget [locale].
     */
    fun getWeekdayLetters(startOfWeek: Int, locale: Locale): List<String> {
        val symbols = DateFormatSymbols(locale)
        val shortWeekdays = symbols.shortWeekdays // index 1 = Sun, 2 = Mon, ..., 7 = Sat

        // Build list for 1=Mon .. 7=Sun
        val orderedLetters = ArrayList<String>()
        // 1=Mon .. 6=Sat
        for (day in Calendar.MONDAY..Calendar.SATURDAY) {
            val name = shortWeekdays[day]
            orderedLetters.add(extractShortSymbol(name, locale))
        }
        // 7=Sun
        val sunName = shortWeekdays[Calendar.SUNDAY]
        orderedLetters.add(extractShortSymbol(sunName, locale))

        // Return reordered according to startOfWeek
        val result = mutableListOf<String>()
        for (col in 0..6) {
            val dayOfWeek = (startOfWeek + col - 1) % 7 + 1 // 1..7 (1=Mon, ..., 7=Sun)
            result.add(orderedLetters[dayOfWeek - 1])
        }
        return result
    }

    private fun extractShortSymbol(name: String?, locale: Locale): String {
        if (name.isNullOrEmpty()) return ""
        val lang = locale.language.lowercase()
        return if (lang in listOf("he", "ar", "hi", "zh", "ja", "ko", "ru")) {
            name.trim().take(1)
        } else {
            name.trim().take(1).uppercase(locale)
        }
    }

    fun getAllDayText(locale: Locale): String {
        return when (locale.language.lowercase()) {
            "he" -> "כל היום"
            "es" -> "Todo el día"
            "de" -> "Ganztägig"
            "fr" -> "Toute la journée"
            "ar" -> "طوال اليوم"
            "sv" -> "Hela dagen"
            "hi" -> "पूरा दिन"
            else -> "All Day"
        }
    }

    fun getNoTasksText(locale: Locale): String {
        return when (locale.language.lowercase()) {
            "he" -> "אין משימות להיום"
            "es" -> "No hay tareas para hoy"
            "de" -> "Keine Aufgaben für heute"
            "fr" -> "Aucune tâche pour aujourd'hui"
            "ar" -> "لا توجد مهام لليوم"
            "sv" -> "Inga uppgifter för idag"
            "hi" -> "आज के लिए कोई कार्य नहीं"
            else -> "No tasks for today"
        }
    }

    fun getTodayText(locale: Locale): String {
        return when (locale.language.lowercase()) {
            "he" -> "היום"
            "es" -> "Hoy"
            "de" -> "Heute"
            "fr" -> "Aujourd'hui"
            "ar" -> "اليوم"
            "sv" -> "Idag"
            "hi" -> "आज"
            else -> "Today"
        }
    }
}

