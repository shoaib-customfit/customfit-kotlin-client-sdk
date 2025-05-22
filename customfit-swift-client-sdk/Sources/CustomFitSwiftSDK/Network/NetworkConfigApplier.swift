import Foundation

/// Applies network configuration settings to HTTP clients
public class NetworkConfigApplier {
    
    /**
     * Apply network configuration settings to a URLRequest
     *
     * @param request URLRequest to configure
     * @param config CFConfig containing network settings
     * @return The configured request
     */
    public static func configureUrlRequest(_ request: URLRequest, config: CFConfig) -> URLRequest {
        var mutableRequest = request
        mutableRequest.timeoutInterval = TimeInterval(config.networkConnectionTimeoutMs) / 1000.0
        
        // Log the configuration
        Logger.debug("Configured URLRequest with timeout=\(config.networkConnectionTimeoutMs)ms")
        
        // Additional request settings can be applied here
        return mutableRequest
    }
    
    /**
     * Apply network configuration settings to a URLSession configuration
     *
     * @param sessionConfig URLSessionConfiguration to configure
     * @param config CFConfig containing network settings
     * @return The configured session configuration
     */
    public static func configureSessionConfiguration(_ sessionConfig: URLSessionConfiguration, config: CFConfig) -> URLSessionConfiguration {
        let mutableConfig = sessionConfig
        
        // Convert milliseconds to seconds for timeouts
        mutableConfig.timeoutIntervalForRequest = TimeInterval(config.networkReadTimeoutMs) / 1000.0
        mutableConfig.timeoutIntervalForResource = TimeInterval(config.networkConnectionTimeoutMs) / 1000.0
        
        // Log the configuration
        Logger.debug("Configured URLSessionConfiguration with connectionTimeout=\(config.networkConnectionTimeoutMs)ms, readTimeout=\(config.networkReadTimeoutMs)ms")
        
        return mutableConfig
    }
} 