class SingleKeyFutureCache<K, V> {
  K? _key;
  Future<V>? _future;

  Future<V> get(K key, Future<V> Function() loader) {
    if (_future == null || _key != key) {
      _key = key;
      _future = loader();
    }
    return _future!;
  }

  void clear() {
    _key = null;
    _future = null;
  }
}
