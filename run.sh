#!/bin/bash
./gradlew clean build
java -jar build/libs/kotlin-client-sdk-1.1.1.jar
