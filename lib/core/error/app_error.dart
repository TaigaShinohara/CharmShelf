enum ErrorSeverity { critical, warning, info }

enum ErrorCategory {
  network,
  database,
  auth,
  validation,
  file,
  permission,
  system,
  ui,
  unknown,
}

class AppError {
  final String message;
  final ErrorCategory category;
  final ErrorSeverity severity;
  final Object? originalError;
  final StackTrace? stackTrace;
  final String? context;
  final Map<String, dynamic>? additionalData;

  const AppError({
    required this.message,
    required this.category,
    required this.severity,
    this.originalError,
    this.stackTrace,
    this.context,
    this.additionalData,
  });

  factory AppError.network(
    String message, {
    ErrorSeverity severity = ErrorSeverity.warning,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.network,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.database(
    String message, {
    ErrorSeverity severity = ErrorSeverity.warning,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.database,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.file(
    String message, {
    ErrorSeverity severity = ErrorSeverity.warning,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.file,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.permission(
    String message, {
    ErrorSeverity severity = ErrorSeverity.warning,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.permission,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.system(
    String message, {
    ErrorSeverity severity = ErrorSeverity.critical,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.system,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.ui(
    String message, {
    ErrorSeverity severity = ErrorSeverity.info,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.ui,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.auth(
    String message, {
    ErrorSeverity severity = ErrorSeverity.warning,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.auth,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  factory AppError.validation(String message, {String? context}) {
    return AppError(
      message: message,
      category: ErrorCategory.validation,
      severity: ErrorSeverity.info,
      context: context,
    );
  }

  factory AppError.unknown(
    String message, {
    ErrorSeverity severity = ErrorSeverity.critical,
    Object? original,
    StackTrace? stackTrace,
    String? context,
  }) {
    return AppError(
      message: message,
      category: ErrorCategory.unknown,
      severity: severity,
      originalError: original,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// コンテキスト情報を追加した新しいAppErrorを返す
  AppError withContext(String context) {
    return AppError(
      message: message,
      category: category,
      severity: severity,
      originalError: originalError,
      stackTrace: stackTrace,
      context: context,
      additionalData: additionalData,
    );
  }

  /// 追加データを付与した新しいAppErrorを返す
  AppError withAdditionalData(Map<String, dynamic> data) {
    return AppError(
      message: message,
      category: category,
      severity: severity,
      originalError: originalError,
      stackTrace: stackTrace,
      context: context,
      additionalData: {...?additionalData, ...data},
    );
  }

  @override
  String toString() {
    return 'AppError: $message';
  }
}
