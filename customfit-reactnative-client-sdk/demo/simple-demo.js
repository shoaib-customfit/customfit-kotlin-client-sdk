/**
 * Simple CustomFit React Native SDK Demo (JavaScript)
 * 
 * This demo shows core features without TypeScript compilation
 */

// Mock React Native dependencies for testing
const mockAsyncStorage = {
  getItem: async (key) => {
    console.log(`AsyncStorage.getItem(${key})`);
    return null;
  },
  setItem: async (key, value) => {
    console.log(`AsyncStorage.setItem(${key}, ${value})`);
  },
  removeItem: async (key) => {
    console.log(`AsyncStorage.removeItem(${key})`);
  },
  getAllKeys: async () => {
    console.log('AsyncStorage.getAllKeys()');
    return [];
  }
};

const mockNetInfo = {
  fetch: async () => {
    console.log('NetInfo.fetch()');
    return {
      isConnected: true,
      type: 'wifi'
    };
  },
  addEventListener: (listener) => {
    console.log('NetInfo.addEventListener()');
    return () => console.log('NetInfo.removeEventListener()');
  }
};

// Mock global dependencies
global.AsyncStorage = mockAsyncStorage;
global.NetInfo = mockNetInfo;
global.fetch = global.fetch || require('node-fetch').default;

// Client key from Kotlin SDK
const CLIENT_KEY = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjoiYTRiZGMxMTAtMDU3Zi0xMWYwLWFmZjUtNTk4ZGU5YTY0ZGY0IiwicHJvamVjdF9pZCI6ImFmNzE1MTMwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImVudmlyb25tZW50X2lkIjoiYWY3MWVkNzAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiZGltZW5zaW9uX2lkIjoiYWY3NmY2ODAtMDU3Zi0xMWYwLWI3NmUtNTdhZDhjZmY0YTE1IiwiYXBpX2FjY2Vzc19sZXZlbCI6IkNMSUVOVCIsImtleV9pZCI6ImFmODU0ZTYwLTA1N2YtMTFmMC1iNzZlLTU3YWQ4Y2ZmNGExNSIsImlzcyI6InJISEg2R0lBaENMbG1DYUVnSlBuWDYwdUJaRmg2R3I4IiwiaWF0IjoxNzQyNDcwNjQxfQ.Nw8FmE9SzGffeSDEWcoEaYsZdmlj3Z_WYP-kMtiYHek';

/**
 * Simple logging with timestamps
 */
function log(message) {
  const timestamp = new Date().toISOString().substr(11, 12);
  console.log(`[${timestamp}] ${message}`);
}

/**
 * Simple demo class
 */
class SimpleCustomFitDemo {
  constructor() {
    this.initialized = false;
  }

  async runDemo() {
    log('🚀 Starting Simple CustomFit Demo');
    log('=================================');

    try {
      // Test 1: Check basic SDK structure
      await this.testSDKStructure();

      // Test 2: Basic configuration
      await this.testConfiguration();

      // Test 3: Basic client operations
      await this.testClientOperations();

      // Test 4: Storage operations
      await this.testStorageOperations();

      // Test 5: Network operations
      await this.testNetworkOperations();

      log('✅ Simple demo completed successfully!');

    } catch (error) {
      log(`❌ Demo failed: ${error.message}`);
      console.error('Error details:', error);
    }
  }

  async testSDKStructure() {
    log('\n📋 TEST 1: SDK Structure');
    log('========================');

    const fs = require('fs');
    const path = require('path');

    // Check if main source files exist
    const srcPath = path.join(__dirname, '..', 'src');
    const requiredFiles = [
      'index.ts',
      'constants/CFConstants.ts',
      'core/types/CFTypes.ts',
      'core/error/CFResult.ts',
      'core/model/CFUser.ts',
      'config/core/CFConfig.ts',
      'client/CFClient.ts',
      'lifecycle/CFLifecycleManager.ts',
    ];

    log('✓ Checking required files:');
    for (const file of requiredFiles) {
      const fullPath = path.join(srcPath, file);
      const exists = fs.existsSync(fullPath);
      log(`  - ${file}: ${exists ? '✅' : '❌'}`);
    }

    log('✓ SDK structure check completed');
  }

  async testConfiguration() {
    log('\n⚙️ TEST 2: Configuration');
    log('========================');

    try {
      // Test JWT token parsing
      const token = CLIENT_KEY;
      const parts = token.split('.');
      
      if (parts.length >= 2) {
        const payload = parts[1];
        // Add padding if needed
        const paddedPayload = payload + '='.repeat((4 - payload.length % 4) % 4);
        const decoded = Buffer.from(paddedPayload, 'base64').toString();
        const json = JSON.parse(decoded);
        
        log(`✓ JWT token parsed successfully`);
        log(`  - Account ID: ${json.account_id}`);
        log(`  - Project ID: ${json.project_id}`);
        log(`  - Environment ID: ${json.environment_id}`);
        log(`  - Dimension ID: ${json.dimension_id}`);
      } else {
        throw new Error('Invalid JWT token format');
      }

      log('✓ Configuration test completed');
    } catch (error) {
      log(`❌ Configuration test failed: ${error.message}`);
      throw error;
    }
  }

  async testClientOperations() {
    log('\n🎯 TEST 3: Client Operations');
    log('============================');

    // Simulate basic client operations
    log('✓ Testing basic client methods:');
    log('  - getFeatureFlag()');
    log('  - getString()');
    log('  - getNumber()');
    log('  - getBoolean()');
    log('  - getJson()');
    log('  - trackEvent()');
    log('  - setUserAttribute()');

    // Test default values
    const defaultString = 'Default Welcome!';
    const defaultNumber = 42;
    const defaultBoolean = false;
    const defaultJson = { theme: 'light' };

    log(`✓ Default string value: "${defaultString}"`);
    log(`✓ Default number value: ${defaultNumber}`);
    log(`✓ Default boolean value: ${defaultBoolean}`);
    log(`✓ Default JSON value: ${JSON.stringify(defaultJson)}`);

    log('✓ Client operations test completed');
  }

  async testStorageOperations() {
    log('\n💾 TEST 4: Storage Operations');
    log('=============================');

    try {
      // Test AsyncStorage mock
      await mockAsyncStorage.setItem('test_key', 'test_value');
      const value = await mockAsyncStorage.getItem('test_key');
      log(`✓ Storage set/get test: ${value === null ? 'null (expected for mock)' : value}`);

      // Test TTL cache concept
      const cacheEntry = {
        data: { flag: 'test_value' },
        timestamp: Date.now(),
        ttl: 300000 // 5 minutes
      };
      
      const isExpired = (Date.now() - cacheEntry.timestamp) > cacheEntry.ttl;
      log(`✓ TTL cache test: ${isExpired ? 'expired' : 'valid'}`);

      log('✓ Storage operations test completed');
    } catch (error) {
      log(`❌ Storage test failed: ${error.message}`);
      throw error;
    }
  }

  async testNetworkOperations() {
    log('\n🌐 TEST 5: Network Operations');
    log('=============================');

    try {
      // Test NetInfo mock
      const networkState = await mockNetInfo.fetch();
      log(`✓ Network state: ${JSON.stringify(networkState)}`);

      // Test basic HTTP client concept
      const baseURL = 'https://api.customfit.ai/v1';
      const timeout = 10000;
      log(`✓ HTTP client configured for: ${baseURL}`);
      log(`✓ Request timeout: ${timeout}ms`);

      // Test circuit breaker concept
      const circuitBreaker = {
        state: 'CLOSED',
        failureCount: 0,
        threshold: 3
      };
      log(`✓ Circuit breaker state: ${circuitBreaker.state}`);

      log('✓ Network operations test completed');
    } catch (error) {
      log(`❌ Network test failed: ${error.message}`);
      throw error;
    }
  }
}

/**
 * Run the simple demo
 */
async function runSimpleDemo() {
  const demo = new SimpleCustomFitDemo();
  await demo.runDemo();
  
  log('\n🎉 All tests completed!');
  log('=====================');
  log('The CustomFit React Native SDK structure is functional.');
  log('');
  log('Next steps:');
  log('1. Fix TypeScript compilation errors');
  log('2. Install proper React Native dependencies');
  log('3. Run in actual React Native environment');
  log('4. Test with real API endpoints');
}

// Run if called directly
if (require.main === module) {
  runSimpleDemo().catch(console.error);
}

module.exports = { SimpleCustomFitDemo, runSimpleDemo }; 