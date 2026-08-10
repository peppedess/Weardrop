
mkdir -p .github/workflows app/src/main/java/com/weardrop/app gradle/wrapper

cat << 'EOT' > .github/workflows/build.yml
name: Build WearDrop APK
on:
  push:
    branches: [ main, master ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3
      - name: Build Debug APK
        run: ./gradlew assembleDebug
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: WearDrop-debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk
EOT

cat << 'EOT' > settings.gradle.kts
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "WearDrop"
include(":app")
EOT

cat << 'EOT' > build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
EOT

cat << 'EOT' > gradle/libs.versions.toml
[versions]
agp = "8.7.3"
kotlin = "2.0.21"
activityCompose = "1.9.3"
composeBom = "2024.10.01"

[libraries]
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
androidx-ui = { group = "androidx.compose.ui", name = "ui" }
androidx-material3 = { group = "androidx.compose.material3", name = "material3" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
EOT

cat << 'EOT' > app/build.gradle.kts
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
        versionCode = 1
        versionName = "1.0"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.activity.compose)
    implementation("com.mobile-native-foundation.dadb:dadb:1.2.6")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
EOT

cat << 'EOT' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <application
        android:allowBackup="true"
        android:label="WearDrop"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOT

cat << 'EOT' > app/src/main/java/com/weardrop/app/AdbInstaller.kt
package com.weardrop.app

import android.content.Context
import android.net.Uri
import dev.mobile.dadb.Dadb
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

class AdbInstaller(private val context: Context) {
    suspend fun installApk(ip: String, port: Int, apkUri: Uri, onStatusUpdate: (String) -> Unit): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                onStatusUpdate("Lettura APK...")
                val tempFile = createTempApkFile(apkUri) ?: throw Exception("Impossibile accedere all'APK")
                onStatusUpdate("Connessione a $ip:$port...")
                Dadb.create(ip, port).use { dadb ->
                    onStatusUpdate("Installazione su Wear OS...")
                    dadb.install(tempFile)
                    tempFile.delete()
                    onStatusUpdate("Installato con successo!")
                    true
                }
            } catch (e: Exception) {
                onStatusUpdate("Errore: ${e.localizedMessage}")
                false
            }
        }
    }

    private fun createTempApkFile(uri: Uri): File? {
        return try {
            val inputStream = context.contentResolver.openInputStream(uri) ?: return null
            val tempFile = File.createTempFile("wear_drop_", ".apk", context.cacheDir)
            val outputStream = FileOutputStream(tempFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            tempFile
        } catch (e: Exception) { null }
    }
}
EOT

cat << 'EOT' > app/src/main/java/com/weardrop/app/MainActivity.kt
package com.weardrop.app

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme { Surface(modifier = Modifier.fillMaxSize()) { WearDropScreen() } }
        }
    }
}

@Composable
fun WearDropScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var ipAddress by remember { mutableStateOf("") }
    var portText by remember { mutableStateOf("5555") }
    var selectedApkUri by remember { mutableStateOf<Uri?>(null) }
    var statusMessage by remember { mutableStateOf("Inserisci IP e scegli un APK") }
    var isInstalling by remember { mutableStateOf(false) }

    val filePickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { selectedApkUri = it; statusMessage = "APK pronto" }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("WearDrop", style = MaterialTheme.typography.headlineMedium)
        OutlinedTextField(value = ipAddress, onValueChange = { ipAddress = it }, label = { Text("IP Wear OS") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = portText, onValueChange = { portText = it }, label = { Text("Porta ADB") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = { filePickerLauncher.launch("application/vnd.android.package-archive") }, modifier = Modifier.fillMaxWidth(), enabled = !isInstalling) {
            Text(if (selectedApkUri == null) "Seleziona APK" else "Cambia APK")
        }
        Button(
            onClick = {
                val uri = selectedApkUri
                val port = portText.toIntOrNull()
                if (uri != null && port != null && ipAddress.isNotBlank()) {
                    isInstalling = true
                    scope.launch {
                        AdbInstaller(context).installApk(ipAddress, port, uri) { statusMessage = it }
                        isInstalling = false
                    }
                } else { statusMessage = "Compila tutti i campi" }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = selectedApkUri != null && !isInstalling
        ) {
            if (isInstalling) CircularProgressIndicator(modifier = Modifier.size(24.dp)) else Text("Installa su Wear OS")
        }
        Card(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text(statusMessage, modifier = Modifier.padding(16.dp)) }
    }
}
EOT

cat << 'EOT' > gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOT

curl -sL https://github.com/gradle/gradle/raw/master/gradlew -o gradlew
curl -sL https://github.com/gradle/gradle/raw/master/gradle/wrapper/gradle-wrapper.jar -o gradle/wrapper/gradle-wrapper.jar
chmod +x gradlew
