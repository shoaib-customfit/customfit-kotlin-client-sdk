/**
 * Configuration request summary data matching Flutter and Kotlin implementations
 */
export interface CFConfigRequestSummary {
  config_id: string | null;
  version: number | null;
  user_id: string | null;
  requested_time: string;
  variation_id: string | null;
  user_customer_id: string;
  session_id: string;
  behaviour_id: string | null;
  experience_id: string | null;
  rule_id: string | null;
}

/**
 * Utility class for creating and managing config request summaries
 */
export class CFConfigRequestSummaryUtil {
  /**
   * Create a config request summary from config data, matching backend DTO.
   */
  static fromConfig(
    config: Record<string, any>,
    userCustomerId: string,
    sessionId: string
  ): CFConfigRequestSummary {
    const now = new Date();
    // Format to match the previously working cURL example: "YYYY-MM-DD HH:mm:ss.sssZ"
    const year = now.getUTCFullYear();
    const month = (now.getUTCMonth() + 1).toString().padStart(2, '0');
    const day = now.getUTCDate().toString().padStart(2, '0');
    const hours = now.getUTCHours().toString().padStart(2, '0');
    const minutes = now.getUTCMinutes().toString().padStart(2, '0');
    const seconds = now.getUTCSeconds().toString().padStart(2, '0');
    const milliseconds = now.getUTCMilliseconds().toString().padStart(3, '0');
    const requestedTime = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}.${milliseconds}Z`;

    let parsedVersion: number | null = null;
    if (config.version !== undefined && config.version !== null) {
      parsedVersion = parseInt(config.version.toString(), 10);
      if (isNaN(parsedVersion)) {
        // Default or throw error if version is critical and unparseable
        // DTO says @NotNull, so it must have a value.
        // Flutter's CFClient passes '1.0.0' if not available.
        // For an Integer, let's default to 1 or parse from default like '1.0.0'.
        // Assuming '1.0.0' means major version 1.
        const majorVersionMatch = config.version.toString().match(/^(\d+)/);
        if (majorVersionMatch && majorVersionMatch[1]) {
          parsedVersion = parseInt(majorVersionMatch[1],10);
        } else {
          parsedVersion = 1; // Fallback if parsing '1.0.0' style fails
        }
        if (isNaN(parsedVersion)) parsedVersion = 1; // Final fallback
      }
    } else {
      // Version is @NotNull in DTO. Default to 1 if not provided.
      parsedVersion = 1;
    }

    return {
      config_id: (config.config_id as string) ?? (config.id as string) ?? null,
      version: parsedVersion, // Use parsed integer version
      user_id: (config.user_id as string) ?? null,
      requested_time: requestedTime,
      variation_id: (config.variation_id as string) ?? (config.id as string) ?? null,
      user_customer_id: userCustomerId,
      session_id: sessionId,
      behaviour_id: (config.behaviour_id as string) ?? null,
      experience_id: (config.experience_id as string) ?? (config.id as string) ?? null,
      rule_id: (config.rule_id as string) ?? null,
    };
  }

  /**
   * Convert to map for API serialization, removing nulls (like Flutter's toMap)
   */
  static toMap(summary: CFConfigRequestSummary): Record<string, any> {
    const result: Record<string, any> = {
      config_id: summary.config_id,
      version: summary.version,
      user_id: summary.user_id,
      requested_time: summary.requested_time,
      variation_id: summary.variation_id,
      user_customer_id: summary.user_customer_id,
      session_id: summary.session_id,
      behaviour_id: summary.behaviour_id,
      experience_id: summary.experience_id,
      rule_id: summary.rule_id,
    };

    // Remove null values, matching Flutter's m.removeWhere((k, v) => v == null);
    Object.keys(result).forEach(key => {
      if (result[key] === null) { // Only remove nulls, not undefined
        delete result[key];
      }
    });

    return result;
  }

  /**
   * Validate a config request summary
   */
  static validate(summary: CFConfigRequestSummary): boolean {
    // Required fields
    if (!summary.requested_time || !summary.user_customer_id || !summary.session_id) {
      return false;
    }

    // At least one of these should be present for it to be meaningful
    if (!summary.config_id && !summary.experience_id) {
      return false;
    }

    return true;
  }
} 