package customfit.ai.kotlinclient.lifecycle

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.logging.Timber
import java.util.concurrent.atomic.AtomicBoolean

/**
 * A lifecycle manager that handles the CFClient's lifecycle in JVM applications.
 * This class provides methods to initialize, manage, and cleanup the CFClient.
 */
class CFLifecycleManager private constructor(
    private val cfConfig: CFConfig,
    private val user: CFUser
) {
    private var client: CFClient? = null
    private val isInitialized = AtomicBoolean(false)

    init {
        Runtime.getRuntime().addShutdownHook(Thread {
            cleanup()
        })
    }

    /**
     * Initializes the CFClient if it hasn't been initialized yet.
     * This should be called when your application starts.
     */
    fun initialize() {
        if (isInitialized.compareAndSet(false, true)) {
            client = CFClient.init(cfConfig, user)
            if (cfConfig.autoEnvAttributesEnabled) {
                client?.enableAutoEnvAttributes()
            }
            client?.setOnline()
            Timber.i("CFClient initialized through lifecycle manager")
        }
    }

    /**
     * Puts the client in offline mode.
     * This should be called when your application is going to background or needs to pause operations.
     */
    fun pause() {
        if (isInitialized.get()) {
            if (cfConfig.disableBackgroundPolling) {
                client?.setOffline()
            }
            Timber.d("CFClient paused")
        }
    }

    /**
     * Restores the client to online mode.
     * This should be called when your application is returning to foreground or resuming operations.
     */
    fun resume() {
        if (isInitialized.get()) {
            client?.setOnline()
            client?.incrementAppLaunchCount()
            Timber.d("CFClient resumed")
        }
    }

    /**
     * Cleans up resources and shuts down the client.
     * This is automatically called when the JVM shuts down.
     */
    fun cleanup() {
        if (isInitialized.compareAndSet(true, false)) {
            client?.shutdown()
            client = null
            Timber.i("CFClient cleaned up through lifecycle manager")
        }
    }

    /**
     * Gets the current CFClient instance.
     * Returns null if the client hasn't been initialized.
     */
    fun getClient(): CFClient? = client

    companion object {
        private var instance: CFLifecycleManager? = null

        /**
         * Initializes the CFClient with lifecycle management.
         * This should be called when your application starts.
         *
         * @param cfConfig The CFConfig to use
         * @param user The CFUser to use
         */
        @JvmStatic
        fun initialize(cfConfig: CFConfig, user: CFUser) {
            if (instance == null) {
                instance = CFLifecycleManager(cfConfig, user)
                instance?.initialize()
                Timber.i("CFLifecycleManager initialized")
            }
        }

        /**
         * Gets the current CFClient instance.
         * Returns null if the client hasn't been initialized.
         */
        @JvmStatic
        fun getInstanceClient(): CFClient? = instance?.client

        /**
         * Puts the client in offline mode.
         */
        @JvmStatic
        fun pauseInstance() {
            instance?.pause()
        }

        /**
         * Restores the client to online mode.
         */
        @JvmStatic
        fun resumeInstance() {
            instance?.resume()
        }

        /**
         * Cleans up resources and shuts down the client.
         */
        @JvmStatic
        fun cleanupInstance() {
            instance?.cleanup()
            instance = null
        }
    }
} 