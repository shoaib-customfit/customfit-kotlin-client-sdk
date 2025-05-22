import { CFResult } from '../core/error/CFResult';
import { ErrorCategory } from '../core/types/CFTypes';
import { Logger } from '../logging/Logger';

/**
 * JSON serialization utilities with error handling and type safety
 */
export class JsonSerializer {
  /**
   * Serialize an object to JSON string
   */
  static serialize<T>(obj: T): CFResult<string> {
    try {
      if (obj === null || obj === undefined) {
        return CFResult.success('null');
      }

      const jsonString = JSON.stringify(obj, JsonSerializer.replacer);
      Logger.trace(`JsonSerializer: Serialized object to ${jsonString.length} characters`);
      return CFResult.success(jsonString);
    } catch (error) {
      Logger.error(`JsonSerializer: Failed to serialize object: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.SERIALIZATION);
    }
  }

  /**
   * Deserialize JSON string to object
   */
  static deserialize<T>(jsonString: string): CFResult<T> {
    try {
      if (!jsonString || jsonString.trim() === '') {
        return CFResult.errorWithMessage('Empty JSON string', ErrorCategory.SERIALIZATION);
      }

      const obj = JSON.parse(jsonString, JsonSerializer.reviver) as T;
      Logger.trace(`JsonSerializer: Deserialized ${jsonString.length} characters to object`);
      return CFResult.success(obj);
    } catch (error) {
      Logger.error(`JsonSerializer: Failed to deserialize JSON: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.SERIALIZATION);
    }
  }

  /**
   * Serialize with pretty printing for debugging
   */
  static serializePretty<T>(obj: T, indent: number = 2): CFResult<string> {
    try {
      if (obj === null || obj === undefined) {
        return CFResult.success('null');
      }

      const jsonString = JSON.stringify(obj, JsonSerializer.replacer, indent);
      Logger.trace(`JsonSerializer: Pretty serialized object to ${jsonString.length} characters`);
      return CFResult.success(jsonString);
    } catch (error) {
      Logger.error(`JsonSerializer: Failed to pretty serialize object: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.SERIALIZATION);
    }
  }

  /**
   * Validate if string is valid JSON
   */
  static isValidJson(jsonString: string): boolean {
    try {
      JSON.parse(jsonString);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Deep clone an object using JSON serialization
   */
  static deepClone<T>(obj: T): CFResult<T> {
    const serialized = JsonSerializer.serialize(obj);
    if (serialized.isError) {
      return serialized;
    }

    return JsonSerializer.deserialize<T>(serialized.data!);
  }

  /**
   * Merge multiple objects into one with JSON deep cloning
   */
  static mergeObjects<T>(...objects: Partial<T>[]): CFResult<T> {
    try {
      const merged = {} as T;
      
      for (const obj of objects) {
        if (obj) {
          const cloneResult = JsonSerializer.deepClone(obj);
          if (cloneResult.isError) {
            return cloneResult;
          }
          Object.assign(merged, cloneResult.data);
        }
      }

      return CFResult.success(merged);
    } catch (error) {
      Logger.error(`JsonSerializer: Failed to merge objects: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.SERIALIZATION);
    }
  }

  /**
   * Convert object to URL query string
   */
  static toQueryString(obj: Record<string, any>): CFResult<string> {
    try {
      const params = new URLSearchParams();
      
      for (const [key, value] of Object.entries(obj)) {
        if (value !== null && value !== undefined) {
          if (typeof value === 'object') {
            params.append(key, JSON.stringify(value));
          } else {
            params.append(key, String(value));
          }
        }
      }

      const queryString = params.toString();
      Logger.trace(`JsonSerializer: Created query string with ${queryString.length} characters`);
      return CFResult.success(queryString);
    } catch (error) {
      Logger.error(`JsonSerializer: Failed to create query string: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.SERIALIZATION);
    }
  }

  /**
   * Parse URL query string to object
   */
  static fromQueryString(queryString: string): CFResult<Record<string, any>> {
    try {
      const params = new URLSearchParams(queryString);
      const obj: Record<string, any> = {};

      for (const [key, value] of params.entries()) {
        // Try to parse as JSON first, fallback to string
        try {
          obj[key] = JSON.parse(value);
        } catch {
          obj[key] = value;
        }
      }

      Logger.trace(`JsonSerializer: Parsed query string to object with ${Object.keys(obj).length} keys`);
      return CFResult.success(obj);
    } catch (error) {
      Logger.error(`JsonSerializer: Failed to parse query string: ${error}`);
      return CFResult.errorFromException(error as Error, ErrorCategory.SERIALIZATION);
    }
  }

  /**
   * Flatten nested object for API transmission
   */
  static flatten(obj: Record<string, any>, prefix: string = ''): Record<string, any> {
    const flattened: Record<string, any> = {};

    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        const value = obj[key];
        const newKey = prefix ? `${prefix}.${key}` : key;

        if (value !== null && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date)) {
          // Recursively flatten nested objects
          Object.assign(flattened, JsonSerializer.flatten(value, newKey));
        } else {
          flattened[newKey] = value;
        }
      }
    }

    return flattened;
  }

  /**
   * Unflatten object from dot notation
   */
  static unflatten(obj: Record<string, any>): Record<string, any> {
    const result: Record<string, any> = {};

    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        const keys = key.split('.');
        let current = result;

        for (let i = 0; i < keys.length - 1; i++) {
          const k = keys[i];
          if (!(k in current)) {
            current[k] = {};
          }
          current = current[k];
        }

        current[keys[keys.length - 1]] = obj[key];
      }
    }

    return result;
  }

  /**
   * Sanitize object for safe serialization (remove functions, circular refs, etc.)
   */
  static sanitize(obj: any, seen = new WeakSet()): any {
    if (obj === null || obj === undefined) {
      return obj;
    }

    if (typeof obj === 'function') {
      return '[Function]';
    }

    if (typeof obj === 'symbol') {
      return obj.toString();
    }

    if (obj instanceof Date) {
      return obj.toISOString();
    }

    if (obj instanceof Error) {
      return {
        name: obj.name,
        message: obj.message,
        stack: obj.stack,
      };
    }

    if (typeof obj !== 'object') {
      return obj;
    }

    // Handle circular references
    if (seen.has(obj)) {
      return '[Circular]';
    }

    seen.add(obj);

    if (Array.isArray(obj)) {
      return obj.map(item => JsonSerializer.sanitize(item, seen));
    }

    const sanitized: Record<string, any> = {};
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        sanitized[key] = JsonSerializer.sanitize(obj[key], seen);
      }
    }

    return sanitized;
  }

  /**
   * Custom replacer function for JSON.stringify
   */
  private static replacer(key: string, value: any): any {
    // Handle special types
    if (value instanceof Date) {
      return value.toISOString();
    }

    if (value instanceof Error) {
      return {
        name: value.name,
        message: value.message,
        stack: value.stack,
      };
    }

    if (typeof value === 'function') {
      return '[Function]';
    }

    if (typeof value === 'symbol') {
      return value.toString();
    }

    if (typeof value === 'bigint') {
      return value.toString();
    }

    return value;
  }

  /**
   * Custom reviver function for JSON.parse
   */
  private static reviver(key: string, value: any): any {
    // Try to parse ISO date strings back to Date objects
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(value)) {
      const date = new Date(value);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }

    return value;
  }
} 