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
  String get theme => 'Tema';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get lightMode => 'Modo claro';

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
  String restoredTask(String title) {
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
  String get welcomeToPro => '¡Bienvenido a Pro!';

  @override
  String get pickAPlan => 'Elige un plan';

  @override
  String get byContinuingAgreement => 'Al continuar, aceptas nuestros';

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
  String get insights => 'Estadísticas';

  @override
  String get searchTasksHint => 'Buscar tareas...';

  @override
  String get emptyTrash => 'Vaciar papelera';

  @override
  String get productivityTrend => 'Tendencia de productividad';

  @override
  String get categoryBreakdown => 'Desglose por categoría';

  @override
  String get completed => 'Completadas';

  @override
  String get pending => 'Pendientes';

  @override
  String taskReminderTitle(String title) {
    return 'Recordatorio de tarea: $title';
  }

  @override
  String get taskDueNowBody => '¡Tienes una tarea que vence ahora!';

  @override
  String get createFirstTask => 'Crea tu primera tarea';

  @override
  String get filterToday => 'Hoy';

  @override
  String get filterThisWeek => 'Esta semana';

  @override
  String get filterOverdue => 'Atrasado';

  @override
  String get filterNoDate => 'Sin fecha';

  @override
  String get dateRange => 'Filtro de fecha';

  @override
  String get recurringTaskScheduled => 'Tarea recurrente programada';

  @override
  String nextOccurrenceSet(String title, String date) {
    return 'Siguiente ocurrencia de \"$title\" establecida para $date';
  }

  @override
  String get initializationFailedError =>
      'Error al inicializar los datos de la aplicación. Por favor, reinicie.';

  @override
  String get noTaskDataAvailable => 'No hay datos de tareas disponibles';

  @override
  String get retryInitialization => 'Reintentar inicialización';

  @override
  String get criticalErrorTitle => 'ERROR CRÍTICO';

  @override
  String get appStartupErrorBody =>
      'ROCI\'s Tasks encontró un problema durante el inicio. Nuestro equipo ha sido notificado.';

  @override
  String get appTagline => 'Cuidando cada detalle';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get allDay => 'Todo el día';

  @override
  String get event => 'Evento';

  @override
  String get markAsIncomplete => 'Marcar como incompleta';

  @override
  String get markAsComplete => 'Marcar como completa';

  @override
  String get editTaskDetailsHint =>
      'Toca dos veces para editar los detalles de la tarea';

  @override
  String get pinTask => 'Fijar tarea';

  @override
  String get unpinTask => 'Desfijar tarea';

  @override
  String get notificationSnooze => 'Posponer 15m';

  @override
  String get notificationMarkCompleted => 'Marcar como completado';

  @override
  String get notificationOpenTask => 'Abrir tarea';

  @override
  String notificationUncompletedTasks(int count) {
    return '$count tareas sin completar';
  }

  @override
  String get notificationTasksRemaining => 'Tareas restantes';

  @override
  String notificationTasksSummary(int count) {
    return '$count tareas';
  }

  @override
  String get skip => 'Omitir';

  @override
  String get productivity => 'Productividad';

  @override
  String get smartAdd => 'Añadido inteligente (NLP)';

  @override
  String get autoRemoveNlpDates => 'Limpiar título';

  @override
  String get autoRemoveNlpDatesSubtitle =>
      'Eliminar fecha/hora del título cuando se sugiera';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get dontHaveAccount => '¿No tienes una cuenta?';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta?';

  @override
  String get invalidEmail =>
      'Por favor, introduce un correo electrónico válido';

  @override
  String get passwordTooShort =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get passwordResetEmailSent =>
      'Correo de restablecimiento de contraseña enviado';

  @override
  String get showTaskCounterNotification => 'Mostrar contador de tareas';

  @override
  String get showTaskCounterNotificationSubtitle =>
      'Muestra una notificación persistente con tu recuento de tareas';

  @override
  String get appGuide => 'Guía de la aplicación';

  @override
  String get appGuideSubtitle => 'Aprende a usar ROCI\'s Tasks';

  @override
  String get appGuideTitle => 'Guía de la aplicación';

  @override
  String get features => 'Características';

  @override
  String get howToUse => 'Cómo usar';

  @override
  String get guideTaskDesc =>
      'Crea, edita y organiza tus tareas diarias con facilidad.';

  @override
  String get guideCalendarDesc =>
      'Visualiza tus tareas y eventos en una hermosa vista de calendario.';

  @override
  String get guideCategoriesDesc =>
      'Organiza tareas en categorías personalizadas con iconos y colores únicos.';

  @override
  String get guideNotificationsTitle => 'Notificaciones';

  @override
  String get guideNotificationsDesc =>
      'Mantente al tanto de tu horario con recordatorios inteligentes y un contador de tareas persistente.';

  @override
  String get guideCloudSyncTitle => 'Sincronización en la nube';

  @override
  String get guideCloudSyncDesc =>
      'Accede a tus tareas desde cualquier dispositivo con sincronización segura en la nube.';

  @override
  String get guideAddingTasksTitle => 'Añadir tareas';

  @override
  String get guideAddingTasksDesc =>
      'Toca el botón + para añadir una nueva tarea. Usa lenguaje natural (p. ej., \"Almuerzo mañana a la 1 pm\") para una entrada rápida.';

  @override
  String get guideGesturesTitle => 'Gestos';

  @override
  String get guideGesturesDesc =>
      'Desliza a la derecha para completar una tarea, desliza a la izquierda para eliminarla. Mantén presionado para más opciones.';

  @override
  String get guideWidgetsTitle => 'Widgets de inicio';

  @override
  String get guideWidgetsDesc =>
      'Añade widgets de ROCI\'s Tasks a tu pantalla de inicio para un acceso rápido y actualizaciones de estado.';

  @override
  String get guideCustomizationTitle => 'Personalización';

  @override
  String get guideCustomizationDesc =>
      'Personalizar tu experiencia en Ajustes con temas, opciones de idioma y más.';

  @override
  String get guideHappyOrganizing => '¡Feliz organización!';

  @override
  String get notificationRefreshed =>
      'Notificación del contador de tareas actualizada';
}
