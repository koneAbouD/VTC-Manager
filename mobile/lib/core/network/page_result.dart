/// Résultat paginé générique renvoyé par l'API (enveloppe `PageResponse`
/// côté backend). Sert de base au scroll infini sur toutes les listes.
class PageResult<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const PageResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  bool get hasMore => !last;

  /// Parse une enveloppe `{ content: [...], page, size, totalElements,
  /// totalPages, last }`. [itemFromJson] convertit chaque élément.
  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawContent = (json['content'] as List?) ?? const [];
    final content = rawContent
        .map((e) => itemFromJson(e as Map<String, dynamic>))
        .toList();
    return PageResult<T>(
      content: content,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? content.length,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? content.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      last: json['last'] as bool? ?? true,
    );
  }
}
