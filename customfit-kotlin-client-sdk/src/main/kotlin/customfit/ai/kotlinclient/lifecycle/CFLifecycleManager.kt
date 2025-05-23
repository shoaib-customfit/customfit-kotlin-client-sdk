package customfit.ai.kotlinclient.lifecycle

import customfit.ai.kotlinclient.client.CFClient
import customfit.ai.kotlinclient.config.core.CFConfig
import customfit.ai.kotlinclient.core.model.CFUser
import customfit.ai.kotlinclient.logging.Timber
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.concurrent.atomic.AtomicBoolean

/**
 * A lifecycle manager that handles the CFClient's lifecycle in JVM applications.
 * This class provides methods to initialize, manage, and cleanup the CFClient using the singleton pattern.
 */
class CFLifecycleManager private constructor(
    private val cfConfig: CFConfig,
    private val user: CFUser
) {
    private val isInitialized = AtomicBoolean(false)
    private val lifecycleScope = CoroutineScope(Dispatchers.IO)

    init {
        Runtime.getRuntime().addShutdownHook(Thread {
            runBlocking {
                cleanup()
            }
        })
    }

    /**
     * Initializes the CFClient singleton if it hasn't been initialized yet.
     * This should be called when your application starts.
     */
    suspend fun initialize() {
        if (isInitialized.compareAndSet(false, true)) {
            try {
                val client = CFClient.init(cfConfig, user)
                // Auto environment attributes are now handled automatically via config.autoEnvAttributesEnabled
                client.setOnline()
                Timber.i("CFClient singleton initialized through lifecycle manager")
            } catch (e: Exception) {
                isInitialized.set(false)
                Timber.e(e, "Failed to initialize CFClient through lifecycle manager")
                throw e
            }
        } else {
            Timber.i("CFClient singleton already initialized")
        }
    }

    /**
     * Initializes the CFClient singleton asynchronously.
     * Use this for fire-and-forget initialization.
     */
    fun initializeAsync() {
        lifecycleScope.launch {
            initialize()
        }
    }

    /**
     * Puts the client in offline mode.
     * This should be called when your application is going to background or needs to pause operations.
     */
    fun pause() {
        if (isInitialized.get()) {
            val client = CFClient.getInstance()
            if (client != null && cfConfig.disableBackgroundPolling) {
                client.setOffline()
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
            val client = CFClient.getInstance()
            client?.setOnline()
            client?.incrementAppLaunchCount()
            Timber.d("CFClient resumed")
        }
    }

    /**
     * Cleans up resources and shuts down the client.
     * This is automatically called when the JVM shuts down.
     */
    suspend fun cleanup() {
        if (isInitialized.compareAndSet(true, false)) {
            CFClient.shutdown()
            Timber.i("CFClient singleton cleaned up through lifecycle manager")
        }
    }

    /**
     * Gets the current CFClient singleton instance.
     * Returns null if the client hasn't been initialized.
     */
    fun getClient(): CFClient? = CFClient.getInstance()

    companion object {
        private var instance: CFLifecycleManager? = null

        /**
         * Initializes the CFClient with lifecycle management using the singleton pattern.
         * This should be called when your application starts.
         *
         * @param cfConfig The CFConfig to use
         * @param user The CFUser to use
         */
        @JvmStatic
        suspend fun initialize(cfConfig: CFConfig, user: CFUser) {
            if (instance == null) {
                instance = CFLifecycleManager(cfConfig, user)
                instance?.initialize()
                Timber.i("CFLifecycleManager initialized")
            } else {
                Timber.i("CFLifecycleManager already exists")
            }
        }

        /**
         * Initializes the CFClient with lifecycle management asynchronously.
         * Use this for fire-and-forget initialization.
         *
         * @param cfConfig The CFConfig to use
         * @param user The CFUser to use
         */
        @JvmStatic
        fun initializeAsync(cfConfig: CFConfig, user: CFUser) {
            if (instance == null) {
                instance = CFLifecycleManager(cfConfig, user)
                instance?.initializeAsync()
                Timber.i("CFLifecycleManager initialized asynchronously")
            } else {
                Timber.i("CFLifecycleManager already exists")
            }
        }

        /**
         * Gets the current CFClient singleton instance.
         * Returns null if the client hasn't been initialized.
         */
        @JvmStatic
        fun getInstanceClient(): CFClient? = CFClient.getInstance()

        /**
         * Check if the CFClient singleton is initialized.
         */
        @JvmStatic
        fun isInitialized(): Boolean = CFClient.isInitialized()

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
         * Cleans up resources and shuts down the client singleton.
         */
        @JvmStatic
        suspend fun cleanupInstance() {
            instance?.cleanup()
            instance = null
        }
        
        /**
         * Cleans up resources and shuts down the client singleton (blocking version).
         * Use this in shutdown hooks or when you can't use coroutines.
         */
        @JvmStatic
        fun cleanupInstanceBlocking() {
            runBlocking {
                cleanupInstance()
            }
        }
    }
} 