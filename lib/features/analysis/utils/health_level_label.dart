/// Maps the backend `health_level` enum (a derivative of `risk_level`) to a
/// Vietnamese label suitable for chip / badge rendering.
///
/// The backend produces one of `stable` / `watch` / `critical` (and may add
/// `good` / `poor` from the family-relationship summaries). Returning `null`
/// signals that the caller should fall back to its existing labelling chain
/// (typically `dashboardRiskDisplayLabel(riskLevel)`).
String? vietnameseHealthLevel(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  switch (normalized) {
    case 'stable':
    case 'good':
    case 'low':
    case 'high': // family payloads use "high" to mean "good health"
      return 'Ổn định';
    case 'watch':
    case 'medium':
    case 'moderate':
    case 'warning':
      return 'Cần theo dõi';
    case 'critical':
    case 'poor':
      return 'Nguy hiểm';
    default:
      return null;
  }
}
