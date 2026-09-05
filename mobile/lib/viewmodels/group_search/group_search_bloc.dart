import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/group_model.dart';
import 'package:social_app/repositories/search_repository.dart';

part 'group_search_event.dart';
part 'group_search_state.dart';

class GroupSearchBloc extends Bloc<GroupSearchEvent, GroupSearchState> {
  GroupSearchBloc() : super(GroupSearchInitialState()) {
    on<GroupSearchQueryChanged>(_onQueryChanged, transformer: restartable());
  }

  final SearchRepository _repo = SearchRepository();

  Future<void> _onQueryChanged(GroupSearchQueryChanged event, Emitter<GroupSearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(GroupSearchInitialState());
      return;
    }
    emit(GroupSearchLoadingState());
    try {
      final groups = await _repo.searchGroups(query);
      emit(GroupSearchLoadedState(groups: groups));
    } catch (e) {
      final message = e is AppException ? e.message : 'Search failed';
      emit(GroupSearchErrorState(message: message));
    }
  }
}
