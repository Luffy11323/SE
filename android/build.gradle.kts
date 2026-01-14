// android/build.gradle (Project-level)

allprojects {
    repositories {
        google() // Google's Maven repository
        mavenCentral() // Maven Central repository
    }
}

// Clean task, already fine for your setup.
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Cleaning task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Add classpath for the Google services plugin (Firebase)
buildscript {
    repositories {
        google() // Google's repository for Firebase
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0' // Match your Android Gradle plugin version
        classpath 'com.google.gms:google-services:4.4.3' // Firebase services plugin (ensure this is the latest version)
    }
}
