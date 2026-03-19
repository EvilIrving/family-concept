import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrNull => switch (this) {
    AsyncData(:final value) => value,
    _ => null,
  };
}

extension IterableX<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
