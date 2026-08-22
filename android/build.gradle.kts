allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = rootProject.layout.buildDirectory.dir(project.name).get()
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.0")
            force("androidx.compose.remote:remote-creation-android:1.0.0-alpha01")
        }
    }

    fun configureProject() {
        project.extensions.findByName("android")?.let { android ->
            try {
                val androidExtension = android as? com.android.build.api.dsl.CommonExtension
                if (androidExtension != null) {
                    if (androidExtension.namespace == null) {
                        androidExtension.namespace = project.group.toString().takeIf { it.isNotEmpty() && it != "null" }
                            ?: "com.example.${project.name.replace("-", "_")}"
                    }
                    
                    androidExtension.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                    androidExtension.compileOptions.targetCompatibility = JavaVersion.VERSION_17
                    androidExtension.compileSdk = 36
                }
            } catch (e: Exception) {
                // Fallback for non-standard android extensions
            }
        }
        
        // Force Kotlin JVM Target
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                freeCompilerArgs.add("-Xjdk-release=17")
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
