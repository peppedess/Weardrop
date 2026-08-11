plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.weardrop.app"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.weardrop.app"
        minSdk = 26
        targetSdk = 35
    }
    buildFeatures { compose = true }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.3")
    // Questa è la libreria che fa l'handshake ADB al posto tuo
    implementation("com.github.mobile-native-foundation:dadb:1.2.6")
}
