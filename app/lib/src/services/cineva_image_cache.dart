import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Dedicated image cache — bump [key] if the on-disk sqflite DB goes bad
/// (e.g. iOS simulator "attempt to write a readonly database").
class CinevaImageCache extends CacheManager with ImageCacheManager {
  CinevaImageCache._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 14),
            maxNrOfCacheObjects: 400,
          ),
        );

  static const key = 'cinevaImageCache_v2';
  static final instance = CinevaImageCache._();
}
