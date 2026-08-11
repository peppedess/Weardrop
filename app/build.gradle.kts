import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.peppedess.weardrop"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.peppedess.weardrop"
        minSdk = 26
        targetSdk = 36

        val runNumber = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionCode = runNumber
        versionName = "3.0.$runNumber"

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE*"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE*"
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/INDEX.LIST"
            excludes += "META-INF/*.version"
            excludes += "META-INF/*.SF"
            excludes += "META-INF/*.DSA"
            excludes += "META-INF/*.RSA"
            excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.12.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    implementation("androidx.activity:activity-compose:1.11.0")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")

    // ATTENZIONE: le API M3 Expressive (MaterialExpressiveTheme, LoadingIndicator,
    // LinearWavyProgressIndicator) sono pubbliche SOLO nel ramo 1.5.0-alpha.
    // La 1.4.x stabile le ha rese interne. Non alzare oltre alpha18 senza
    // verificare le release note: dalla alpha19 servono AGP 9.1 e SDK 37.
    implementation("androidx.compose.material3:material3:1.5.0-alpha12")

    // material3 1.4+ non porta piu' material-icons-core in transitivo
    implementation("androidx.compose.material:material-icons-core:1.7.8")

    // Forme poligonali morphing (stabile)
    implementation("androidx.graphics:graphics-shapes:1.0.1")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    implementation("com.github.MuntashirAkon:libadb-android:1.0.1")

    // bcprov arriva gia' come dipendenza transitiva di libadb-android
    // (jdk15on:1.69): aggiungere jdk15to18 creerebbe classi duplicate.
    implementation("org.bouncycastle:bcpkix-jdk15on:1.69")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
