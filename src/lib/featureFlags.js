export function isEnabledFeatureFlag(value) {
  return String(value ?? '').trim().toLowerCase() === 'true'
}

// Disabled unless the deployed backend has passed the commercial readiness audit.
export const commercialAdminEnabled = isEnabledFeatureFlag(
  import.meta.env?.VITE_COMMERCIAL_ADMIN_ENABLED,
)
