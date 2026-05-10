// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Tareas de ROCI';

  @override
  String get settings => 'Configuración';

  @override
  String get account => 'Cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get appearance => 'Apariencia';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get materialTheme => 'Tema Material';

  @override
  String get useSystemColors => 'Usar colores del sistema';

  @override
  String get amoledDarkMode => 'Modo oscuro AMOLED';

  @override
  String get pureBlackBackground => 'Fondo negro puro';

  @override
  String get dataAndSync => 'Datos y sincronización';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get syncingTasks => 'Sincronizando tareas...';

  @override
  String get trash => 'Papelera';

  @override
  String get sortAndFilter => 'Ordenar y filtrar';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get date => 'Fecha';

  @override
  String get priority => 'Prioridad';

  @override
  String get title => 'Título';

  @override
  String get createdDate => 'Fecha de creación';

  @override
  String get filterByCategory => 'Filtrar por categoría';

  @override
  String get all => 'Todos';

  @override
  String get showCompletedTasks => 'Mostrar tareas completadas';

  @override
  String get done => 'Listo';

  @override
  String get timeFormat24h => 'Formato de 24 horas';

  @override
  String get language => 'Idioma';

  @override
  String get hebrew => 'Hebreo';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get tasks => 'Tareas';

  @override
  String get editTask => 'Editar tarea';

  @override
  String get newTask => 'Nueva tarea';

  @override
  String get description => 'Descripción';

  @override
  String get dueDateAndTime => 'Fecha y hora de vencimiento';

  @override
  String get noDateSelected => 'Sin fecha seleccionada';

  @override
  String get category => 'Categoría';

  @override
  String get noCategory => 'Sin categoría';

  @override
  String get saveTask => 'Guardar tarea';

  @override
  String get updateTask => 'Actualizar tarea';

  @override
  String get pleaseEnterATitle => 'Por favor, introduce un título';

  @override
  String get high => 'Alta';

  @override
  String get medium => 'Media';

  @override
  String get low => 'Baja';

  @override
  String get priorityLabel => 'Prioridad';

  @override
  String get myTasks => 'Mis tareas';

  @override
  String get calendar => 'Calendario';

  @override
  String get categories => 'Categorías';

  @override
  String get noCategoriesYet => 'Sin categorías aún';

  @override
  String get addCategory => 'Añadir categoría';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get editCategory => 'Editar categoría';

  @override
  String get name => 'Nombre';

  @override
  String get color => 'Color';

  @override
  String get icon => 'Icono';

  @override
  String get cancel => 'Cancelar';

  @override
  String get add => 'Añadir';

  @override
  String get save => 'Guardar';

  @override
  String get trashTitle => 'Papelera';

  @override
  String get trashEmpty => 'La papelera está vacía';

  @override
  String restoredTask(Object title) {
    return 'Tarea \"$title\" restaurada';
  }

  @override
  String get deletePermanently => '¿Eliminar permanentemente?';

  @override
  String get actionUndone => 'Esta acción no se puede deshacer.';

  @override
  String get delete => 'Eliminar';

  @override
  String get noTasksYet => 'Sin tareas aún';

  @override
  String get duePrefix => 'Vence: ';

  @override
  String get deleteTaskTitle => 'Eliminar tarea';

  @override
  String get deleteTaskConfirmation =>
      '¿Estás seguro de que deseas eliminar esta tarea?';

  @override
  String get calendarColors => 'Colores del calendario';

  @override
  String get calendarFiltersTitle => 'Filtros del calendario';

  @override
  String get showCalendarTasks => 'Mostrar tareas';

  @override
  String get showGoogleCalendar => 'Mostrar Google Calendar';

  @override
  String get showRocisSchedule => 'Mostrar horario de ROCIs';

  @override
  String get taskColor => 'Color de tarea';

  @override
  String get googleCalendarColor => 'Color de Google Calendar';

  @override
  String get scheduleColor => 'Color de horario ROCIs';

  @override
  String get assignmentColor => 'Color de asignación';

  @override
  String get resetColors => 'Restablecer valores';

  @override
  String get selectColor => 'Seleccionar color';

  @override
  String get selectGoogleCalendars => 'Seleccionar calendarios de Google';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Deseleccionar todo';

  @override
  String get offlineMode => 'Modo sin conexión';

  @override
  String get syncComplete => 'Sincronización completa';

  @override
  String get backupAndRestore => 'Copia de seguridad y restauración';

  @override
  String get exportData => 'Exportar datos (JSON)';

  @override
  String get exportDataSubtitle =>
      'Haz una copia de seguridad de tus tareas y categorías';

  @override
  String get backupCopied => '¡Copia de seguridad copiada al portapapeles!';

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get importData => 'Importar datos (JSON)';

  @override
  String get importDataSubtitle => 'Restaurar desde una copia JSON';

  @override
  String get importBackup => 'Importar copia de seguridad';

  @override
  String get pasteJsonHint => 'Pega aquí la copia JSON...';

  @override
  String get import => 'Importar';

  @override
  String get importComplete => '¡Importación completada!';

  @override
  String importFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get privacyAndGdpr => 'Privacidad y GDPR';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get privacyPolicySubtitle =>
      'Lee nuestros términos de seguridad de datos';

  @override
  String get deleteAccountTitle => 'Eliminar mi cuenta y datos';

  @override
  String get deleteAccountSubtitle =>
      'Eliminar permanentemente todos tus datos';

  @override
  String get deleteAccountConfirmTitle => '¿Eliminar cuenta?';

  @override
  String get deleteAccountConfirmBody =>
      'Esta acción es permanente y eliminará todas tus tareas, categorías y configuración de nuestros servidores.';

  @override
  String get deleteEverything => 'Eliminar todo';

  @override
  String get deletionFailed =>
      'La eliminación falló. Es posible que debas cerrar sesión y volver a iniciarla por seguridad.';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutApp => 'Acerca de ROCI\'s Tasks';

  @override
  String get aboutAppSubtitle => 'Versión de la app, soporte e información';

  @override
  String get aboutAppDescription =>
      'ROCI\'s Tasks está diseñado para ayudarte a mantenerte organizado y productivo. Construido con Flutter, ofrece una experiencia fluida para gestionar tus tareas, categorías y agenda diaria.';

  @override
  String get visitWebsite => 'Visitar nuestro sitio web';

  @override
  String get contactSupport => 'Contactar soporte';

  @override
  String get rocisTasksPro => 'ROCIs Tasks Pro';

  @override
  String get youAreProUser => '¡Eres usuario Pro!';

  @override
  String get unlockPremiumFeatures => 'Desbloquea funciones premium';

  @override
  String get manageSubscription => 'Gestionar suscripción';

  @override
  String get manageSubscriptionSubtitle => 'Cancela o cambia tu plan';

  @override
  String get upgradeToPro => 'Actualizar a Pro';

  @override
  String get unlockFullPotential => 'Desbloquea todo tu potencial';

  @override
  String get unlimitedCategories => 'Categorías ilimitadas';

  @override
  String get unlimitedCategoriesDesc =>
      'Crea tantas categorías como necesites para mantenerte organizado.';

  @override
  String get premiumWidgets => 'Widgets premium';

  @override
  String get premiumWidgetsDesc =>
      'Acceso a widgets de pantalla de inicio de mes y calendario completo.';

  @override
  String get subtasksAndChecklists => 'Subtareas y listas de verificación';

  @override
  String get subtasksAndChecklistsDesc =>
      'Divide las tareas complejas en pasos más pequeños y manejables.';

  @override
  String get recurringTasks => 'Tareas recurrentes';

  @override
  String get recurringTasksDesc =>
      'Automatiza tu rutina con reglas de repetición flexibles.';

  @override
  String get viewPricingPlans => 'Ver planes de precios';

  @override
  String get proSubscriptionActive => 'Suscripción Pro activa';

  @override
  String get purchasesRestored => '¡Compras restauradas correctamente!';

  @override
  String get noActiveSubscription =>
      'No se encontró suscripción activa para esta cuenta.';

  @override
  String get failedToRestore => 'No se pudieron restaurar las compras.';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get subtasks => 'Subtareas';

  @override
  String get noSubtasksAdded => 'No se añadieron subtareas';

  @override
  String get enterSubtask => 'Introducir subtarea...';

  @override
  String get recurrence => 'Recurrencia';

  @override
  String get repeat => 'Repetir';

  @override
  String get repeatNone => 'Ninguna';

  @override
  String get repeatDaily => 'Diariamente';

  @override
  String get repeatWeekly => 'Semanalmente';

  @override
  String get repeatMonthly => 'Mensualmente';

  @override
  String get titleInvalidContent => 'El título contiene contenido no válido';

  @override
  String get descriptionInvalidContent =>
      'La descripción contiene contenido no válido';

  @override
  String get failedToSaveTask =>
      'No se pudo guardar la tarea. Por favor, inténtalo de nuevo.';

  @override
  String get welcomeToApp => 'Bienvenido a ROCI\'s Tasks';

  @override
  String get signInToSync =>
      'Inicia sesión para sincronizar tus tareas entre dispositivos';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signInFailed => 'Error al iniciar sesión';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a ROCI\'s Tasks';

  @override
  String get onboardingWelcomeDesc =>
      'Organiza tu vida con eficiencia y estilo.';

  @override
  String get onboardingSyncTitle => 'Sincronización y modo sin conexión';

  @override
  String get onboardingSyncDesc =>
      'Tus tareas te siguen a todas partes. Accede a ellas incluso sin conexión a internet.';

  @override
  String get onboardingGesturesTitle => 'Gestos inteligentes';

  @override
  String get onboardingGesturesDesc =>
      'Desliza a la izquierda para eliminar, a la derecha para completar. Mantén presionado para más opciones.';

  @override
  String get getStarted => 'Empezar';

  @override
  String get next => 'Siguiente';

  @override
  String get searchTasksHint => 'Buscar tareas...';

  @override
  String get emptyTrash => 'Vaciar papelera';
}
