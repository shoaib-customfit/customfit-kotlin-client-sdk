/**
 * String extension utilities for the CustomFit React Native SDK
 */

/**
 * String utility functions
 */
export class StringExtensions {
  /**
   * Check if string is null, undefined, or empty
   */
  static isNullOrEmpty(str: string | null | undefined): boolean {
    return str === null || str === undefined || str === '';
  }

  /**
   * Check if string is null, undefined, empty, or only whitespace
   */
  static isNullOrWhitespace(str: string | null | undefined): boolean {
    return StringExtensions.isNullOrEmpty(str) || str!.trim() === '';
  }

  /**
   * Safely trim a string
   */
  static safeTrim(str: string | null | undefined): string {
    return str?.trim() || '';
  }

  /**
   * Truncate string to maximum length with ellipsis
   */
  static truncate(str: string, maxLength: number, ellipsis: string = '...'): string {
    if (!str || str.length <= maxLength) {
      return str || '';
    }
    return str.substring(0, maxLength - ellipsis.length) + ellipsis;
  }

  /**
   * Convert string to camelCase
   */
  static toCamelCase(str: string): string {
    return str
      .replace(/(?:^\w|[A-Z]|\b\w)/g, (word, index) => {
        return index === 0 ? word.toLowerCase() : word.toUpperCase();
      })
      .replace(/\s+/g, '');
  }

  /**
   * Convert string to snake_case
   */
  static toSnakeCase(str: string): string {
    return str
      .replace(/\W+/g, ' ')
      .split(/ |\B(?=[A-Z])/)
      .map(word => word.toLowerCase())
      .join('_');
  }

  /**
   * Convert string to kebab-case
   */
  static toKebabCase(str: string): string {
    return str
      .replace(/\W+/g, ' ')
      .split(/ |\B(?=[A-Z])/)
      .map(word => word.toLowerCase())
      .join('-');
  }

  /**
   * Capitalize first letter
   */
  static capitalize(str: string): string {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  /**
   * Convert to title case
   */
  static toTitleCase(str: string): string {
    return str.replace(/\w\S*/g, (txt) => {
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
  }

  /**
   * Remove special characters and keep only alphanumeric
   */
  static alphanumericOnly(str: string, keepSpaces: boolean = false): string {
    const pattern = keepSpaces ? /[^a-zA-Z0-9\s]/g : /[^a-zA-Z0-9]/g;
    return str.replace(pattern, '');
  }

  /**
   * Generate a random string
   */
  static random(length: number, charset: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'): string {
    let result = '';
    for (let i = 0; i < length; i++) {
      result += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    return result;
  }

  /**
   * Generate a UUID v4
   */
  static generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * Check if string is a valid email
   */
  static isValidEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  /**
   * Check if string is a valid URL
   */
  static isValidUrl(url: string): boolean {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Extract domain from URL
   */
  static extractDomain(url: string): string {
    try {
      return new URL(url).hostname;
    } catch {
      return '';
    }
  }

  /**
   * Mask sensitive data in string
   */
  static maskSensitive(str: string, visibleChars: number = 4, maskChar: string = '*'): string {
    if (!str || str.length <= visibleChars) {
      return str;
    }
    
    const visible = str.slice(-visibleChars);
    const masked = maskChar.repeat(str.length - visibleChars);
    return masked + visible;
  }

  /**
   * Format string as currency
   */
  static formatCurrency(amount: number, currency: string = 'USD', locale: string = 'en-US'): string {
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currency,
    }).format(amount);
  }

  /**
   * Format number with commas
   */
  static formatNumber(num: number, locale: string = 'en-US'): string {
    return new Intl.NumberFormat(locale).format(num);
  }

  /**
   * Parse query string to object
   */
  static parseQueryString(queryString: string): Record<string, string> {
    const params: Record<string, string> = {};
    const urlParams = new URLSearchParams(queryString);
    
    for (const [key, value] of urlParams.entries()) {
      params[key] = value;
    }
    
    return params;
  }

  /**
   * Convert object to query string
   */
  static toQueryString(obj: Record<string, any>): string {
    const params = new URLSearchParams();
    
    for (const [key, value] of Object.entries(obj)) {
      if (value !== null && value !== undefined) {
        params.append(key, String(value));
      }
    }
    
    return params.toString();
  }

  /**
   * Escape HTML entities
   */
  static escapeHtml(str: string): string {
    const htmlEscapes: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    
    return str.replace(/[&<>"']/g, (match) => htmlEscapes[match]);
  }

  /**
   * Unescape HTML entities
   */
  static unescapeHtml(str: string): string {
    const htmlUnescapes: Record<string, string> = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
    };
    
    return str.replace(/&(amp|lt|gt|quot|#39);/g, (match) => htmlUnescapes[match]);
  }

  /**
   * Convert string to base64
   */
  static toBase64(str: string): string {
    if (typeof btoa !== 'undefined') {
      return btoa(str);
    }
    
    // Fallback for React Native
    return Buffer.from(str, 'utf8').toString('base64');
  }

  /**
   * Convert base64 to string
   */
  static fromBase64(base64: string): string {
    if (typeof atob !== 'undefined') {
      return atob(base64);
    }
    
    // Fallback for React Native
    return Buffer.from(base64, 'base64').toString('utf8');
  }

  /**
   * Calculate Levenshtein distance between two strings
   */
  static levenshteinDistance(str1: string, str2: string): number {
    const matrix = Array(str2.length + 1).fill(null).map(() => Array(str1.length + 1).fill(null));

    for (let i = 0; i <= str1.length; i++) {
      matrix[0][i] = i;
    }

    for (let j = 0; j <= str2.length; j++) {
      matrix[j][0] = j;
    }

    for (let j = 1; j <= str2.length; j++) {
      for (let i = 1; i <= str1.length; i++) {
        const indicator = str1[i - 1] === str2[j - 1] ? 0 : 1;
        matrix[j][i] = Math.min(
          matrix[j][i - 1] + 1, // deletion
          matrix[j - 1][i] + 1, // insertion
          matrix[j - 1][i - 1] + indicator // substitution
        );
      }
    }

    return matrix[str2.length][str1.length];
  }

  /**
   * Calculate string similarity (0-1)
   */
  static similarity(str1: string, str2: string): number {
    const maxLength = Math.max(str1.length, str2.length);
    if (maxLength === 0) return 1;
    
    const distance = StringExtensions.levenshteinDistance(str1, str2);
    return (maxLength - distance) / maxLength;
  }
} 