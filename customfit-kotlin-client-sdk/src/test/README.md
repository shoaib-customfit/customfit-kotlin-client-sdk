# CustomFit Kotlin Client SDK - Test Suite

This directory contains comprehensive unit tests for the CustomFit Kotlin Client SDK. The test suite is designed to ensure reliability, correctness, and maintainability of the SDK.

## Test Structure

```
src/test/kotlin/customfit/ai/kotlinclient/
├── TestSuite.kt                           # Main test suite runner
├── core/
│   ├── model/
│   │   └── CFUserTest.kt                  # Tests for CFUser model
│   └── error/
│       └── CFResultTest.kt                # Tests for CFResult error handling
├── config/
│   └── core/
│       └── CFConfigTest.kt                # Tests for CFConfig configuration
├── utils/
│   └── CoroutineUtilsTest.kt             # Tests for coroutine utilities
└── client/
    └── CFClientTest.kt                    # Tests for main CFClient functionality
```

## Test Coverage

### Core Models (`core/model/`)
- **CFUserTest**: Comprehensive testing of the CFUser model
  - User creation with builder pattern
  - Property management (string, number, boolean, date, geo, JSON)
  - Context management
  - Device and application info handling
  - Immutability and data integrity
  - Edge cases and validation

### Configuration (`config/core/`)
- **CFConfigTest**: Testing of configuration management
  - Default values and validation
  - Builder pattern functionality
  - JWT token parsing and dimension ID extraction
  - Custom configuration options
  - Validation of configuration parameters
  - Error handling for invalid configurations

### Error Handling (`core/error/`)
- **CFResultTest**: Testing of the result type system
  - Success and error result creation
  - Result transformations and mapping
  - Chaining operations
  - Error propagation
  - Utility methods (getOrNull, getOrElse, etc.)

### Utilities (`utils/`)
- **CoroutineUtilsTest**: Testing of coroutine utilities
  - Scope creation and management
  - Error handling in coroutines
  - Retry logic with exponential backoff
  - Timeout handling
  - Parallel execution
  - Cancellation handling

### Client Functionality (`client/`)
- **CFClientTest**: Testing of the main SDK client
  - Client initialization and lifecycle
  - User management and identification
  - Property and context management
  - Event tracking
  - Feature flag evaluation
  - Listener management
  - Connection handling
  - Configuration changes

## Testing Framework

The test suite uses modern testing frameworks and libraries:

- **JUnit 5**: Primary testing framework with support for nested tests and parameterized tests
- **MockK**: Kotlin-first mocking library for creating test doubles
- **AssertJ**: Fluent assertion library for readable test assertions
- **Coroutines Test**: Testing utilities for coroutine-based code
- **Logback**: Logging framework for test output

## Running Tests

### Prerequisites
- Java 17 or higher
- Gradle 8.0 or higher

### Run All Tests
```bash
./gradlew test
```

### Run Specific Test Class
```bash
./gradlew test --tests "customfit.ai.kotlinclient.core.model.CFUserTest"
```

### Run Tests with Coverage
```bash
./gradlew test jacocoTestReport
```

### Run Tests in Continuous Mode
```bash
./gradlew test --continuous
```

## Test Configuration

The test configuration is defined in `build.gradle.kts`:

```kotlin
tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
        showStandardStreams = false
    }
}
```

## Test Patterns and Best Practices

### 1. Naming Convention
Tests follow the pattern: `should [expected behavior] when [condition]`
```kotlin
@Test
fun `should create CFUser with minimal parameters`()

@Test
fun `should return error result when exception occurs`()
```

### 2. Test Structure
Tests follow the Arrange-Act-Assert pattern:
```kotlin
@Test
fun `should add property and return new instance`() {
    // Arrange
    val originalUser = CFUser(user_customer_id = "test-user")
    
    // Act
    val updatedUser = originalUser.addProperty("age", 25)
    
    // Assert
    assertThat(originalUser.properties).isEmpty()
    assertThat(updatedUser.properties).containsEntry("age", 25)
}
```

### 3. Mocking
MockK is used for creating test doubles:
```kotlin
val mockListener = mockk<FeatureFlagChangeListener>(relaxed = true)
```

### 4. Coroutine Testing
Coroutine tests use `runTest` for proper test execution:
```kotlin
@Test
fun `should handle async operation`() = runTest {
    val result = CoroutineUtils.withErrorHandling {
        "success"
    }
    assertThat(result.isSuccess).isTrue()
}
```

### 5. Edge Cases
Tests include edge cases and error conditions:
```kotlin
@Test
fun `should handle empty JWT payload gracefully`() {
    val config = CFConfig.fromClientKey("invalid-jwt")
    assertThat(config.dimensionId).isNull()
}
```

## Test Data

Test data is created using builder patterns and factory methods:
```kotlin
private val testUser = CFUser.builder("test-user-123")
    .withStringProperty("name", "Test User")
    .withNumberProperty("age", 25)
    .build()

private val testConfig = CFConfig.Builder("test-client-key")
    .eventsQueueSize(100)
    .offlineMode(false)
    .build()
```

## Continuous Integration

The test suite is designed to run in CI/CD environments:
- Tests are deterministic and don't rely on external services
- Timeouts are configured appropriately for CI environments
- Test output is formatted for CI consumption
- Coverage reports are generated in standard formats

## Contributing to Tests

When adding new functionality to the SDK:

1. **Write tests first** (TDD approach)
2. **Cover happy path and edge cases**
3. **Use descriptive test names**
4. **Follow existing patterns and conventions**
5. **Mock external dependencies**
6. **Test error conditions**
7. **Ensure tests are fast and reliable**

### Adding New Test Classes

1. Create the test class in the appropriate package
2. Follow the naming convention: `[ClassName]Test`
3. Use appropriate annotations (`@Test`, `@BeforeEach`, etc.)
4. Add comprehensive test coverage
5. Update this README if needed

## Test Metrics

The test suite aims for:
- **Line Coverage**: > 80%
- **Branch Coverage**: > 75%
- **Test Execution Time**: < 30 seconds for full suite
- **Test Reliability**: 0% flaky tests

## Troubleshooting

### Common Issues

1. **Tests fail with timeout**: Increase timeout values in test configuration
2. **MockK issues**: Ensure proper relaxed mocking for complex objects
3. **Coroutine tests hang**: Use `runTest` and proper test dispatchers
4. **Assertion failures**: Check test data setup and expected values

### Debug Mode
Run tests with debug logging:
```bash
./gradlew test --debug
```

### Test Reports
Test reports are generated in:
- `build/reports/tests/test/index.html` - HTML test report
- `build/test-results/test/` - XML test results
- `build/reports/jacoco/test/html/index.html` - Coverage report 