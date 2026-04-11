import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatProvider = NotifierProvider.autoDispose.family<ChatNotifier, List<int>, String>(
  (arg) => ChatNotifier(arg),
);

class ChatNotifier extends Notifier<List<int>> {
  final String arg;
  ChatNotifier(this.arg);

  @override
  List<int> build() => [];
}
