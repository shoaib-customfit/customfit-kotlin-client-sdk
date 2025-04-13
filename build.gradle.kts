plugins {
    kotlin("jvm") version "2.1.10"
    kotlin("plugin.serialization") version "2.1.10" 
    application
}

group = "ai.customfit"
version = "1.1.1"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.json:json:20231013")
    implementation("joda-time:joda-time:2.12.5")
    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    implementation("io.jsonwebtoken:jjwt-impl:0.11.5")
    implementation("io.jsonwebtoken:jjwt-jackson:0.11.5")
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
    implementation("org.slf4j:slf4j-api:2.0.9")
    implementation("ch.qos.logback:logback-classic:1.4.11")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.0")
    implementation(kotlin("reflect"))
}

application {
    mainClass.set("customfit.ai.MainKt")
}

// Custom task to run the Timber test
tasks.register<JavaExec>("runTimberTest") {
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("customfit.ai.kotlinclient.logging.TestKt")
}

tasks.withType<Jar> {
    manifest {
        attributes["Main-Class"] = "customfit.ai.MainKt"
    }
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from(configurations.runtimeClasspath.get().map { 
        if (it.isDirectory) it else zipTree(it) 
    })
}