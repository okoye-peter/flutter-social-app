import 'package:equatable/equatable.dart';
import 'package:social_app/models/feed_item_model.dart';

class PostsPage extends Equatable {
  const PostsPage({required this.items, required this.nextCursor});

  final List<FeedItemModel> items;
  final String? nextCursor;

  bool get hasMorePage => nextCursor != null;

  factory PostsPage.fromJson(Map<String, dynamic> json) {
    return PostsPage(
      items: (json['items'] as List)
          .map((item) => FeedItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor];
}
