plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("com.tom-roush:pdfbox-android:2.0.27.0")
}

val workspaceRoot = rootProject.projectDir.parentFile.parentFile
val botProject = workspaceRoot.resolve("WhatsAppBot")
val nodeRuntimeDownload = tasks.register<Exec>("prepareBlissNodeRuntime") {
    workingDir(workspaceRoot)
    commandLine("python3", botProject.resolve("scripts/fetch_android_node_runtime.py").absolutePath)
    inputs.file(botProject.resolve("scripts/fetch_android_node_runtime.py"))
    outputs.files(
        project.file("src/main/jniLibs/arm64-v8a/libnode.so"),
        project.file("src/main/jniLibs/armeabi-v7a/libnode.so"),
        project.file("src/main/jniLibs/x86_64/libnode.so"),
        project.file("src/main/cpp/node-runtime/VERSION"),
    )
}

val compileWhatsAppBot = tasks.register<Exec>("compileWhatsAppBotRuntime") {
    workingDir(botProject)
    commandLine("npm", "run", "build")
    inputs.dir(botProject.resolve("src"))
    inputs.file(botProject.resolve("tsconfig.json"))
    outputs.dir(botProject.resolve("dist"))
}

val stageWhatsAppBot = tasks.register<Sync>("stageWhatsAppBotRuntime") {
    dependsOn(compileWhatsAppBot)
    into(layout.buildDirectory.dir("generated/bliss-node-assets/nodejs"))
    from(botProject.resolve("package.json"))
    from(botProject.resolve("dist")) {
        into("dist")
        exclude("**/*.d.ts", "**/*.js.map")
    }
    from(botProject.resolve("src/plugin-store")) {
        into("plugin-store")
        include("**/manifest.json")
    }
    from(botProject.resolve("node_modules")) {
        into("node_modules")
        // Runtime does not invoke the TypeScript toolchain or optional media codecs.
        exclude(".bin/**", "@types/**", "@esbuild/**", "esbuild/**", "tsx/**", "typescript/**")
        exclude("@img/**", "sharp/**")
        exclude("**/*.map", "**/*.d.ts", "**/*.d.ts.map", "**/*.tsbuildinfo")
        exclude("**/__tests__/**", "**/test/**", "**/tests/**")
    }
}

android {
    namespace = "com.syacretary.bliss"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.syacretary.bliss"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    sourceSets.getByName("main").assets.srcDir(
        layout.buildDirectory.dir("generated/bliss-node-assets").get().asFile,
    )
    sourceSets.getByName("main").jniLibs.srcDir("src/main/jniLibs")

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(nodeRuntimeDownload, stageWhatsAppBot)
}

tasks.configureEach {
    if (name.startsWith("configureCMake") || name.startsWith("buildCMake")) {
        dependsOn(nodeRuntimeDownload)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
