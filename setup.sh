#!/usr/bin/env bash
# =============================================================================
#  WearDrop - generatore progetto completo
#  Installa APK su smartwatch Wear OS via Wireless ADB (dev.mobile:dadb)
#
#  Uso:  ./setup.sh            -> genera nella cartella corrente (consigliato)
#        ./setup.sh WearDrop   -> genera nella sottocartella WearDrop
# =============================================================================
set -euo pipefail

TARGET="${1:-.}"
PKG_DIR="app/src/main/java/com/peppedess/weardrop"

echo "==> WearDrop :: generazione progetto in '${TARGET}'"
mkdir -p "${TARGET}"
cd "${TARGET}"

# ------------------------------------------------------------------ struttura
mkdir -p .github/workflows
mkdir -p gradle/wrapper
mkdir -p "${PKG_DIR}"
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/values-night
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-anydpi-v26

# ============================================================================
#  settings.gradle.kts
# ============================================================================
cat << 'EOF' > settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "WearDrop"
include(":app")
EOF

# ============================================================================
#  build.gradle.kts (root)
# ============================================================================
cat << 'EOF' > build.gradle.kts
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
EOF

# ============================================================================
#  gradle.properties
# ============================================================================
cat << 'EOF' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=false

android.useAndroidX=true
android.nonTransitiveRClass=true
android.enableJetifier=false

kotlin.code.style=official
EOF

# ============================================================================
#  gradle/wrapper/gradle-wrapper.properties
# ============================================================================
cat << 'EOF' > gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.9-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

# ============================================================================
#  app/build.gradle.kts
# ============================================================================
cat << 'EOF' > app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.peppedess.weardrop"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.peppedess.weardrop"
        minSdk = 26
        targetSdk = 35

        val runNumber = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionCode = runNumber
        versionName = "1.0.$runNumber"

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

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    // -------------------------------------------------------------------
    //  FONDAMENTALE: DADB e le sue dipendenze transitive portano diversi
    //  file duplicati in META-INF che fanno fallire :app:mergeDebugJavaResource
    // -------------------------------------------------------------------
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE*"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/LICENSE.md"
            excludes += "META-INF/LICENSE-notice.md"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE*"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/NOTICE.md"
            excludes += "META-INF/*.version"
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/INDEX.LIST"
            excludes += "META-INF/io.netty.versions.properties"
            excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.3")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // Engine ADB puro Kotlin/JVM - disponibile su Maven Central
    implementation("dev.mobile:dadb:1.2.6")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
EOF

# ============================================================================
#  app/proguard-rules.pro
# ============================================================================
cat << 'EOF' > app/proguard-rules.pro
# Regole R8 per WearDrop
-keep class dadb.** { *; }
-dontwarn dadb.**
-dontwarn org.slf4j.**
-dontwarn javax.annotation.**
EOF

# ============================================================================
#  AndroidManifest.xml
# ============================================================================
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

    <application
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.WearDrop">

        <activity
            android:name=".MainActivity"
            android:configChanges="orientation|screenSize|screenLayout|keyboardHidden|uiMode"
            android:exported="true"
            android:label="@string/app_name"
            android:theme="@style/Theme.WearDrop"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

# ============================================================================
#  res/values/strings.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">WearDrop</string>
</resources>
EOF

# ============================================================================
#  res/values/colors.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/values/colors.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B3D5C</color>
    <color name="window_background">#FBFCFE</color>
</resources>
EOF

# ============================================================================
#  res/values-night/colors.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/values-night/colors.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B3D5C</color>
    <color name="window_background">#101418</color>
</resources>
EOF

# ============================================================================
#  res/values/themes.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/values/themes.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.WearDrop" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">@color/window_background</item>
        <item name="android:statusBarColor">@color/window_background</item>
        <item name="android:navigationBarColor">@color/window_background</item>
        <item name="android:windowLightStatusBar">true</item>
    </style>
</resources>
EOF

# ============================================================================
#  res/values-night/themes.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/values-night/themes.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.WearDrop" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@color/window_background</item>
        <item name="android:statusBarColor">@color/window_background</item>
        <item name="android:navigationBarColor">@color/window_background</item>
        <item name="android:windowLightStatusBar">false</item>
    </style>
</resources>
EOF

# ============================================================================
#  res/drawable/ic_launcher_foreground.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/drawable/ic_launcher_foreground.xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">

    <path
        android:fillColor="#FFFFFF"
        android:pathData="M50,26 L58,26 L58,48 L70,48 L54,68 L38,48 L50,48 Z" />

    <path
        android:fillColor="#FFFFFF"
        android:pathData="M38,74 L70,74 L70,82 L38,82 Z" />

</vector>
EOF

# ============================================================================
#  mipmap-anydpi-v26/ic_launcher.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
EOF

# ============================================================================
#  mipmap-anydpi-v26/ic_launcher_round.xml
# ============================================================================
cat << 'EOF' > app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
EOF

# ============================================================================
#  Theme.kt
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/Theme.kt
package com.peppedess.weardrop

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = Color(0xFF00658B),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFC5E7FF),
    onPrimaryContainer = Color(0xFF001E2C),
    secondary = Color(0xFF4E616D),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFD1E5F4),
    onSecondaryContainer = Color(0xFF091E28),
    error = Color(0xFFBA1A1A),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFFBFCFE),
    onBackground = Color(0xFF191C1E),
    surface = Color(0xFFFBFCFE),
    onSurface = Color(0xFF191C1E),
    surfaceVariant = Color(0xFFDCE3E9),
    onSurfaceVariant = Color(0xFF40484C),
    outline = Color(0xFF70787D)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF7FD0FF),
    onPrimary = Color(0xFF003549),
    primaryContainer = Color(0xFF004C69),
    onPrimaryContainer = Color(0xFFC5E7FF),
    secondary = Color(0xFFB5C9D7),
    onSecondary = Color(0xFF20333E),
    secondaryContainer = Color(0xFF364955),
    onSecondaryContainer = Color(0xFFD1E5F4),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF101418),
    onBackground = Color(0xFFE1E2E5),
    surface = Color(0xFF101418),
    onSurface = Color(0xFFE1E2E5),
    surfaceVariant = Color(0xFF40484C),
    onSurfaceVariant = Color(0xFFC0C8CD),
    outline = Color(0xFF8A9297)
)

@Composable
fun WearDropTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val ctx = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
EOF

# ============================================================================
#  AdbInstaller.kt
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/AdbInstaller.kt
package com.peppedess.weardrop

import android.content.Context
import android.net.Uri
import dadb.AdbKeyPair
import dadb.Dadb
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * Esito di una operazione ADB.
 */
sealed interface AdbOutcome {
    data class Ok(val message: String) : AdbOutcome
    data class Error(val message: String) : AdbOutcome
}

/**
 * Helper che gestisce l'intero ciclo:
 *  1. copia dell'APK selezionato (content:// Uri) in un file temporaneo di cache
 *  2. apertura del socket ADB verso lo smartwatch tramite Dadb.create(ip, port)
 *  3. esecuzione di dadb.install(tempFile)
 *
 * Tutto viene eseguito su Dispatchers.IO; i log vengono riportati sul Main.
 */
class AdbInstaller(private val context: Context) {

    // ---------------------------------------------------------------- public

    suspend fun install(
        apkUri: Uri,
        host: String,
        port: Int,
        onLog: suspend (String) -> Unit
    ): AdbOutcome = withContext(Dispatchers.IO) {
        var temp: File? = null
        try {
            emit(onLog, "Copia del pacchetto nella cache locale...")
            val payload = copyToCache(apkUri)
            temp = payload
            emit(onLog, "Pacchetto pronto: ${formatSize(payload.length())}")

            emit(onLog, "Apertura socket ADB su $host:$port...")
            Dadb.create(host, port, keyPairOrNull()).use { dadb ->
                emit(onLog, "Handshake completato, dispositivo autorizzato.")

                val model = runCatching {
                    dadb.shell("getprop ro.product.model").output.trim()
                }.getOrNull()
                if (!model.isNullOrBlank()) {
                    emit(onLog, "Dispositivo: $model")
                }

                emit(onLog, "Trasferimento e installazione in corso...")
                dadb.install(payload)
            }

            emit(onLog, "Installazione terminata con successo.")
            AdbOutcome.Ok("APK installato sullo smartwatch")
        } catch (t: Throwable) {
            val reason = describe(t)
            emit(onLog, "ERRORE: $reason")
            AdbOutcome.Error(reason)
        } finally {
            temp?.delete()
        }
    }

    suspend fun testConnection(
        host: String,
        port: Int,
        onLog: suspend (String) -> Unit
    ): AdbOutcome = withContext(Dispatchers.IO) {
        try {
            emit(onLog, "Apertura socket ADB su $host:$port...")
            Dadb.create(host, port, keyPairOrNull()).use { dadb ->
                val model = dadb.shell("getprop ro.product.model").output.trim()
                val release = dadb.shell("getprop ro.build.version.release").output.trim()
                emit(onLog, "Connesso a: $model (Android $release)")
                AdbOutcome.Ok("Connesso a $model")
            }
        } catch (t: Throwable) {
            val reason = describe(t)
            emit(onLog, "ERRORE: $reason")
            AdbOutcome.Error(reason)
        }
    }

    // --------------------------------------------------------------- private

    private suspend fun emit(onLog: suspend (String) -> Unit, message: String) {
        withContext(Dispatchers.Main) { onLog(message) }
    }

    /**
     * La chiave RSA viene generata una sola volta e conservata nello storage
     * privato dell'app: cosi' il prompt "Consenti debug USB" appare una volta sola.
     */
    private fun keyPairOrNull(): AdbKeyPair? = try {
        val dir = File(context.filesDir, "adb").apply { mkdirs() }
        val priv = File(dir, "adbkey")
        val pub = File(dir, "adbkey.pub")
        if (!priv.exists() || !pub.exists()) {
            AdbKeyPair.generate(priv, pub)
        }
        AdbKeyPair.read(priv, pub)
    } catch (t: Throwable) {
        null
    }

    private fun copyToCache(uri: Uri): File {
        val dir = File(context.cacheDir, "weardrop").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }

        val target = File(dir, "payload_${System.currentTimeMillis()}.apk")
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Impossibile leggere il file selezionato")

        input.use { source ->
            FileOutputStream(target).use { sink ->
                source.copyTo(sink, DEFAULT_BUFFER)
                sink.flush()
            }
        }

        if (target.length() <= 0L) {
            target.delete()
            throw IllegalStateException("Il file selezionato risulta vuoto")
        }
        return target
    }

    private fun describe(t: Throwable): String {
        val raw = t.message?.takeIf { it.isNotBlank() } ?: t.javaClass.simpleName
        return when {
            raw.contains("ECONNREFUSED", true) ->
                "Connessione rifiutata: verifica che il debug wireless sia attivo sull'orologio"
            raw.contains("ETIMEDOUT", true) || raw.contains("timeout", true) ->
                "Timeout: orologio non raggiungibile su questa rete Wi-Fi"
            raw.contains("EHOSTUNREACH", true) || raw.contains("ENETUNREACH", true) ->
                "Host non raggiungibile: telefono e orologio devono stare sulla stessa rete"
            raw.contains("device unauthorized", true) || raw.contains("auth", true) ->
                "Autorizzazione negata: accetta il prompt di debug sull'orologio e riprova"
            raw.contains("INSTALL_FAILED_VERSION_DOWNGRADE", true) ->
                "Installazione rifiutata: versione piu' vecchia di quella gia' presente"
            raw.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE", true) ->
                "Firma incompatibile: disinstalla prima la versione presente sull'orologio"
            raw.contains("INSTALL_FAILED_NO_MATCHING_ABIS", true) ->
                "ABI non compatibile con il processore dell'orologio"
            else -> raw
        }
    }

    private fun formatSize(bytes: Long): String = when {
        bytes >= 1024L * 1024L -> String.format("%.1f MB", bytes / (1024.0 * 1024.0))
        bytes >= 1024L -> String.format("%.0f KB", bytes / 1024.0)
        else -> "$bytes B"
    }

    private companion object {
        const val DEFAULT_BUFFER = 64 * 1024
    }
}
EOF

# ============================================================================
#  MainActivity.kt
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/MainActivity.kt
package com.peppedess.weardrop

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            WearDropTheme {
                WearDropScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WearDropScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val prefs = remember { context.getSharedPreferences("weardrop_prefs", Context.MODE_PRIVATE) }
    val installer = remember { AdbInstaller(context.applicationContext) }

    var host by rememberSaveable { mutableStateOf(prefs.getString("host", "") ?: "") }
    var port by rememberSaveable { mutableStateOf(prefs.getString("port", "5555") ?: "5555") }
    var apkUri by rememberSaveable { mutableStateOf<Uri?>(null) }
    var apkName by rememberSaveable { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var outcome by remember { mutableStateOf<AdbOutcome?>(null) }
    val logs = remember { mutableStateListOf<String>() }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) {
            apkUri = uri
            apkName = displayNameOf(context, uri)
            outcome = null
            logs.clear()
        }
    }

    val portNumber = port.trim().toIntOrNull()
    val hostOk = host.trim().isNotEmpty()
    val portOk = portNumber != null && portNumber in 1..65535
    val canConnect = !busy && hostOk && portOk
    val canInstall = canConnect && apkUri != null

    fun saveTarget() {
        prefs.edit()
            .putString("host", host.trim())
            .putString("port", port.trim())
            .apply()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("WearDrop", fontWeight = FontWeight.SemiBold)
                        Text(
                            "Sideload APK su Wear OS",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {

            // ---------------------------------------------------- 1. Target
            SectionCard(title = "1 - Smartwatch di destinazione") {
                OutlinedTextField(
                    value = host,
                    onValueChange = { host = it.trim() },
                    label = { Text("Indirizzo IP Wear OS") },
                    placeholder = { Text("192.168.1.42") },
                    singleLine = true,
                    isError = host.isNotEmpty() && !hostOk,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))

                OutlinedTextField(
                    value = port,
                    onValueChange = { value -> port = value.filter { it.isDigit() }.take(5) },
                    label = { Text("Porta ADB") },
                    singleLine = true,
                    isError = port.isNotEmpty() && !portOk,
                    supportingText = { Text("5555 = debug Wi-Fi classico | 37xxx = wireless debugging") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { port = "5555" },
                        enabled = !busy,
                        modifier = Modifier.weight(1f)
                    ) { Text("5555") }

                    OutlinedButton(
                        onClick = { port = "37221" },
                        enabled = !busy,
                        modifier = Modifier.weight(1f)
                    ) { Text("37221") }
                }

                Spacer(Modifier.height(10.dp))

                OutlinedButton(
                    onClick = {
                        saveTarget()
                        scope.launch {
                            busy = true
                            outcome = null
                            logs.clear()
                            outcome = installer.testConnection(
                                host = host.trim(),
                                port = portNumber ?: 5555
                            ) { logs.add(it) }
                            busy = false
                        }
                    },
                    enabled = canConnect,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Test connessione")
                }
            }

            // ------------------------------------------------------ 2. APK
            SectionCard(title = "2 - Pacchetto APK") {
                OutlinedButton(
                    onClick = { picker.launch("*/*") },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Filled.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (apkUri == null) "Seleziona file APK" else "Cambia file APK")
                }

                if (apkUri != null) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        text = apkName.ifBlank { "pacchetto selezionato" },
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium
                    )
                    if (!apkName.endsWith(".apk", ignoreCase = true)) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "Attenzione: l'estensione non sembra .apk",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }

            // -------------------------------------------------- 3. Install
            Button(
                onClick = {
                    val uri = apkUri ?: return@Button
                    saveTarget()
                    scope.launch {
                        busy = true
                        outcome = null
                        logs.clear()
                        outcome = installer.install(
                            apkUri = uri,
                            host = host.trim(),
                            port = portNumber ?: 5555
                        ) { logs.add(it) }
                        busy = false
                    }
                },
                enabled = canInstall,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
            ) {
                if (busy) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Spacer(Modifier.width(12.dp))
                    Text("Operazione in corso...")
                } else {
                    Icon(Icons.Filled.PlayArrow, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Installa sullo smartwatch")
                }
            }

            // ----------------------------------------------------- 4. Stato
            if (logs.isNotEmpty() || outcome != null) {
                SectionCard(title = "Stato operazione") {
                    val current = outcome
                    if (current != null) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            when (current) {
                                is AdbOutcome.Ok -> {
                                    Icon(
                                        Icons.Filled.CheckCircle,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        current.message,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                                is AdbOutcome.Error -> {
                                    Icon(
                                        Icons.Filled.Warning,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.error,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        current.message,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.error
                                    )
                                }
                            }
                        }
                        Spacer(Modifier.height(10.dp))
                        HorizontalDivider()
                        Spacer(Modifier.height(10.dp))
                    }

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 220.dp)
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        logs.forEach { line ->
                            Text(
                                text = "> $line",
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            // ------------------------------------------------------ 5. Guida
            SectionCard(title = "Come preparare l'orologio") {
                Row(verticalAlignment = Alignment.Top) {
                    Icon(
                        Icons.Filled.Info,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = HELP_TEXT,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SectionCard(
    title: String,
    content: @Composable () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(Modifier.height(12.dp))
            content()
        }
    }
}

private const val HELP_TEXT =
    "1. Sull'orologio apri Impostazioni > Sistema > Informazioni e tocca 7 volte " +
    "\"Numero build\" per sbloccare le Opzioni sviluppatore.\n\n" +
    "2. In Opzioni sviluppatore attiva \"Debug ADB\" e \"Debug via Wi-Fi\": " +
    "sotto la voce comparira' l'indirizzo IP e la porta da inserire qui sopra.\n\n" +
    "3. Telefono e orologio devono essere sulla stessa rete Wi-Fi.\n\n" +
    "4. Alla prima connessione l'orologio mostra un prompt di autorizzazione: " +
    "accettalo (spunta \"Consenti sempre\") e ripeti l'operazione."

private fun displayNameOf(context: Context, uri: Uri): String {
    var name = uri.lastPathSegment ?: "package.apk"
    runCatching {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                val value = cursor.getString(index)
                if (!value.isNullOrBlank()) name = value
            }
        }
    }
    return name
}
EOF

# ============================================================================
#  .github/workflows/build.yml
# ============================================================================
cat << 'EOF' > .github/workflows/build.yml
name: Build WearDrop

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build:
    name: Build Debug APK
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 17 (Temurin)
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Setup Gradle 8.9
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.9'

      - name: Rigenera il Gradle Wrapper
        run: gradle wrapper --gradle-version 8.9 --distribution-type bin

      - name: Permessi esecuzione gradlew
        run: chmod +x ./gradlew

      - name: Build assembleDebug
        run: ./gradlew assembleDebug --stacktrace

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: WearDrop-debug-${{ github.run_number }}
          path: app/build/outputs/apk/debug/app-debug.apk
          if-no-files-found: error
          retention-days: 30
EOF

# ============================================================================
#  .gitignore
# ============================================================================
cat << 'EOF' > .gitignore
*.iml
.gradle/
local.properties
.idea/
.DS_Store
build/
captures/
.externalNativeBuild/
.cxx/
*.apk
*.aab
*.keystore
!gradle/wrapper/gradle-wrapper.jar
EOF

# ============================================================================
#  README.md
# ============================================================================
cat << 'EOF' > README.md
# WearDrop

Installa file APK su smartwatch **Wear OS** direttamente dal telefono, via
**Wireless ADB**, senza PC.

## Stack

| Componente | Versione |
|---|---|
| JDK | 17 |
| Gradle Wrapper | 8.9 (bin) |
| Android Gradle Plugin | 8.7.3 |
| Kotlin | 2.0.21 (+ plugin Compose) |
| compileSdk / targetSdk | 35 |
| minSdk | 26 |
| Compose BOM | 2024.10.01 |
| Engine ADB | `dev.mobile:dadb:1.2.6` (Maven Central) |

## Come si usa

1. Sull'orologio: Impostazioni > Sistema > Informazioni > 7 tap su "Numero build".
2. Opzioni sviluppatore > attiva **Debug ADB** e **Debug via Wi-Fi**.
3. Annota IP e porta mostrati (di norma `5555`).
4. In WearDrop inserisci IP e porta, premi **Test connessione**.
5. Accetta il prompt di autorizzazione che compare sull'orologio.
6. Seleziona l'APK e premi **Installa sullo smartwatch**.

Telefono e orologio devono essere sulla stessa rete Wi-Fi.

## Build

La pipeline GitHub Actions compila la variante debug e pubblica
`app-debug.apk` come artifact.
EOF

# ============================================================================
#  Gradle Wrapper: download di gradlew + gradle-wrapper.jar
#  (in CI viene comunque rigenerato dal workflow, quindi un fallimento
#   qui non e' bloccante)
# ============================================================================
GRADLE_TAG="v8.9.0"
RAW_BASE="https://raw.githubusercontent.com/gradle/gradle/${GRADLE_TAG}"
WRAPPER_OK=1

echo "==> Download Gradle Wrapper (${GRADLE_TAG})..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${RAW_BASE}/gradle/wrapper/gradle-wrapper.jar" -o gradle/wrapper/gradle-wrapper.jar || WRAPPER_OK=0
    curl -fsSL "${RAW_BASE}/gradlew"     -o gradlew     || WRAPPER_OK=0
    curl -fsSL "${RAW_BASE}/gradlew.bat" -o gradlew.bat || WRAPPER_OK=0
elif command -v wget >/dev/null 2>&1; then
    wget -q "${RAW_BASE}/gradle/wrapper/gradle-wrapper.jar" -O gradle/wrapper/gradle-wrapper.jar || WRAPPER_OK=0
    wget -q "${RAW_BASE}/gradlew"     -O gradlew     || WRAPPER_OK=0
    wget -q "${RAW_BASE}/gradlew.bat" -O gradlew.bat || WRAPPER_OK=0
else
    WRAPPER_OK=0
fi

if [ "${WRAPPER_OK}" -eq 1 ] && [ -s gradle/wrapper/gradle-wrapper.jar ]; then
    chmod +x gradlew
    echo "    Wrapper scaricato correttamente."
else
    rm -f gradle/wrapper/gradle-wrapper.jar gradlew gradlew.bat
    echo "    ATTENZIONE: download wrapper non riuscito (rete assente?)."
    echo "    Nessun problema: il workflow GitHub Actions lo rigenera da solo."
fi

# ============================================================================
#  Riepilogo
# ============================================================================
echo ""
echo "==> Progetto WearDrop generato."
echo ""
find . -type f \
    -not -path "./.git/*" \
    -not -path "./build/*" \
    -not -path "./app/build/*" \
    -not -path "./.gradle/*" | sort
echo ""
echo "==> Prossimo passo: commit + push, poi controlla la tab Actions."
