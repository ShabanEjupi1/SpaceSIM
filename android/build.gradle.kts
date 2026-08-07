// Shtojca e Google Services — ajo që lexon `app/google-services.json` dhe e
// kthen në burime Android që Firebase-i i gjen në kohë ekzekutimi.
//
// 🚨 Udhëzimet e konsolës së Firebase-it janë në Groovy (`build.gradle`); ky
// projekt është në Kotlin DSL. Kopjimi fjalë për fjalë dështon me «Unresolved
// reference: classpath» — sintaksa është e ndryshme, jo konfigurimi.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
