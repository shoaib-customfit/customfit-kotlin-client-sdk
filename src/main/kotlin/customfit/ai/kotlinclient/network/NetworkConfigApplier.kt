package customfit.ai.kotlinclient.network

import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.logging.Timber
import java.net.HttpURLConnection

/**
 * Applies network configuration settings to HTTP clients
 */
class NetworkConfigApplier {
    companion object {
        /**
         * Apply network configuration settings to a HttpURLConnection
         *
         * @param connection HttpURLConnection to configure
         * @param config CFConfig containing network settings
         * @return The configured connection
         */
        fun configureUrlConnection(connection: HttpURLConnection, config: CFConfig): HttpURLConnection {
            return connection.apply {
                connectTimeout = config.networkConnectionTimeoutMs
                readTimeout = config.networkReadTimeoutMs
                // Additional connection settings can be applied here
                Timber.d("Configured HttpURLConnection with connectionTimeout=${config.networkConnectionTimeoutMs}ms, readTimeout=${config.networkReadTimeoutMs}ms")
            }
        }
    }
} 