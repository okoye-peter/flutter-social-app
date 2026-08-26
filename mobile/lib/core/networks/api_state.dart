sealed class ApiState<T> {
  const ApiState();
}

class ApiLoading<T> extends ApiState<T> {
  const ApiLoading();
}

class ApiSuccess<T> extends ApiState<T> {
  const ApiSuccess(this.data);
  final T data;
}

class ApiError<T> extends ApiState<T> {
  const ApiError(this.message);
  final String message;
}
