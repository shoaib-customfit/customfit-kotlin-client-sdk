plugins {
    kotlin("jvm") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
    application
}

group = "ai.customfit"
version = "1.1.1"

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(17)
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.withType<JavaCompile> {
    sourceCompatibility = JavaVersion.VERSION_17.toString()
    targetCompatibility = JavaVersion.VERSION_17.toString()
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    implementation("io.jsonwebtoken:jjwt-impl:0.11.5")
    implementation("io.jsonwebtoken:jjwt-jackson:0.11.5")
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
    implementation("org.slf4j:slf4j-api:2.0.9")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
    implementation(kotlin("reflect"))
    testImplementation(kotlin("test"))
}

application {
    mainClass.set("customfit.ai.MainKt")
}

tasks.register<JavaExec>("runLoggingTest") {
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("customfit.ai.kotlinclient.logging.LoggingTestKt")
}

tasks.withType<Jar> {
    manifest {
        attributes["Main-Class"] = "customfit.ai.MainKt"
    }
    //from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
}