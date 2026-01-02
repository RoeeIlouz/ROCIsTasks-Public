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
    
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // Namespace Logic
                val namespaceMethod = android.javaClass.getMethod("getNamespace")
                val currentNamespace = namespaceMethod.invoke(android)
                if (currentNamespace == null) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    var groupName = project.group.toString()
                    if (groupName.isEmpty() || groupName == "null") {
                        groupName = "com.example.${project.name}"
                    }
                    setNamespaceMethod.invoke(android, groupName)
                }
                
                // Compile Options Logic (Force Java 17)
                try {
                    val getCompileOptions = android.javaClass.getMethod("getCompileOptions")
                    val compileOptions = getCompileOptions.invoke(android)
                    val setSourceComp = compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                    val setTargetComp = compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                    setSourceComp.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                    setTargetComp.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                } catch(e: Exception) {
                    // Ignore
                }
                
                // Force Compile SDK (to support Java 17)
                try {
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    setCompileSdkVersion.invoke(android, 35)
                } catch(e: Exception) {
                     try {
                        val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                        setCompileSdkVersion.invoke(android, 35)
                     } catch(e2: Exception) {
                        try {
                             // Try property access if method fails (unlikely in KTS/Groovy mix but via reflection it's method)
                             android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType).invoke(android, 35)
                        } catch(e3: Exception) { }
                     }
                }

            } catch (e: Exception) {
                // Ignore
            }


        }
        
        // Force Kotlin JVM Target
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
             compilerOptions {
                 jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
