sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get dataOrNull => switch (this) {
    Success<T, E>(data: final data) => data,
    Failure<T, E>() => null,
  };

  E? get errorOrNull => switch (this) {
    Success<T, E>() => null,
    Failure<T, E>(error: final error) => error,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) {
    return switch (this) {
      Success<T, E>(data: final data) => success(data),
      Failure<T, E>(error: final error) => failure(error),
    };
  }

  factory Result.success(T data) = Success<T, E>;
  factory Result.failure(E error) = Failure<T, E>;
}

final class Success<T, E> extends Result<T, E> {
  final T data;
  const Success(this.data);
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}
