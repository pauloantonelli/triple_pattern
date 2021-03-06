import 'dart:async';

import 'package:async/async.dart';
import 'package:dartz/dartz.dart';

import 'models/triple_model.dart';
import 'package:meta/meta.dart';

typedef Disposer = Future<void> Function();

abstract class Store<Error extends Object, State extends Object> {
  late Triple<Error, State> _triple;
  late Triple<Error, State> lastTripleState;

  CancelableOperation? _completerExecution;
  var _lastExecution = DateTime.now();

  ///Get the complete triple value;
  Triple<Error, State> get triple => _triple;

  ///Get the [state] value;
  State get state => _triple.state;

  ///Get [loading] value;
  bool get isLoading => _triple.isLoading;

  ///Get [error] value;
  Error? get error => _triple.error;

  ///[initialState] Start this store with a value defalt.
  Store(State initialState) {
    _triple = Triple<Error, State>(state: initialState);
    lastTripleState = _triple;
  }

  ///IMPORTANT!!!
  ///THIS METHOD TO BE VISIBLE FOR OVERRIDING ONLY!!!
  @visibleForOverriding
  void propagate(Triple<Error, State> triple) {
    _triple = triple;
  }

  ///Change the State value.
  ///
  ///This also stores the state value to be retrieved using the [undo()] method when using MementoMixin
  void update(State newState) {
    final candidate = _triple.copyWith(state: newState, event: TripleEvent.state);
    if (candidate != _triple && candidate.state != _triple.state) {
      _triple = candidate;
      propagate(_triple);
    }
  }

  ///Change the loading value.
  void setLoading(bool newloading) {
    final candidate = _triple.copyWith(isLoading: newloading, event: TripleEvent.loading);
    if (candidate != _triple && candidate.isLoading != _triple.isLoading) {
      _triple = candidate;
      propagate(_triple);
    }
  }

  ///Change the error value.
  void setError(Error newError) {
    final candidate = _triple.copyWith(error: newError, event: TripleEvent.error);
    if (candidate != _triple && candidate.error != _triple.error) {
      _triple = candidate;
      propagate(_triple);
    }
  }

  ///Execute a Future.
  ///
  ///This function is a sugar code used to run a Future in a simple way,
  ///executing [setLoading] and adding to [setError] if an error occurs in Future
  Future<void> execute(Future<State> Function() func, {Duration delay = const Duration(milliseconds: 50)}) async {
    final localTime = DateTime.now();
    _lastExecution = localTime;
    await Future.delayed(delay);
    if (localTime != _lastExecution) {
      return;
    }

    setLoading(true);

    await _completerExecution?.cancel();

    _completerExecution = CancelableOperation.fromFuture(func());

    await _completerExecution!.then(
      (value) {
        if (value is State) {
          update(value);
          setLoading(false);
        }
      },
      onError: (error, __) {
        if (error is Error) {
          setError(error);
          setLoading(false);
        } else {
          //    throw 'is expected a ${Error.toString()} type, and receipt ${error.runtimeType}';
        }
      },
    ).valueOrCancellation();
  }

  ///Execute a Future Either [dartz].
  ///
  ///This function is a sugar code used to run a Future in a simple way,
  ///executing [setLoading] and adding to [setError] if an error occurs in Either
  Future<void> executeEither(Future<Either<Error, State>> Function() func, {Duration delay = const Duration(milliseconds: 50)}) async {
    final localTime = DateTime.now();
    _lastExecution = localTime;
    await Future.delayed(delay);
    if (localTime != _lastExecution) {
      return;
    }

    setLoading(true);

    await _completerExecution?.cancel();

    _completerExecution = CancelableOperation.fromFuture(func());

    await _completerExecution!.then(
      (value) {
        if (value is Either<Error, State>) {
          value.fold(setError, update);
          setLoading(false);
        }
      },
    ).valueOrCancellation();
  }

  ///Discard the store
  Future destroy();

  ///Observer the Segmented State.
  ///
  ///EXAMPLE:
  ///```dart
  ///Disposer disposer = counter.observer(
  ///   onState: (state) => print(state),
  ///   onLoading: (loading) => print(loading),
  ///   onError: (error) => print(error),
  ///);
  ///
  ///dispose();
  ///```
  Disposer observer({
    void Function(State state)? onState,
    void Function(bool isLoading)? onLoading,
    void Function(Error error)? onError,
  });
}
