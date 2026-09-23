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
// flutter_ringtone_player hardcodes compileSdk 33, but the AndroidX
// libraries it pulls in need 34+ (checkDebugAarMetadata fails otherwise).
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let {
                if ((it.compileSdk ?: 0) < 34) it.compileSdk = 36
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
