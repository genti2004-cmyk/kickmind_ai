class KickMindFeatureFlags {
  const KickMindFeatureFlags._();

  /// Sicherer Standard:
  /// - API an
  /// - Mock-Fallback an, damit die App nicht crasht
  /// - Pro-Enrichment an, damit AI-Score/Risiko sichtbar bleiben
  static const bool useRealApi = true;
  static const bool allowMockFallback = true;
  static const bool useProEnrichment = true;
}
