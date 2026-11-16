plugins {
    id("com.android.library")
}

val pluginName = "InAppUpdatePlugin"
val pluginPackageName = "com.arrowescape.inappupdate"

android {
    namespace = pluginPackageName
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Godot's own Android library (supplied by the exported app at runtime).
    compileOnly("org.godotengine:godot:4.7.2.stable")
    // Google Play in-app updates. At runtime this comes from the export plugin's
    // _get_android_dependencies() (addons/InAppUpdatePlugin/export_plugin.gd).
    compileOnly("com.google.android.play:app-update:2.1.0")
}

// ./gradlew assembleDebug assembleRelease  ->  copies the AARs + export scripts into ../../addons
tasks.register<Copy>("installAddon") {
    dependsOn("assembleDebug", "assembleRelease")
    from("build/outputs/aar/plugin-debug.aar") {
        rename { "$pluginName-debug.aar" }
        into("bin/debug")
    }
    from("build/outputs/aar/plugin-release.aar") {
        rename { "$pluginName-release.aar" }
        into("bin/release")
    }
    from("../export_scripts")
    into("../../../addons/$pluginName")
}
