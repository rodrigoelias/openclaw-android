import java.util.Properties

plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.kotlinAndroid)
    alias(libs.plugins.detekt)
    alias(libs.plugins.ktlint)
}

android {
    namespace = "com.openclaw.android"
    compileSdk = 36

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    defaultConfig {
        applicationId = "com.openclaw.android"
        minSdk = 24
        //noinspection ExpiredTargetSdkVersion
        targetSdk = 28
        versionCode = 7
        versionName = "0.3.5"

        ndk { abiFilters += listOf("arm64-v8a") }

        // Download URLs (§2.9) — BuildConfig hardcoded fallbacks
        // Override via config.json hosted at CONFIG_URL (see UrlResolver)
        buildConfigField(
            "String", "BOOTSTRAP_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/bootstrap-aarch64.zip\""
        )
        buildConfigField(
            "String", "WWW_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/www.zip\""
        )
        buildConfigField(
            "String", "CONFIG_URL",
            "\"https://raw.githubusercontent.com/rodrigoelias/openclaw-android/main/config.json\""
        )

        // Dependency URLs — used by post-setup.sh via deps-urls.env
        buildConfigField(
            "String", "DEPS_NODE_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/node-v22.22.0-linux-arm64.tar.xz\""
        )
        buildConfigField(
            "String", "DEPS_GLIBC_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/glibc-2.42-0-aarch64.pkg.tar.xz\""
        )
        buildConfigField(
            "String", "DEPS_GCC_LIBS_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/gcc-libs-glibc-14.2.1-1-aarch64.pkg.tar.xz\""
        )
        buildConfigField(
            "String", "DEPS_LIBEXPAT_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/libexpat_2.7.1-1_aarch64.deb\""
        )
        buildConfigField(
            "String", "DEPS_PCRE2_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/pcre2_10.45-1_aarch64.deb\""
        )
        buildConfigField(
            "String", "DEPS_GIT_URL",
            "\"https://github.com/rodrigoelias/openclaw-android/releases/download/deps-v1/git_2.49.0_aarch64.deb\""
        )
    }

    signingConfigs {
        create("release") {
            val props = project.rootProject.file("local.properties")
            if (props.exists()) {
                val localProps = Properties().apply { props.inputStream().use { load(it) } }
                storeFile = file(localProps.getProperty("RELEASE_STORE_FILE", ""))
                storePassword = localProps.getProperty("RELEASE_STORE_PASSWORD", "")
                keyAlias = localProps.getProperty("RELEASE_KEY_ALIAS", "")
                keyPassword = localProps.getProperty("RELEASE_KEY_PASSWORD", "")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-DEBUG"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    packaging {
        jniLibs { useLegacyPackaging = true }
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}

dependencies {
    implementation(project(":terminal-emulator"))
    implementation(project(":terminal-view"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.gson)
    // WebView + @JavascriptInterface — Android SDK built-in, no extra dependency
}


// --- www build automation ---
// Builds the React UI (android/www) and copies dist/ into assets/www before every APK build.
val wwwProjectDir = file("${rootDir}/www")
val assetsWwwDir = file("${projectDir}/src/main/assets/www")

val buildWww by tasks.registering(Exec::class) {
    description = "Build React UI (npm run build)"
    group = "build"
    workingDir = wwwProjectDir
    commandLine("npm", "run", "build")
    inputs.dir(wwwProjectDir.resolve("src"))
    inputs.files(
        wwwProjectDir.resolve("package.json"),
        wwwProjectDir.resolve("tsconfig.json"),
        wwwProjectDir.resolve("vite.config.ts")
    )
    outputs.dir(wwwProjectDir.resolve("dist"))
}

val syncWwwAssets by tasks.registering(Sync::class) {
    description = "Copy React dist/ into assets/www/"
    group = "build"
    dependsOn(buildWww)
    from(wwwProjectDir.resolve("dist"))
    into(assetsWwwDir)
}

tasks.named("preBuild") {
    dependsOn(syncWwwAssets)
}

detekt {
    buildUponDefaultConfig = true
    allRules = false
    config.setFrom("$rootDir/detekt.yml")
}

tasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach {
    jvmTarget = "17"
    reports {
        html.required.set(true)
        sarif.required.set(true)
        xml.required.set(false)
        txt.required.set(false)
    }
}

tasks.withType<io.gitlab.arturbosch.detekt.DetektCreateBaselineTask>().configureEach {
    jvmTarget = "17"
}

configure<org.jlleitschuh.gradle.ktlint.KtlintExtension> {
    android.set(true)
    outputToConsole.set(true)
    ignoreFailures.set(false)
    filter {
        exclude("**/generated/**")
    }
}