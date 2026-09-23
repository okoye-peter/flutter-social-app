import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/models/comment_model.dart';
import 'package:social_app/models/create_comment_model.dart';
import 'package:social_app/viewmodels/comments/comment_bloc.dart';
import 'package:social_app/views/feeds/widgets/comment_composer.dart';
import 'package:social_app/views/feeds/widgets/comment_list_body.dart';
import 'package:social_app/views/feeds/widgets/comment_sheet_handle.dart';

/// Instagram-style draggable comments sheet for a post: a resizable,
/// scrollable comment list backed by [CommentBloc], with reply threads,
/// like toggling, and a bottom composer.
class CommentBottomSheet extends StatefulWidget {
  const CommentBottomSheet({
    super.key,
    required this.postId,
    this.onCommentPosted,
  });

  final String postId;

  /// Called once per successfully created comment or reply — lets the
  /// caller (e.g. [ReelsTile]) bump its own visible comment count without
  /// reaching into this sheet's bloc.
  final VoidCallback? onCommentPosted;

  /// Presents the sheet over [context], scoped to its own [CommentBloc]
  /// that loads the first page of comments for [postId].
  static Future<void> show(
    BuildContext context, {
    required String postId,
    VoidCallback? onCommentPosted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => CommentBloc()..add(LoadCommentEvent(postId: postId)),
        child: CommentBottomSheet(
          postId: postId,
          onCommentPosted: onCommentPosted,
        ),
      ),
    );
  }

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final Set<String> _expandedReplyIds = {};

  CommentModel? _replyTo;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification, CommentState state) {
    if (state is! CommentLoadedState) return false;
    if (state.isLoadingMore || !state.hasMorePage) return false;
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 200) {
      context.read<CommentBloc>().add(
        LoadMoreCommentsEvent(postId: widget.postId, cursor: state.nextCursor!),
      );
    }
    return false;
  }

  void _startReply(CommentModel comment) {
    setState(() => _replyTo = comment);
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  void _toggleReplies(CommentModel comment) {
    setState(() {
      if (!_expandedReplyIds.add(comment.id)) {
        _expandedReplyIds.remove(comment.id);
        return;
      }
    });
    context.read<CommentBloc>().add(LoadRepliesEvent(parentId: comment.id));
  }

  Future<void> _submit() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    final replyToId = _replyTo?.id;
    _inputController.clear();
    setState(() => _replyTo = null);

    final bloc = context.read<CommentBloc>();
    final success = await bloc.createComment(
      widget.postId,
      CreateCommentModel(content: content, replyToId: replyToId),
    );
    if (success) widget.onCommentPosted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: BlocConsumer<CommentBloc, CommentState>(
              listenWhen: (previous, current) =>
                  current is CommentLoadedState &&
                  current.submitError != null &&
                  current.submitError !=
                      (previous is CommentLoadedState ? previous.submitError : null),
              listener: (context, state) {
                final message = (state as CommentLoadedState).submitError!;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
              },
              builder: (context, state) {
                return Column(
                  children: [
                    const CommentSheetHandle(),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Comments',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: CommentListBody(
                        state: state,
                        scrollController: scrollController,
                        postId: widget.postId,
                        expandedReplyIds: _expandedReplyIds,
                        onScrollNotification: _onScrollNotification,
                        onToggleLike: (comment) => context
                            .read<CommentBloc>()
                            .add(ToggleCommentLikeStatusEvent(comment: comment)),
                        onReply: _startReply,
                        onToggleReplies: _toggleReplies,
                        onLoadMoreReplies: (comment, cursor) => context
                            .read<CommentBloc>()
                            .add(LoadRepliesEvent(parentId: comment.id, cursor: cursor)),
                      ),
                    ),
                    CommentComposer(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      replyTo: _replyTo,
                      onCancelReply: _cancelReply,
                      onSubmit: _submit,
                      isSubmitting: state is CommentLoadedState && state.isSubmitting,
                      bottomInset: bottomInset,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
