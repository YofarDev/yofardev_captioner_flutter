class Cubit<S> {
  S get state => throw StateError('stub');
}

class CounterCubit extends Cubit<int> {}

class SomeService {
  SomeService(this.cubit);

  final CounterCubit cubit;
}
