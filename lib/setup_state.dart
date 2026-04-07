import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pass_service.dart';

class SetupStateNotifier extends StateNotifier<SetupStatus> {
  final PassService _svc = PassService();

  SetupStateNotifier() : super(SetupStatus.checking);

  Future<void> check() async {
    state = SetupStatus.checking;
    state = await _svc.checkSetup();
  }
}

final setupProvider =
    StateNotifierProvider<SetupStateNotifier, SetupStatus>((ref) {
  final notifier = SetupStateNotifier();
  notifier.check();
  return notifier;
});
