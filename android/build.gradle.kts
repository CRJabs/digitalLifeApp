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

subprojects {
    val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
    android?.compileSdkVersion(36)

    if (!project.state.executed) {
        project.afterEvaluate {
            val ext = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            ext?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
