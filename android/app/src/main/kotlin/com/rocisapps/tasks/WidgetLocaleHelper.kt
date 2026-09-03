package com.rocisapps.tasks

import android.content.SharedPreferences
import java.text.DateFormatSymbols
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object WidgetLocaleHelper {

    fun getNormalizedLanguage(locale: Locale): String {
        return when (val lang = locale.language.lowercase()) {
            "iw" -> "he"
            "in" -> "id"
            "ji" -> "yi"
            else -> lang
        }
    }

    fun getWidgetLocale(widgetData: SharedPreferences): Locale {
        val langCode = widgetData.getString("app_language", null)
            ?: widgetData.getString("language_code", null)

        if (!langCode.isNullOrEmpty() && langCode != "system") {
            return try {
                if (langCode.contains("_") || langCode.contains("-")) {
                    val parts = langCode.split(Regex("[_-]"))
                    if (parts.size >= 2) Locale(parts[0], parts[1]) else Locale(parts[0])
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
        val lang = getNormalizedLanguage(locale)

        // Custom accurate single-letter mappings for languages where take(1) fails
        val dayLettersSunToSat: List<String> = when (lang) {
            "he" -> listOf("א", "ב", "ג", "ד", "ה", "ו", "ש")
            "ar" -> listOf("ح", "ن", "ث", "ر", "خ", "ج", "س")
            "hi" -> listOf("र", "सो", "मं", "बु", "गु", "शु", "श")
            "es" -> listOf("D", "L", "M", "X", "J", "V", "S")
            "fr" -> listOf("D", "L", "M", "M", "J", "V", "S")
            "de" -> listOf("S", "M", "D", "M", "D", "F", "S")
            "sv" -> listOf("S", "M", "T", "O", "T", "F", "L")
            else -> {
                val symbols = DateFormatSymbols(locale)
                val shortWeekdays = symbols.shortWeekdays // 1=Sun, 2=Mon...
                (Calendar.SUNDAY..Calendar.SATURDAY).map { day ->
                    val name = shortWeekdays[day]
                    if (name.isNullOrEmpty()) "" else name.trim().take(1).uppercase(locale)
                }
            }
        }

        // Ordered 1=Mon .. 7=Sun
        val orderedLetters = listOf(
            dayLettersSunToSat[1], // Mon
            dayLettersSunToSat[2], // Tue
            dayLettersSunToSat[3], // Wed
            dayLettersSunToSat[4], // Thu
            dayLettersSunToSat[5], // Fri
            dayLettersSunToSat[6], // Sat
            dayLettersSunToSat[0]  // Sun
        )

        // Reorder according to startOfWeek (1=Mon .. 7=Sun)
        val result = mutableListOf<String>()
        for (col in 0..6) {
            val dayOfWeek = (startOfWeek + col - 1) % 7 + 1
            result.add(orderedLetters[dayOfWeek - 1])
        }
        return result
    }

    /**
     * Formats Month and Year using the best ICU pattern for [locale].
     */
    fun getMonthYearTitle(cal: Calendar, locale: Locale): String {
        return try {
            val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "yyyyMMMM")
            SimpleDateFormat(pattern, locale).format(cal.time)
        } catch (_: Exception) {
            SimpleDateFormat("MMMM yyyy", locale).format(cal.time)
        }
    }

    /**
     * Formats date titles like "Thursday, Sep 3" with locale-aware day/month ordering.
     */
    fun getDateTitle(cal: Calendar, locale: Locale, full: Boolean = false): String {
        return try {
            val skeleton = if (full) "EEEEMMMd" else "EEEMMMd"
            val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, skeleton)
            SimpleDateFormat(pattern, locale).format(cal.time)
        } catch (_: Exception) {
            val pattern = if (full) "EEEE, MMM d" else "EEE, MMM d"
            SimpleDateFormat(pattern, locale).format(cal.time)
        }
    }

    fun getTodayText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
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

    fun getTomorrowText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "מחר"
            "es" -> "Mañana"
            "de" -> "Morgen"
            "fr" -> "Demain"
            "ar" -> "غداً"
            "sv" -> "Imorgon"
            "hi" -> "कल"
            else -> "Tomorrow"
        }
    }

    fun getYesterdayText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "אתמול"
            "es" -> "Ayer"
            "de" -> "Gestern"
            "fr" -> "Hier"
            "ar" -> "أمس"
            "sv" -> "Igår"
            "hi" -> "कल"
            else -> "Yesterday"
        }
    }

    fun getAllDayText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
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
        return when (getNormalizedLanguage(locale)) {
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

    fun getTasksFilterText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "משימות"
            "es" -> "Tareas"
            "de" -> "Aufgaben"
            "fr" -> "Tâches"
            "ar" -> "المهام"
            "sv" -> "Uppgifter"
            "hi" -> "कार्य"
            else -> "Tasks"
        }
    }

    fun getGoogleFilterText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "גוגל"
            "ar" -> "جوجل"
            "hi" -> "गूगल"
            else -> "Google"
        }
    }

    fun getScheduleFilterText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "לוח זמנים"
            "es" -> "Horario"
            "de" -> "Zeitplan"
            "fr" -> "Calendrier"
            "ar" -> "الجدول"
            "sv" -> "Schema"
            "hi" -> "समय सारिणी"
            else -> "Schedule"
        }
    }

    fun getNoDataAvailableText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "אין נתונים זמינים"
            "es" -> "No hay datos disponibles"
            "de" -> "Keine Daten verfügbar"
            "fr" -> "Aucune donnée disponible"
            "ar" -> "لا تتوفر بيانات"
            "sv" -> "Ingen data tillgänglig"
            "hi" -> "कोई डेटा उपलब्ध नहीं"
            else -> "No data available"
        }
    }

    fun getNoEventsOrTasksText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "אין אירועים או משימות"
            "es" -> "No hay eventos ni tareas"
            "de" -> "Keine Termine oder Aufgaben"
            "fr" -> "Aucun événement ou tâche"
            "ar" -> "لا توجد أحداث أو مهام"
            "sv" -> "Inga händelser eller uppgifter"
            "hi" -> "कोई घटना या कार्य नहीं"
            else -> "No events or tasks"
        }
    }

    fun getNoTasksOrEventsText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "אין משימות או אירועים"
            "es" -> "No hay tareas ni eventos"
            "de" -> "Keine Aufgaben oder Termine"
            "fr" -> "Aucune tâche ou événement"
            "ar" -> "لا توجد مهام أو أحداث"
            "sv" -> "Inga uppgifter eller händelser"
            "hi" -> "कोई कार्य या घटना नहीं"
            else -> "No tasks or events"
        }
    }

    fun getTapPlusToAddText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "הקש + כדי להוסיף משימה"
            "es" -> "Toca + para agregar una tarea"
            "de" -> "Tippe auf +, um eine Aufgabe hinzuzufügen"
            "fr" -> "Appuyez sur + pour ajouter une tâche"
            "ar" -> "اضغط + لإضافة مهمة"
            "sv" -> "Tryck på + för att lägga till en uppgift"
            "hi" -> "कार्य जोड़ने के लिए + दबाएं"
            else -> "Tap + to add a task"
        }
    }

    fun getPendingTasksText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "משימות פתוחות"
            "es" -> "Tareas pendientes"
            "de" -> "Ausstehende Aufgaben"
            "fr" -> "Tâches en attente"
            "ar" -> "المهام المعلقة"
            "sv" -> "Väntande uppgifter"
            "hi" -> "लंबित कार्य"
            else -> "Pending Tasks"
        }
    }

    fun getSortButtonText(sortMode: Int, locale: Locale): String {
        val lang = getNormalizedLanguage(locale)
        return if (sortMode == 0) {
            when (lang) {
                "he" -> "מיון: תאריך"
                "es" -> "Ordenar: Fecha"
                "de" -> "Sortieren: Datum"
                "fr" -> "Trier: Date"
                "ar" -> "ترتيب: التاريخ"
                "sv" -> "Sortera: Datum"
                "hi" -> "क्रमबद्ध: तिथि"
                else -> "Sort: Date"
            }
        } else {
            when (lang) {
                "he" -> "מיון: עדיפות"
                "es" -> "Ordenar: Prioridad"
                "de" -> "Sortieren: Priorität"
                "fr" -> "Trier: Priorité"
                "ar" -> "ترتيب: الأولوية"
                "sv" -> "Sortera: Prioritet"
                "hi" -> "क्रमबद्ध: प्राथमिकता"
                else -> "Sort: Priority"
            }
        }
    }

    fun getFilterButtonText(filterMode: Int, isPremium: Boolean, locale: Locale): String {
        val lang = getNormalizedLanguage(locale)
        return when (filterMode) {
            1 -> when (lang) {
                "he" -> "סינון: היום"
                "es" -> "Filtro: Hoy"
                "de" -> "Filter: Heute"
                "fr" -> "Filtre: Aujourd'hui"
                "ar" -> "تصفية: اليوم"
                "sv" -> "Filter: Idag"
                "hi" -> "फ़िल्टर: आज"
                else -> "Filter: Today"
            }
            2 -> when (lang) {
                "he" -> "סינון: עדיפות גבוהה"
                "es" -> "Filtro: Alta Prioridad"
                "de" -> "Filter: Hohe Priorität"
                "fr" -> "Filtre: Haute Priorité"
                "ar" -> "تصفية: أولوية عالية"
                "sv" -> "Filter: Hög prioritet"
                "hi" -> "फ़िल्टर: उच्च प्राथमिकता"
                else -> "Filter: High Prio"
            }
            3 -> if (isPremium) {
                when (lang) {
                    "he" -> "סינון: באיחור"
                    "es" -> "Filtro: Vencidas"
                    "de" -> "Filter: Überfällig"
                    "fr" -> "Filtre: En retard"
                    "ar" -> "تصفية: متأخرة"
                    "sv" -> "Filter: Försenad"
                    "hi" -> "फ़िल्टर: अतिदेय"
                    else -> "Filter: Overdue"
                }
            } else "Filter: PRO"
            4 -> if (isPremium) {
                when (lang) {
                    "he" -> "סינון: מוצמדות"
                    "es" -> "Filtro: Fijadas"
                    "de" -> "Filter: Angeheftet"
                    "fr" -> "Filtre: Épinglées"
                    "ar" -> "تصفية: مثبتة"
                    "sv" -> "Filter: Fästa"
                    "hi" -> "फ़िल्टर: पिन किए गए"
                    else -> "Filter: Pinned"
                }
            } else "Filter: PRO"
            else -> when (lang) {
                "he" -> "סינון: הכל"
                "es" -> "Filtro: Todas"
                "de" -> "Filter: Alle"
                "fr" -> "Filtre: Tout"
                "ar" -> "تصفية: الكل"
                "sv" -> "Filter: Alla"
                "hi" -> "फ़िल्टर: सभी"
                else -> "Filter: All"
            }
        }
    }

    fun getNoPendingTasksText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "אין משימות פתוחות"
            "es" -> "No hay tareas pendientes"
            "de" -> "Keine ausstehenden Aufgaben"
            "fr" -> "Aucune tâche en attente"
            "ar" -> "لا توجد مهام معلقة"
            "sv" -> "Inga väntande uppgifter"
            "hi" -> "कोई लंबित कार्य नहीं"
            else -> "No pending tasks"
        }
    }

    fun getScheduleTimelineText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "לוח זמנים"
            "es" -> "Línea de tiempo"
            "de" -> "Zeitachse"
            "fr" -> "Chronologie"
            "ar" -> "الجدول الزمني"
            "sv" -> "Tidslinje"
            "hi" -> "समयरेखा"
            else -> "Schedule Timeline"
        }
    }

    fun getKanbanColumnTitle(columnIndex: Int, locale: Locale): String {
        val lang = getNormalizedLanguage(locale)
        return when (columnIndex) {
            1 -> when (lang) {
                "he" -> "בפוקוס"
                "es" -> "En Foco"
                "de" -> "Im Fokus"
                "fr" -> "En Focus"
                "ar" -> "قيد التركيز"
                "sv" -> "I fokus"
                "hi" -> "फ़ोकस में"
                else -> "In Focus"
            }
            2 -> when (lang) {
                "he" -> "הושלם"
                "es" -> "Hecho"
                "de" -> "Erledigt"
                "fr" -> "Terminé"
                "ar" -> "مكتمل"
                "sv" -> "Klart"
                "hi" -> "पूर्ण"
                else -> "Done"
            }
            else -> when (lang) {
                "he" -> "לביצוע"
                "es" -> "Por Hacer"
                "de" -> "Zu Erledigen"
                "fr" -> "À Faire"
                "ar" -> "للقيام به"
                "sv" -> "Att göra"
                "hi" -> "करने के लिए"
                else -> "To Do"
            }
        }
    }

    fun getKanbanSubtitle(count: Int, locale: Locale): String {
        val lang = getNormalizedLanguage(locale)
        return when (lang) {
            "he" -> "לוח קנבן • $count משימות"
            "es" -> "Tablero Kanban • $count tareas"
            "de" -> "Kanban-Board • $count Aufgaben"
            "fr" -> "Tableau Kanban • $count tâches"
            "ar" -> "لوحة كانبان • $count مهام"
            "sv" -> "Kanban-tavla • $count uppgifter"
            "hi" -> "कैनबन बोर्ड • $count कार्य"
            else -> "Kanban Board • $count tasks"
        }
    }

    fun getKanbanTodoTitle(locale: Locale): String = getKanbanColumnTitle(0, locale)
    fun getKanbanFocusTitle(locale: Locale): String = getKanbanColumnTitle(1, locale)
    fun getKanbanDoneTitle(locale: Locale): String = getKanbanColumnTitle(2, locale)

    fun getNoTasksInColumnText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "אין משימות בעמודה זו"
            "es" -> "No hay tareas en esta columna"
            "de" -> "Keine Aufgaben in dieser Spalte"
            "fr" -> "Aucune tâche dans cette colonne"
            "ar" -> "لا توجد مهام في هذا العمود"
            "sv" -> "Inga uppgifter i denna kolumn"
            "hi" -> "इस कॉलम में कोई कार्य नहीं"
            else -> "No tasks in this column"
        }
    }

    fun getPendingLeftText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "נותרו"
            "es" -> "Restan"
            "de" -> "Übrig"
            "fr" -> "Restant"
            "ar" -> "متبقي"
            "sv" -> "Kvar"
            "hi" -> "शेष"
            else -> "Left"
        }
    }

    fun getNewTaskText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "משימה חדשה"
            "es" -> "Nueva Tarea"
            "de" -> "Neue Aufgabe"
            "fr" -> "Nouvelle tâche"
            "ar" -> "مهمة جديدة"
            "sv" -> "Ny uppgift"
            "hi" -> "नया कार्य"
            else -> "New Task"
        }
    }

    fun getCalendarText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "לוח שנה"
            "es" -> "Calendario"
            "de" -> "Kalender"
            "fr" -> "Calendrier"
            "ar" -> "التقويم"
            "sv" -> "Kalender"
            "hi" -> "कैलेंडर"
            else -> "Calendar"
        }
    }

    fun getAllCaughtUpText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "כל המשימות הושלמו"
            "es" -> "Todas las tareas completadas"
            "de" -> "Alle Aufgaben erledigt"
            "fr" -> "Toutes les tâches terminées"
            "ar" -> "اكتملت جميع المهام"
            "sv" -> "Alla uppgifter slutförda"
            "hi" -> "सभी कार्य पूरे हो गए"
            else -> "All tasks completed"
        }
    }

    fun getClearText(locale: Locale): String {
        return when (getNormalizedLanguage(locale)) {
            "he" -> "נקי"
            "es" -> "Limpio"
            "de" -> "Frei"
            "fr" -> "Libre"
            "ar" -> "منجز"
            "sv" -> "Klart"
            "hi" -> "साफ़"
            else -> "Clear"
        }
    }
}

