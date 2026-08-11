#!/usr/bin/env bash
# =============================================================================
#  WearDrop v3 - Material 3 Expressive
#  Toolchain allineata a Treni Tracker / Viandante:
#  AGP 8.13.0, Kotlin 2.2.20, BOM 2025.12.00, material3 1.5.0-alpha12,
#  SDK 36, Gradle 8.14.3, JDK Temurin 21.
# =============================================================================
set -euo pipefail

PKG_DIR="app/src/main/java/com/peppedess/weardrop"

if [ ! -f settings.gradle.kts ]; then
    echo "ERRORE: esegui lo script dalla root del progetto WearDrop."
    exit 1
fi

echo "==> WearDrop v3 :: Material 3 Expressive"

# ============================================================================
#  gradle/wrapper/gradle-wrapper.properties
# ============================================================================
cat << 'EOF' > gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14.3-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

# ============================================================================
#  build.gradle.kts (root)
# ============================================================================
cat << 'EOF' > build.gradle.kts
plugins {
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
EOF

# ============================================================================
#  app/build.gradle.kts
# ============================================================================
cat << 'EOF' > app/build.gradle.kts
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

      - name: Set up JDK 21 (Temurin)
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Setup Gradle 8.14.3
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.14.3'

      - name: Rigenera il Gradle Wrapper
        run: gradle wrapper --gradle-version 8.14.3 --distribution-type bin

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
#  Motion.kt
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/Motion.kt
package com.peppedess.weardrop

import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VisibilityThreshold
import androidx.compose.animation.core.spring
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.IntOffset

/**
 * Vocabolario di movimento condiviso.
 *
 * Distinzione Material 3 Expressive: le molle "spatial" muovono elementi nello
 * spazio e possono rimbalzare, quelle "effects" cambiano colore/opacita' e non
 * devono mai oscillare (dampingRatio 1.0).
 *
 * NOTA: per animare un IntOffset con spring serve visibilityThreshold
 * esplicito, altrimenti non compila.
 */
object Motion {

    fun <T> spatial(): FiniteAnimationSpec<T> = spring(
        dampingRatio = 0.78f,
        stiffness = 360f
    )

    fun <T> spatialFast(): FiniteAnimationSpec<T> = spring(
        dampingRatio = 0.60f,
        stiffness = 900f
    )

    fun <T> effects(): FiniteAnimationSpec<T> = spring(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = 420f
    )

    fun offset(): FiniteAnimationSpec<IntOffset> = spring(
        dampingRatio = 0.80f,
        stiffness = 340f,
        visibilityThreshold = IntOffset.VisibilityThreshold
    )
}

/**
 * Compressione elastica alla pressione.
 */
@Composable
fun Modifier.pressBounce(interactionSource: MutableInteractionSource): Modifier {
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.965f else 1f,
        animationSpec = Motion.spatialFast(),
        label = "pressBounce"
    )
    return this.graphicsLayer {
        scaleX = scale
        scaleY = scale
    }
}
EOF

# ============================================================================
#  Theme.kt
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/Theme.kt
package com.peppedess.weardrop

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
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
    tertiary = Color(0xFF615A7C),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFE7DEFF),
    onTertiaryContainer = Color(0xFF1D1736),
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
    outline = Color(0xFF70787D),
    outlineVariant = Color(0xFFC0C8CD)
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
    tertiary = Color(0xFFCBC1E9),
    onTertiary = Color(0xFF322C4C),
    tertiaryContainer = Color(0xFF484264),
    onTertiaryContainer = Color(0xFFE7DEFF),
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
    outline = Color(0xFF8A9297),
    outlineVariant = Color(0xFF40484C)
)

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
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

    MaterialExpressiveTheme(
        colorScheme = colorScheme,
        motionScheme = MotionScheme.expressive(),
        content = content
    )
}
EOF

# ============================================================================
#  AdbInstaller.kt  (aggiunto solo il callback di progresso)
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/AdbInstaller.kt
package com.peppedess.weardrop

import android.content.Context
import android.net.Uri
import io.github.muntashirakon.adb.AdbStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

sealed interface AdbOutcome {
    data class Ok(val message: String) : AdbOutcome
    data class Error(val message: String) : AdbOutcome
}

/**
 * Gestisce abbinamento, connessione e installazione.
 *
 * L'installazione usa il servizio "exec:" con "cmd package install -S <size>":
 * e' lo stesso meccanismo dello streamed install di adb. Indicando la
 * dimensione esatta, il package manager sa quando smettere di leggere e non
 * serve chiudere lo stdin dello stream.
 */
class AdbInstaller(private val context: Context) {

    // ---------------------------------------------------------------- public

    suspend fun pair(
        host: String,
        pairingPort: Int,
        pairingCode: String,
        onLog: suspend (String) -> Unit
    ): AdbOutcome = withContext(Dispatchers.IO) {
        try {
            emit(onLog, "Abbinamento con $host:$pairingPort")
            val manager = WearDropAdbManager.getInstance(context)
            val paired = manager.pair(host, pairingPort, pairingCode)
            if (paired) {
                emit(onLog, "Abbinamento riuscito")
                AdbOutcome.Ok("Orologio abbinato")
            } else {
                emit(onLog, "Abbinamento rifiutato")
                AdbOutcome.Error("Codice errato o dialog chiuso sull'orologio")
            }
        } catch (t: Throwable) {
            val reason = describe(t)
            emit(onLog, "ERRORE: $reason")
            AdbOutcome.Error(reason)
        }
    }

    suspend fun testConnection(
        host: String,
        port: Int,
        onLog: suspend (String) -> Unit
    ): AdbOutcome = withContext(Dispatchers.IO) {
        try {
            val manager = connect(host, port, onLog)
            val model = runShell(manager, "getprop ro.product.model").trim()
            val release = runShell(manager, "getprop ro.build.version.release").trim()
            emit(onLog, "Connesso a $model (Android $release)")
            AdbOutcome.Ok("Connesso a $model")
        } catch (t: Throwable) {
            val reason = describe(t)
            emit(onLog, "ERRORE: $reason")
            AdbOutcome.Error(reason)
        }
    }

    suspend fun install(
        apkUri: Uri,
        host: String,
        port: Int,
        onLog: suspend (String) -> Unit,
        onProgress: suspend (Float) -> Unit
    ): AdbOutcome = withContext(Dispatchers.IO) {
        var temp: File? = null
        try {
            emit(onLog, "Copia del pacchetto nella cache locale")
            val payload = copyToCache(apkUri)
            temp = payload
            emit(onLog, "Pacchetto pronto: ${formatSize(payload.length())}")

            val manager = connect(host, port, onLog)
            val response = streamInstall(manager, payload, onLog, onProgress)

            if (response.contains("Success", ignoreCase = true)) {
                emit(onLog, "Installazione completata")
                AdbOutcome.Ok("APK installato sullo smartwatch")
            } else {
                val clean = response.trim().ifBlank { "nessuna risposta dal package manager" }
                emit(onLog, "Rifiutato: $clean")
                AdbOutcome.Error(describeInstall(clean))
            }
        } catch (t: Throwable) {
            val reason = describe(t)
            emit(onLog, "ERRORE: $reason")
            AdbOutcome.Error(reason)
        } finally {
            temp?.delete()
        }
    }

    // --------------------------------------------------------------- private

    private suspend fun connect(
        host: String,
        port: Int,
        onLog: suspend (String) -> Unit
    ): WearDropAdbManager {
        val manager = WearDropAdbManager.getInstance(context)
        if (!manager.isConnected) {
            emit(onLog, "Connessione a $host:$port")
            if (!manager.connect(host, port)) {
                throw IllegalStateException("Connessione rifiutata dal daemon ADB")
            }
            emit(onLog, "Canale TLS stabilito")
        }
        return manager
    }

    private fun runShell(manager: WearDropAdbManager, command: String): String {
        val stream: AdbStream = manager.openStream("shell:$command")
        try {
            return stream.openInputStream().bufferedReader().readText()
        } finally {
            runCatching { stream.close() }
        }
    }

    private suspend fun streamInstall(
        manager: WearDropAdbManager,
        apk: File,
        onLog: suspend (String) -> Unit,
        onProgress: suspend (Float) -> Unit
    ): String {
        val size = apk.length()
        emit(onLog, "Avvio streamed install")

        val stream: AdbStream = manager.openStream("exec:cmd package install -r -t -S $size")
        try {
            val output = stream.openOutputStream()
            var sent = 0L

            apk.inputStream().use { source ->
                val buffer = ByteArray(CHUNK)
                while (true) {
                    val read = source.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                    sent += read
                    progress(onProgress, sent.toFloat() / size.toFloat())
                }
            }
            output.flush()
            progress(onProgress, 1f)
            emit(onLog, "Trasferimento completato, attendo il package manager")

            return stream.openInputStream().bufferedReader().readText()
        } finally {
            runCatching { stream.close() }
        }
    }

    private suspend fun emit(onLog: suspend (String) -> Unit, message: String) {
        withContext(Dispatchers.Main) { onLog(message) }
    }

    private suspend fun progress(onProgress: suspend (Float) -> Unit, value: Float) {
        withContext(Dispatchers.Main) { onProgress(value.coerceIn(0f, 1f)) }
    }

    private fun copyToCache(uri: Uri): File {
        val dir = File(context.cacheDir, "weardrop").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }

        val target = File(dir, "payload_${System.currentTimeMillis()}.apk")
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Impossibile leggere il file selezionato")

        input.use { source ->
            FileOutputStream(target).use { sink ->
                source.copyTo(sink, CHUNK)
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
                "Porta chiusa: la porta di connessione e' diversa da quella del pairing"
            raw.contains("ETIMEDOUT", true) || raw.contains("timeout", true) ->
                "Timeout: orologio non raggiungibile su questa rete"
            raw.contains("EHOSTUNREACH", true) || raw.contains("ENETUNREACH", true) ->
                "Host non raggiungibile: stessa rete Wi-Fi per telefono e orologio"
            raw.contains("PairingRequired", true) || raw.contains("pairing", true) ->
                "Abbinamento mancante o scaduto: rifai il pairing"
            raw.contains("AuthenticationFailed", true) ->
                "Autenticazione rifiutata dal daemon ADB"
            else -> raw
        }
    }

    private fun describeInstall(raw: String): String = when {
        raw.contains("INSTALL_FAILED_VERSION_DOWNGRADE", true) ->
            "Versione piu' vecchia di quella gia' installata"
        raw.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE", true) ->
            "Firma incompatibile: disinstalla prima la versione presente"
        raw.contains("INSTALL_FAILED_NO_MATCHING_ABIS", true) ->
            "ABI non compatibile con il processore dell'orologio"
        raw.contains("INSTALL_FAILED_INSUFFICIENT_STORAGE", true) ->
            "Spazio insufficiente sull'orologio"
        raw.contains("INSTALL_PARSE_FAILED", true) ->
            "APK non valido o corrotto"
        else -> raw.take(160)
    }

    private fun formatSize(bytes: Long): String = when {
        bytes >= 1024L * 1024L -> String.format("%.1f MB", bytes / (1024.0 * 1024.0))
        bytes >= 1024L -> String.format("%.0f KB", bytes / 1024.0)
        else -> "$bytes B"
    }

    private companion object {
        const val CHUNK = 64 * 1024
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
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearWavyProgressIndicator
import androidx.compose.material3.LoadingIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
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

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun WearDropScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val prefs = remember { context.getSharedPreferences("weardrop_prefs", Context.MODE_PRIVATE) }
    val installer = remember { AdbInstaller(context.applicationContext) }

    var host by rememberSaveable { mutableStateOf(prefs.getString("host", "") ?: "") }
    var pairPort by rememberSaveable { mutableStateOf(prefs.getString("pair_port", "") ?: "") }
    var pairCode by rememberSaveable { mutableStateOf("") }
    var connPort by rememberSaveable { mutableStateOf(prefs.getString("conn_port", "") ?: "") }
    var paired by rememberSaveable { mutableStateOf(prefs.getBoolean("paired", false)) }
    var connected by remember { mutableStateOf(false) }
    var apkUri by rememberSaveable { mutableStateOf<Uri?>(null) }
    var apkName by rememberSaveable { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var transferring by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
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

    val hostOk = host.trim().isNotEmpty()
    val pairPortNumber = pairPort.trim().toIntOrNull()
    val connPortNumber = connPort.trim().toIntOrNull()
    val canPair = !busy && hostOk && pairPortNumber != null && pairCode.length == 6
    val canConnect = !busy && hostOk && connPortNumber != null
    val canInstall = canConnect && apkUri != null

    fun persist() {
        prefs.edit()
            .putString("host", host.trim())
            .putString("pair_port", pairPort.trim())
            .putString("conn_port", connPort.trim())
            .putBoolean("paired", paired)
            .apply()
    }

    fun run(block: suspend () -> AdbOutcome) {
        persist()
        scope.launch {
            busy = true
            outcome = null
            logs.clear()
            progress = 0f
            outcome = block()
            busy = false
            transferring = false
        }
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

            // ------------------------------------------------- 1. Abbinamento
            StepCard(index = 0, step = 1, title = "Abbinamento", done = paired) {
                ExpressiveField(
                    value = host,
                    onValueChange = { host = it.trim() },
                    label = "Indirizzo IP",
                    placeholder = "192.168.1.42",
                    keyboard = KeyboardType.Uri
                )

                Spacer(Modifier.height(10.dp))

                ExpressiveField(
                    value = pairPort,
                    onValueChange = { value -> pairPort = value.filter { it.isDigit() }.take(5) },
                    label = "Porta abbinamento",
                    support = "Schermata del codice a 6 cifre",
                    keyboard = KeyboardType.Number
                )

                Spacer(Modifier.height(10.dp))

                ExpressiveField(
                    value = pairCode,
                    onValueChange = { value -> pairCode = value.filter { it.isDigit() }.take(6) },
                    label = "Codice",
                    keyboard = KeyboardType.NumberPassword
                )

                Spacer(Modifier.height(14.dp))

                val pairSource = remember { MutableInteractionSource() }
                OutlinedButton(
                    onClick = {
                        run {
                            val result = installer.pair(
                                host = host.trim(),
                                pairingPort = pairPortNumber ?: 0,
                                pairingCode = pairCode
                            ) { logs.add(it) }
                            if (result is AdbOutcome.Ok) {
                                paired = true
                                pairCode = ""
                                persist()
                            }
                            result
                        }
                    },
                    enabled = canPair,
                    interactionSource = pairSource,
                    modifier = Modifier
                        .fillMaxWidth()
                        .pressBounce(pairSource)
                ) {
                    Icon(Icons.Filled.Lock, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (paired) "Riabbina" else "Abbina orologio")
                }
            }

            // -------------------------------------------------- 2. Connessione
            StepCard(index = 1, step = 2, title = "Connessione", done = connected) {
                ExpressiveField(
                    value = connPort,
                    onValueChange = { value -> connPort = value.filter { it.isDigit() }.take(5) },
                    label = "Porta connessione",
                    support = "Cambia a ogni riavvio del debug wireless",
                    keyboard = KeyboardType.Number
                )

                Spacer(Modifier.height(14.dp))

                val connSource = remember { MutableInteractionSource() }
                OutlinedButton(
                    onClick = {
                        run {
                            val result = installer.testConnection(
                                host = host.trim(),
                                port = connPortNumber ?: 0
                            ) { logs.add(it) }
                            connected = result is AdbOutcome.Ok
                            result
                        }
                    },
                    enabled = canConnect,
                    interactionSource = connSource,
                    modifier = Modifier
                        .fillMaxWidth()
                        .pressBounce(connSource)
                ) {
                    Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Test connessione")
                }
            }

            // ------------------------------------------------------ 3. APK
            StepCard(index = 2, step = 3, title = "Pacchetto", done = apkUri != null) {
                val pickSource = remember { MutableInteractionSource() }
                OutlinedButton(
                    onClick = { picker.launch("*/*") },
                    enabled = !busy,
                    interactionSource = pickSource,
                    modifier = Modifier
                        .fillMaxWidth()
                        .pressBounce(pickSource)
                ) {
                    Icon(Icons.Filled.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (apkUri == null) "Seleziona APK" else "Cambia APK")
                }

                AnimatedVisibility(visible = apkUri != null, enter = fadeIn(Motion.effects())) {
                    Column {
                        Spacer(Modifier.height(12.dp))
                        Text(
                            text = apkName.ifBlank { "pacchetto selezionato" },
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium
                        )
                        if (!apkName.endsWith(".apk", ignoreCase = true)) {
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "L'estensione non sembra .apk",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }
            }

            // -------------------------------------------------- 4. Installa
            val installSource = remember { MutableInteractionSource() }
            Button(
                onClick = {
                    val uri = apkUri ?: return@Button
                    transferring = true
                    run {
                        installer.install(
                            apkUri = uri,
                            host = host.trim(),
                            port = connPortNumber ?: 0,
                            onLog = { logs.add(it) },
                            onProgress = { progress = it }
                        )
                    }
                },
                enabled = canInstall,
                interactionSource = installSource,
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp)
                    .pressBounce(installSource)
            ) {
                if (busy) {
                    LoadingIndicator(
                        modifier = Modifier.size(26.dp),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Spacer(Modifier.width(12.dp))
                    Text("In corso")
                } else {
                    Icon(Icons.Filled.PlayArrow, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Installa sullo smartwatch", fontWeight = FontWeight.SemiBold)
                }
            }

            // Progresso reale del trasferimento
            AnimatedVisibility(
                visible = transferring && progress > 0f,
                enter = fadeIn(Motion.effects()) + slideInVertically(Motion.offset()) { it / 3 }
            ) {
                val animated by animateFloatAsState(
                    targetValue = progress,
                    animationSpec = Motion.spatial(),
                    label = "transferProgress"
                )
                Column {
                    LinearWavyProgressIndicator(
                        progress = { animated },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(14.dp)
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "${(animated * 100).toInt()}%",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // ----------------------------------------------------- 5. Stato
            AnimatedVisibility(
                visible = logs.isNotEmpty() || outcome != null,
                enter = fadeIn(Motion.effects()) + slideInVertically(Motion.offset()) { it / 4 }
            ) {
                StatusCard(outcome = outcome, logs = logs)
            }

            // ------------------------------------------------------ 6. Guida
            StepCard(index = 3, step = null, title = "Preparare l'orologio", done = false) {
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

            Spacer(Modifier.height(28.dp))
        }
    }
}

// ---------------------------------------------------------------- componenti

@Composable
private fun StepCard(
    index: Int,
    step: Int?,
    title: String,
    done: Boolean,
    content: @Composable () -> Unit
) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(index * 80L)
        visible = true
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(Motion.effects()) + slideInVertically(Motion.offset()) { it / 5 }
    ) {
        val container by animateColorAsState(
            targetValue = if (done) {
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.30f)
            } else {
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.32f)
            },
            animationSpec = Motion.effects(),
            label = "stepContainer"
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(26.dp),
            colors = CardDefaults.cardColors(containerColor = container)
        ) {
            Column(modifier = Modifier.padding(18.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (step != null) {
                        StepBadge(step = step, done = done)
                        Spacer(Modifier.width(12.dp))
                    }
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (done) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurface
                        }
                    )
                }
                Spacer(Modifier.height(16.dp))
                content()
            }
        }
    }
}

@Composable
private fun StepBadge(step: Int, done: Boolean) {
    val background by animateColorAsState(
        targetValue = if (done) {
            MaterialTheme.colorScheme.primary
        } else {
            MaterialTheme.colorScheme.surfaceVariant
        },
        animationSpec = Motion.effects(),
        label = "badgeBg"
    )
    val foreground by animateColorAsState(
        targetValue = if (done) {
            MaterialTheme.colorScheme.onPrimary
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        animationSpec = Motion.effects(),
        label = "badgeFg"
    )

    Box(
        modifier = Modifier
            .size(30.dp)
            .clip(CircleShape)
            .background(background),
        contentAlignment = Alignment.Center
    ) {
        if (done) {
            Icon(
                Icons.Filled.Check,
                contentDescription = null,
                tint = foreground,
                modifier = Modifier.size(18.dp)
            )
        } else {
            Text(
                text = step.toString(),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = foreground
            )
        }
    }
}

@Composable
private fun ExpressiveField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String? = null,
    support: String? = null,
    keyboard: KeyboardType = KeyboardType.Text
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = placeholder?.let { hint -> { Text(hint) } },
        supportingText = support?.let { note -> { Text(note) } },
        singleLine = true,
        shape = RoundedCornerShape(18.dp),
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        modifier = Modifier.fillMaxWidth()
    )
}

@Composable
private fun StatusCard(outcome: AdbOutcome?, logs: List<String>) {
    val accent = when (outcome) {
        is AdbOutcome.Ok -> MaterialTheme.colorScheme.primary
        is AdbOutcome.Error -> MaterialTheme.colorScheme.error
        null -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.32f)
        )
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            if (outcome != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = if (outcome is AdbOutcome.Ok) {
                            Icons.Filled.Check
                        } else {
                            Icons.Filled.Warning
                        },
                        contentDescription = null,
                        tint = accent,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = when (outcome) {
                            is AdbOutcome.Ok -> outcome.message
                            is AdbOutcome.Error -> outcome.message
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = accent
                    )
                }
                Spacer(Modifier.height(14.dp))
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 200.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                logs.forEach { line ->
                    Text(
                        text = line,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

private const val HELP_TEXT =
    "Impostazioni > Sistema > Informazioni, 7 tap su Numero build.\n\n" +
    "In Opzioni sviluppatore attiva Debug wireless: la schermata principale " +
    "mostra IP e porta di connessione.\n\n" +
    "Tocca Abbina nuovo dispositivo: compaiono il codice a 6 cifre e una porta " +
    "diversa, quella di abbinamento.\n\n" +
    "L'abbinamento resta, la porta di connessione cambia a ogni riavvio del debug."

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

echo ""
echo "==> Upgrade completato. File modificati:"
echo "    gradle/wrapper/gradle-wrapper.properties  (8.14.3)"
echo "    build.gradle.kts                          (AGP 8.13.0, Kotlin 2.2.20)"
echo "    app/build.gradle.kts                      (SDK 36, material3 1.5.0-alpha12)"
echo "    .github/workflows/build.yml               (JDK 21)"
echo "    ${PKG_DIR}/Motion.kt              (nuovo)"
echo "    ${PKG_DIR}/Theme.kt               (MaterialExpressiveTheme)"
echo "    ${PKG_DIR}/AdbInstaller.kt        (+ callback progresso)"
echo "    ${PKG_DIR}/MainActivity.kt        (UI Expressive)"
echo ""
