import { CFResult } from '../core/error/CFResult';
import { ErrorCategory, HttpRequestOptions, HttpResponse } from '../core/types/CFTypes';
import { RetryUtil, RetryConfig } from '../core/util/RetryUtil';
import { CircuitBreaker, CircuitBreakerConfig } from '../core/util/CircuitBreaker';
import { CFConstants } from '../constants/CFConstants';
import { Logger } from '../logging/Logger';

/**
 * HTTP client with retry logic and circuit breaker
 */
export class HttpClient {
  private readonly baseURL: string;
  private readonly defaultTimeout: number;
  private readonly retryConfig: RetryConfig;
  private readonly circuitBreaker: CircuitBreaker;
  private readonly defaultHeaders: Record<string, string>;

  constructor(
    baseURL: string = CFConstants.Api.BASE_API_URL,
    timeout: number = CFConstants.Network.CONNECTION_TIMEOUT_MS,
    retryConfig?: RetryConfig,
    circuitBreakerConfig?: CircuitBreakerConfig
  ) {
    this.baseURL = baseURL.endsWith('/') ? baseURL.slice(0, -1) : baseURL;
    this.defaultTimeout = timeout;
    
    this.retryConfig = retryConfig || {
      maxAttempts: CFConstants.RetryConfig.MAX_RETRY_ATTEMPTS,
      initialDelayMs: CFConstants.RetryConfig.INITIAL_DELAY_MS,
      maxDelayMs: CFConstants.RetryConfig.MAX_DELAY_MS,
      backoffMultiplier: CFConstants.RetryConfig.BACKOFF_MULTIPLIER,
    };

    this.circuitBreaker = new CircuitBreaker(
      circuitBreakerConfig || {
        failureThreshold: CFConstants.RetryConfig.CIRCUIT_BREAKER_FAILURE_THRESHOLD,
        resetTimeoutMs: CFConstants.RetryConfig.CIRCUIT_BREAKER_RESET_TIMEOUT_MS,
        name: 'HttpClient',
      }
    );

    this.defaultHeaders = {
      [CFConstants.Http.HEADER_CONTENT_TYPE]: CFConstants.Http.CONTENT_TYPE_JSON,
      'User-Agent': `${CFConstants.General.SDK_NAME}/${CFConstants.General.DEFAULT_SDK_VERSION}`,
    };

    Logger.debug(`HttpClient initialized with baseURL: ${this.baseURL}, timeout: ${this.defaultTimeout}ms`);
  }

  /**
   * Perform a GET request
   */
  async get(path: string, headers?: Record<string, string>): Promise<CFResult<HttpResponse>> {
    return this.request({
      method: 'GET',
      headers,
    }, path);
  }

  /**
   * Perform a POST request
   */
  async post(path: string, body?: any, headers?: Record<string, string>): Promise<CFResult<HttpResponse>> {
    return this.request({
      method: 'POST',
      headers,
      body: body ? JSON.stringify(body) : undefined,
    }, path);
  }

  /**
   * Perform a PUT request
   */
  async put(path: string, body?: any, headers?: Record<string, string>): Promise<CFResult<HttpResponse>> {
    return this.request({
      method: 'PUT',
      headers,
      body: body ? JSON.stringify(body) : undefined,
    }, path);
  }

  /**
   * Perform a DELETE request
   */
  async delete(path: string, headers?: Record<string, string>): Promise<CFResult<HttpResponse>> {
    return this.request({
      method: 'DELETE',
      headers,
    }, path);
  }

  /**
   * Perform a HEAD request
   */
  async head(path: string, headers?: Record<string, string>): Promise<CFResult<HttpResponse>> {
    return this.request({
      method: 'HEAD',
      headers,
    }, path);
  }

  /**
   * Perform a request with the given options
   */
  async request(options: HttpRequestOptions, path: string): Promise<CFResult<HttpResponse>> {
    const url = this.buildURL(path);
    const requestHeaders = { ...this.defaultHeaders, ...options.headers };
    const timeout = options.timeout || this.defaultTimeout;

    const operation = async (): Promise<CFResult<HttpResponse>> => {
      return this.circuitBreaker.execute(async () => {
        const response = await this.performRequest(url, options, requestHeaders, timeout);
        return CFResult.success(response);
      }, `${options.method} ${path}`);
    };

    const operationName = `HTTP ${options.method} ${path}`;
    Logger.debug(`${operationName} starting...`);

    const startTime = Date.now();
    const result = await RetryUtil.execute(operation, this.retryConfig, operationName);
    const duration = Date.now() - startTime;

    if (result.isSuccess) {
      Logger.debug(`${operationName} completed in ${duration}ms with status ${result.data?.status}`);
    } else {
      Logger.error(`${operationName} failed after ${duration}ms: ${result.error?.message}`);
    }

    return result;
  }

  /**
   * Get circuit breaker state
   */
  getCircuitBreakerState() {
    return this.circuitBreaker.getState();
  }

  /**
   * Reset circuit breaker
   */
  resetCircuitBreaker(): void {
    this.circuitBreaker.reset();
  }

  /**
   * Check if client is healthy (circuit breaker closed)
   */
  isHealthy(): boolean {
    return this.circuitBreaker.canExecute();
  }

  /**
   * Get metrics
   */
  getMetrics() {
    return this.circuitBreaker.getMetrics();
  }

  private async performRequest(
    url: string,
    options: HttpRequestOptions,
    headers: Record<string, string>,
    timeout: number
  ): Promise<HttpResponse> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      const fetchOptions: RequestInit = {
        method: options.method,
        headers,
        body: options.body,
        signal: controller.signal,
      };

      Logger.trace(`Making ${options.method} request to ${url}`);
      
      // Add detailed logging for debugging
      Logger.info(`🌐 HTTP REQUEST DEBUG:`);
      Logger.info(`🌐 URL: ${url}`);
      Logger.info(`🌐 METHOD: ${options.method}`);
      Logger.info(`🌐 HEADERS: ${JSON.stringify(headers, null, 2)}`);
      if (options.body) {
        const bodyStr = options.body.toString();
        Logger.info(`🌐 BODY SIZE: ${bodyStr.length} bytes`);
        Logger.info(`🌐 BODY PREVIEW: ${bodyStr.length > 500 ? bodyStr.substring(0, 500) + '...' : bodyStr}`);
      }
      
      const response = await fetch(url, fetchOptions);
      
      clearTimeout(timeoutId);

      // Parse response headers
      const responseHeaders: Record<string, string> = {};
      response.headers.forEach((value: string, key: string) => {
        responseHeaders[key.toLowerCase()] = value;
      });

      // Parse response body
      let data: any;
      const contentType = responseHeaders['content-type'] || '';
      
      if (options.method === 'HEAD') {
        // HEAD requests don't have a body
        data = null;
      } else if (contentType.includes('application/json')) {
        try {
          const text = await response.text();
          data = text ? JSON.parse(text) : null;
          
          // Log response details
          Logger.info(`🌐 HTTP RESPONSE DEBUG:`);
          Logger.info(`🌐 STATUS: ${response.status} ${response.statusText}`);
          Logger.info(`🌐 RESPONSE HEADERS: ${JSON.stringify(responseHeaders, null, 2)}`);
          if (text) {
            Logger.info(`🌐 RESPONSE BODY: ${text.length > 500 ? text.substring(0, 500) + '...' : text}`);
          }
        } catch (error) {
          Logger.warning(`Failed to parse JSON response: ${error}`);
          data = null;
        }
      } else {
        data = await response.text();
        Logger.info(`🌐 HTTP RESPONSE DEBUG:`);
        Logger.info(`🌐 STATUS: ${response.status} ${response.statusText}`);
        Logger.info(`🌐 RESPONSE HEADERS: ${JSON.stringify(responseHeaders, null, 2)}`);
        Logger.info(`🌐 RESPONSE BODY (TEXT): ${data ? data.toString().substring(0, 500) : 'null'}`);
      }

      const httpResponse: HttpResponse = {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
        data,
      };

      // Check if response indicates an error
      if (!response.ok) {
        Logger.error(`🌐 HTTP ERROR: ${response.status}: ${response.statusText}`);
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return httpResponse;
    } catch (error: any) {
      clearTimeout(timeoutId);
      
      Logger.error(`🌐 HTTP REQUEST FAILED: ${error.message}`);
      
      if (error.name === 'AbortError') {
        throw new Error(`Request timeout after ${timeout}ms`);
      }
      
      // Re-throw the error to be handled by retry logic
      throw error;
    }
  }

  private buildURL(path: string): string {
    const normalizedPath = path.startsWith('/') ? path : `/${path}`;
    return `${this.baseURL}${normalizedPath}`;
  }
} 