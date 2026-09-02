import 'package:equatable/equatable.dart';

class PaginateDataModel<T> extends Equatable {
  const PaginateDataModel({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMorePage => nextCursor != null;

  factory PaginateDataModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginateDataModel(
      items: (json['items'] as List)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor];
}
