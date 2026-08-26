import 'package:equatable/equatable.dart';
import 'package:social_app/models/post_model.dart';

class PostsPage extends Equatable {
  const PostsPage({required this.posts, required this.nextCursor});

  final List<PostModel> posts;
  final String? nextCursor;

  bool get hasMorePage => nextCursor != null;

  factory PostsPage.fromJson(Map<String, dynamic> json) {
    return PostsPage(
      posts: (json['items'] as List)
          .map((post) => PostModel.fromJson(post as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  List<Object?> get props => [posts, nextCursor];
}
