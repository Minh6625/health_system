class PaginationModel<T> {
  final List<T> items;
  final int page;
  final int total;

  const PaginationModel({
    required this.items,
    required this.page,
    required this.total,
  });
}
