class ApiResponse<T> {
  final T? data;
  final String? message;

  const ApiResponse({this.data, this.message});
}
