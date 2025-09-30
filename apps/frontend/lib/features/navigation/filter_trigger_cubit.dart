import 'package:flutter_bloc/flutter_bloc.dart';

class FilterTriggerCubit extends Cubit<int> {
  FilterTriggerCubit() : super(0);

  void triggerFilter() => emit(state + 1);
}