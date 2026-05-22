import re

path = r'c:\Users\roeei\Documents\rocis_apps\ROCIs-tasks\lib\features\tasks\presentation\providers\task_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports if missing
if "import 'dart:ui';" not in content:
    content = content.replace("import 'package:flutter/foundation.dart' hide Category;", "import 'package:flutter/foundation.dart' hide Category;\nimport 'dart:ui';\nimport 'package:rocis_tasks/l10n/app_localizations.dart';")

# Add _l10n getter if missing
if "AppLocalizations get _l10n" not in content:
    class_match = re.search(r'class TaskProvider extends ChangeNotifier \{', content)
    if class_match:
        content = content[:class_match.end()] + '\n  AppLocalizations get _l10n {\n    return lookupAppLocalizations(PlatformDispatcher.instance.locale);\n  }\n' + content[class_match.end():]

# Replace title and body
content = re.sub(r"title:\s*'Task Reminder:\s*\$\{([^}]+)\}',", r"title: _l10n.taskReminderTitle(\1),", content)
content = re.sub(r"'You have a task due now!'", r"_l10n.taskDueNowBody", content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
