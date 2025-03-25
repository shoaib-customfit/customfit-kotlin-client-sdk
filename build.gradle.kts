import org.gradle.jvm.tasks.Jar
import org.gradle.api.publish.maven.MavenPublication

plugins {
    kotlin("jvm") version "2.1.10"
    id("io.github.gradle-nexus.publish-plugin") version "1.3.0"
    `maven-publish`
    signing
}

// Group/Version must match your Sonatype-approved coordinates
group = "ai.customfit"
version = "1.1.1"  // Use a non-SNAPSHOT version when making a release

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))

    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    implementation("io.jsonwebtoken:jjwt-impl:0.11.5")
    implementation("io.jsonwebtoken:jjwt-jackson:0.11.5")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.5.2") 
    implementation("org.json:json:20250107")
    implementation("joda-time:joda-time:2.10.10")
}

tasks.test {
    useJUnitPlatform()
}

// Optional: specify which JVM toolchain to use
kotlin {
    jvmToolchain(17)
}

// Create a sources Jar task
val sourcesJar by tasks.registering(Jar::class) {
    archiveClassifier.set("sources")
    from(sourceSets["main"].allSource)
}

// Create a javadoc Jar task
val javadocJar by tasks.registering(Jar::class) {
    archiveClassifier.set("javadoc")
    // For actual Kotlin docs, consider Dokka. For now, we just package javadoc outputs:
    from(tasks["javadoc"])
}

// Configure Maven publishing
publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])

            // Attach sources & javadoc jars
            artifact(sourcesJar)
            artifact(javadocJar)

            // POM metadata required by Maven Central
            pom {
                name.set("Kotlin Client SDK")
                description.set("A Kotlin client SDK for CustomFit.ai (Feature Flags, Config, etc.)")
                url.set("https://github.com/shoaib-customfit/kotlin-client-sdk")

                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }

                developers {
                    developer {
                        id.set("shoaib-customfit")
                        name.set("Shoaib Mohammed")
                        email.set("shoaib@customfit.ai")
                    }
                }

                scm {
                    connection.set("scm:git:git://github.com/shoaib-customfit/kotlin-client-sdk.git")
                    developerConnection.set("scm:git:ssh://github.com/shoaib-customfit/kotlin-client-sdk.git")
                    url.set("https://github.com/shoaib-customfit/kotlin-client-sdk")
                }
            }
        }
    }
}

// GPG signing configuration
signing {
    sign(publishing.publications["mavenJava"])
}

nexusPublishing {
    repositories {
        sonatype {
            nexusUrl.set(uri("https://s01.oss.sonatype.org/service/local/"))
            snapshotRepositoryUrl.set(uri("https://s01.oss.sonatype.org/content/repositories/snapshots/"))

        }
    }
}