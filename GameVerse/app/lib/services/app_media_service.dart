import 'package:supabase_flutter/supabase_flutter.dart';

/// Resuelve medios del diseño desde la configuración remota de Supabase.
class AppMediaService {
  AppMediaService._();

  static final instance = AppMediaService._();
  final _supabase = Supabase.instance.client;
  final Map<String, Future<String?>> _urlCache = {};

  Future<String?> publicUrlFor(String key) =>
      _urlCache.putIfAbsent(key, () => _fetchPublicUrl(key));

  Future<String?> _fetchPublicUrl(String key) async {
    try {
      final row = await _supabase
          .from('app_media_config')
          .select('storage_bucket, storage_path')
          .eq('key', key)
          .maybeSingle();
      final bucket = row?['storage_bucket']?.toString();
      final path = row?['storage_path']?.toString();
      if (bucket == null || path == null || bucket.isEmpty || path.isEmpty) {
        return null;
      }
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
