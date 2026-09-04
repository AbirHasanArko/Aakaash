allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Workaround: AGP 8+ requires every module to declare a `namespace`.
// Some older Flutter plugins (e.g. flutter_keyboard_visibility 5.4.1) still
// rely on the old `package` attribute in their source AndroidManifest.xml.
// Inject a namespace here so the build doesn't fail with `Namespace not specified`.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            if (androidExt != null && androidExt.namespace == null) {
                androidExt.namespace = project.group.toString()
            }
        }
    }
}

// Workaround: legacy plugins (e.g. flutter_keyboard_visibility 5.4.1) pin their
// own compileSdk to 31, which fails checkDebugAarMetadata because their transitive
// androidx.* deps require compileSdk >= 34. Force every Android library subproject
// to compile against the same SDK we use in the app module (compileSdk = 36).
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            if (androidExt != null) {
                androidExt.compileSdk = 36
            }
        }
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
