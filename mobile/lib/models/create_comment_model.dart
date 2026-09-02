import 'package:equatable/equatable.dart';

class CreateCommentModel extends Equatable {
  const CreateCommentModel({required this.content, this.replyToId});

  final String content;
  final String? replyToId;

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      if (replyToId != null) 'replyToId': replyToId,
    };
  }

  CreateCommentModel copyWith({String? newContent, String? newReplyToId}) {
    return CreateCommentModel(
      content: newContent ?? content,
      replyToId: newReplyToId ?? replyToId
    );
  }

  @override
  List<String?> get props => [content, replyToId];
}
