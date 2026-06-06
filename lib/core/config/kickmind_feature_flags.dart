class KickMindFeatureFlags {
  const KickMindFeatureFlags._();

  /// Sicherer Standard:
  /// - API an
  /// - Mock-Fallback aus, damit keine Dummy-Spiele in der echten App erscheinen
  /// - Pro-Enrichment an, damit AI-Score/Risiko sichtbar bleiben
  static const bool useRealApi = true;
  static const bool allowMockFallback = false;
  static const bool useProEnrichment = true;
}
