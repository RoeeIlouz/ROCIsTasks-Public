import json
import os

translations = {
    "en": {
        "repeatWeekdays": "Weekdays (Mon–Fri)",
        "repeatYearly": "Yearly",
        "repeatCustom": "Custom...",
        "repeatsEvery": "Repeats every",
        "recurringTasks": "Recurring Tasks",
        "recurringTasksDesc": "Automate repeating tasks with daily, weekly, monthly, or custom schedules.",
        "customRecurrence": "Custom Recurrence",
        "daySingular": "day",
        "daysPlural": "days",
        "weekSingular": "week",
        "weeksPlural": "weeks",
        "monthSingular": "month",
        "monthsPlural": "months",
        "yearSingular": "year",
        "yearsPlural": "years",
        "selectRecurrence": "Select Recurrence"
    },
    "he": {
        "repeatWeekdays": "ימי חול (א'–ה')",
        "repeatYearly": "שנתי",
        "repeatCustom": "מותאם אישית...",
        "repeatsEvery": "חוזר כל",
        "recurringTasks": "משימות חוזרות",
        "recurringTasksDesc": "הפוך משימות לאוטומטיות בלוח זמנים יומי, שבועי, חודשי או מותאם אישית.",
        "customRecurrence": "חזרה מותאמת אישית",
        "daySingular": "יום",
        "daysPlural": "ימים",
        "weekSingular": "שבוע",
        "weeksPlural": "שבועות",
        "monthSingular": "חודש",
        "monthsPlural": "חודשים",
        "yearSingular": "שנה",
        "yearsPlural": "שנים",
        "selectRecurrence": "בחר חזרה"
    },
    "es": {
        "repeatWeekdays": "Días laborables (lun–vie)",
        "repeatYearly": "Anualmente",
        "repeatCustom": "Personalizado...",
        "repeatsEvery": "Se repite cada",
        "recurringTasks": "Tareas recurrentes",
        "recurringTasksDesc": "Automatiza tareas repetitivas con programaciones diarias, semanales, mensuales o personalizadas.",
        "customRecurrence": "Recurrencia personalizada",
        "daySingular": "día",
        "daysPlural": "días",
        "weekSingular": "semana",
        "weeksPlural": "semanas",
        "monthSingular": "mes",
        "monthsPlural": "meses",
        "yearSingular": "año",
        "yearsPlural": "años",
        "selectRecurrence": "Seleccionar recurrencia"
    },
    "fr": {
        "repeatWeekdays": "Jours de semaine (lun–ven)",
        "repeatYearly": "Annuel",
        "repeatCustom": "Personnalisé...",
        "repeatsEvery": "Se répète tous les",
        "recurringTasks": "Tâches récurrentes",
        "recurringTasksDesc": "Automatisez les tâches répétitives avec des fréquences quotidiennes, hebdomadaires, mensuelles ou personnalisées.",
        "customRecurrence": "Récurrence personnalisée",
        "daySingular": "jour",
        "daysPlural": "jours",
        "weekSingular": "semaine",
        "weeksPlural": "semaines",
        "monthSingular": "mois",
        "monthsPlural": "mois",
        "yearSingular": "an",
        "yearsPlural": "ans",
        "selectRecurrence": "Sélectionner la récurrence"
    },
    "de": {
        "repeatWeekdays": "Wochentage (Mo–Fr)",
        "repeatYearly": "Jährlich",
        "repeatCustom": "Benutzerdefiniert...",
        "repeatsEvery": "Wiederholt sich alle",
        "recurringTasks": "Wiederkehrende Aufgaben",
        "recurringTasksDesc": "Automatisiere wiederkehrende Aufgaben mit täglichen, wöchentlichen, monatlichen oder benutzerdefinierten Intervallen.",
        "customRecurrence": "Benutzerdefinierte Wiederholung",
        "daySingular": "Tag",
        "daysPlural": "Tage",
        "weekSingular": "Woche",
        "weeksPlural": "Wochen",
        "monthSingular": "Monat",
        "monthsPlural": "Monate",
        "yearSingular": "Jahr",
        "yearsPlural": "Jahre",
        "selectRecurrence": "Wiederholung auswählen"
    },
    "ar": {
        "repeatWeekdays": "أيام الأسبوع (الإثنين–الجمعة)",
        "repeatYearly": "سنويًا",
        "repeatCustom": "مخصص...",
        "repeatsEvery": "يتكرر كل",
        "recurringTasks": "المهام المتكررة",
        "recurringTasksDesc": "أتمتة المهام المتكررة بجداول يومية أو أسبوعية أو شهرية أو مخصصة.",
        "customRecurrence": "تكرار مخصص",
        "daySingular": "يوم",
        "daysPlural": "أيام",
        "weekSingular": "أسبوع",
        "weeksPlural": "أسابيع",
        "monthSingular": "شهر",
        "monthsPlural": "أشهر",
        "yearSingular": "سنة",
        "yearsPlural": "سنوات",
        "selectRecurrence": "تحديد التكرار"
    },
    "sv": {
        "repeatWeekdays": "Vardagar (mån–fre)",
        "repeatYearly": "Årligen",
        "repeatCustom": "Anpassad...",
        "repeatsEvery": "Upprepas var",
        "recurringTasks": "Återkommande uppgifter",
        "recurringTasksDesc": "Automatisera återkommande uppgifter med dagliga, veckovisa, månatliga eller anpassade scheman.",
        "customRecurrence": "Anpassad upprepning",
        "daySingular": "dag",
        "daysPlural": "dagar",
        "weekSingular": "vecka",
        "weeksPlural": "veckor",
        "monthSingular": "månad",
        "monthsPlural": "månader",
        "yearSingular": "år",
        "yearsPlural": "år",
        "selectRecurrence": "Välj upprepning"
    },
    "hi": {
        "repeatWeekdays": "कार्यदिवस (सोम–शुक्र)",
        "repeatYearly": "वार्षिक",
        "repeatCustom": "कस्टम...",
        "repeatsEvery": "हर दोहराता है",
        "recurringTasks": "आवर्ती कार्य",
        "recurringTasksDesc": "दैनिक, साप्ताहिक, मासिक या कस्टम शेड्यूल के साथ कार्यों को स्वचालित करें।",
        "customRecurrence": "कस्टम पुनरावृत्ति",
        "daySingular": "दिन",
        "daysPlural": "दिन",
        "weekSingular": "सप्ताह",
        "weeksPlural": "सप्ताह",
        "monthSingular": "महीना",
        "monthsPlural": "महीने",
        "yearSingular": "वर्ष",
        "yearsPlural": "वर्ष",
        "selectRecurrence": "पुनरावृत्ति चुनें"
    }
}

l10n_dir = r"c:\Users\roeei\Documents\rocis_apps\ROCIs-tasks\lib\l10n"

for lang, new_entries in translations.items():
    file_path = os.path.join(l10n_dir, f"app_{lang}.arb")
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue
    
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    for k, v in new_entries.items():
        data[k] = v
        
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Updated {file_path}")

print("All ARB files updated successfully.")
