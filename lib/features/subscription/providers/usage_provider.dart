import 'package:flutter_riverpod/flutter_riverpod.dart';

class UsageState {
  final int queries;
  final int documents;

  UsageState({
    this.queries = 0,
    this.documents = 0,
  });

  UsageState copyWith({
    int? queries,
    int? documents,
  }) {
    return UsageState(
      queries: queries ?? this.queries,
      documents: documents ?? this.documents,
    );
  }
}

class UsageNotifier extends Notifier<UsageState> {
  @override
  UsageState build() {
    return UsageState();
  }

  void incrementQueries() {
    state = state.copyWith(queries: state.queries + 1);
  }

  void incrementDocuments() {
    state = state.copyWith(documents: state.documents + 1);
  }

  void reset() {
    state = UsageState();
  }
}

final usageProvider =
    NotifierProvider<UsageNotifier, UsageState>(
  () => UsageNotifier(),
);
