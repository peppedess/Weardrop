#!/usr/bin/env bash
# =============================================================================
#  WearDrop v2 - migrazione da dadb a libadb-android (supporto pairing 6 cifre)
#  Sovrascrive solo i file che cambiano. Theme.kt, manifest, res/ e workflow
#  restano identici.
# =============================================================================
set -euo pipefail

PKG_DIR="app/src/main/java/com/peppedess/weardrop"

if [ ! -f settings.gradle.kts ]; then
    echo "ERRORE: esegui lo script dalla root del progetto WearDrop."
    exit 1
fi

mkdir -p "${PKG_DIR}"
echo "==> WearDrop v2 :: migrazione a libadb-android"

# ============================================================================
#  settings.gradle.kts  (aggiunta JitPack)
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
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "WearDrop"
include(":app")
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
        versionName = "2.0.$runNumber"

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
    //  Oltre ai duplicati META-INF, BouncyCastle porta i file di firma
    //  del JAR (*.SF / *.DSA / *.RSA) che fanno fallire il merge.
    // -------------------------------------------------------------------
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

    // Engine ADB con supporto pairing Android 11+ (solo su JitPack)
    implementation("com.github.MuntashirAkon:libadb-android:1.0.1")

    // Necessaria per generare il certificato X509 richiesto dal pairing
    implementation("org.bouncycastle:bcpkix-jdk15to18:1.78.1")
    implementation("org.bouncycastle:bcprov-jdk15to18:1.78.1")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
EOF

# ============================================================================
#  app/proguard-rules.pro
# ============================================================================
cat << 'EOF' > app/proguard-rules.pro
# Regole R8 per WearDrop
-keep class io.github.muntashirakon.adb.** { *; }
-dontwarn io.github.muntashirakon.adb.**
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn javax.annotation.**
EOF

# ============================================================================
#  WearDropAdbManager.kt
# ============================================================================
cat << 'EOF' > app/src/main/java/com/peppedess/weardrop/WearDropAdbManager.kt
package com.peppedess.weardrop

import android.content.Context
import android.os.Build
import io.github.muntashirakon.adb.AbsAdbConnectionManager
import org.bouncycastle.asn1.x500.X500NameBuilder
import org.bouncycastle.asn1.x500.style.BCStyle
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.File
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.cert.Certificate
import java.security.cert.CertificateFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Date

/**
 * Implementazione concreta di AbsAdbConnectionManager.
 *
 * La libreria richiede una coppia chiave privata + certificato X509: la
 * generiamo una volta sola e la conserviamo in filesDir, cosi' l'abbinamento
 * con l'orologio resta valido anche dopo il riavvio dell'app.
 *
 * NOTA: i campi di appoggio si chiamano mPrivateKey / mCertificate e non
 * privateKey / certificate, altrimenti Kotlin genererebbe getter con la stessa
 * firma JVM dei metodi astratti Java, causando un clash in compilazione.
 */
class WearDropAdbManager private constructor(context: Context) : AbsAdbConnectionManager() {

    private val mPrivateKey: PrivateKey
    private val mCertificate: Certificate

    init {
        setApi(Build.VERSION.SDK_INT)
        val material = loadOrCreate(context.applicationContext)
        mPrivateKey = material.first
        mCertificate = material.second
    }

    override fun getPrivateKey(): PrivateKey = mPrivateKey

    override fun getCertificate(): Certificate = mCertificate

    override fun getDeviceName(): String = "WearDrop"

    companion object {

        @Volatile
        private var instance: WearDropAdbManager? = null

        fun getInstance(context: Context): WearDropAdbManager {
            return instance ?: synchronized(this) {
                instance ?: WearDropAdbManager(context).also { instance = it }
            }
        }

        private fun loadOrCreate(context: Context): Pair<PrivateKey, Certificate> {
            val dir = File(context.filesDir, "adb").apply { mkdirs() }
            val keyFile = File(dir, "adbkey.pk8")
            val certFile = File(dir, "adbkey.crt")

            if (keyFile.exists() && certFile.exists()) {
                runCatching {
                    val key = KeyFactory.getInstance("RSA")
                        .generatePrivate(PKCS8EncodedKeySpec(keyFile.readBytes()))
                    val cert = certFile.inputStream().use { stream ->
                        CertificateFactory.getInstance("X.509").generateCertificate(stream)
                    }
                    return key to cert
                }
                keyFile.delete()
                certFile.delete()
            }

            val generator = KeyPairGenerator.getInstance("RSA")
            generator.initialize(2048)
            val pair = generator.generateKeyPair()

            val now = System.currentTimeMillis()
            val notBefore = Date(now - 86_400_000L)
            val notAfter = Date(now + 10L * 365L * 86_400_000L)

            val subject = X500NameBuilder(BCStyle.INSTANCE)
                .addRDN(BCStyle.CN, "WearDrop")
                .addRDN(BCStyle.O, "peppedess")
                .build()

            val holder = JcaX509v3CertificateBuilder(
                subject,
                BigInteger.valueOf(now),
                notBefore,
                notAfter,
                subject,
                pair.public
            ).build(JcaContentSignerBuilder("SHA256withRSA").build(pair.private))

            val certificate = JcaX509CertificateConverter().getCertificate(holder)

            keyFile.writeBytes(pair.private.encoded)
            certFile.writeBytes(certificate.encoded)

            return pair.private to certificate
        }
    }
}
EOF

# ============================================================================
#  AdbInstaller.kt
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
            emit(onLog, "Abbinamento con $host:$pairingPort...")
            val manager = WearDropAdbManager.getInstance(context)
            val paired = manager.pair(host, pairingPort, pairingCode)
            if (paired) {
                emit(onLog, "Abbinamento riuscito.")
                AdbOutcome.Ok("Orologio abbinato")
            } else {
                emit(onLog, "Abbinamento rifiutato.")
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
            emit(onLog, "Connesso a: $model (Android $release)")
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
        onLog: suspend (String) -> Unit
    ): AdbOutcome = withContext(Dispatchers.IO) {
        var temp: File? = null
        try {
            emit(onLog, "Copia del pacchetto nella cache locale...")
            val payload = copyToCache(apkUri)
            temp = payload
            emit(onLog, "Pacchetto pronto: ${formatSize(payload.length())}")

            val manager = connect(host, port, onLog)
            val response = streamInstall(manager, payload, onLog)

            if (response.contains("Success", ignoreCase = true)) {
                emit(onLog, "Installazione completata.")
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
            emit(onLog, "Connessione a $host:$port...")
            if (!manager.connect(host, port)) {
                throw IllegalStateException("Connessione rifiutata dal daemon ADB")
            }
            emit(onLog, "Canale TLS stabilito.")
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
        onLog: suspend (String) -> Unit
    ): String {
        val size = apk.length()
        emit(onLog, "Avvio streamed install...")

        val stream: AdbStream = manager.openStream("exec:cmd package install -r -t -S $size")
        try {
            val output = stream.openOutputStream()
            var sent = 0L
            var lastPercent = 0

            apk.inputStream().use { source ->
                val buffer = ByteArray(CHUNK)
                while (true) {
                    val read = source.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                    sent += read

                    val percent = ((sent * 100) / size).toInt()
                    if (percent >= lastPercent + 20) {
                        lastPercent = percent
                        emit(onLog, "Trasferimento: $percent%")
                    }
                }
            }
            output.flush()
            emit(onLog, "Trasferimento completato, attendo il package manager...")

            return stream.openInputStream().bufferedReader().readText()
        } finally {
            runCatching { stream.close() }
        }
    }

    private suspend fun emit(onLog: suspend (String) -> Unit, message: String) {
        withContext(Dispatchers.Main) { onLog(message) }
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
                "Porta chiusa: ricorda che la porta di connessione e' diversa da quella del pairing"
            raw.contains("ETIMEDOUT", true) || raw.contains("timeout", true) ->
                "Timeout: orologio non raggiungibile su questa rete Wi-Fi"
            raw.contains("EHOSTUNREACH", true) || raw.contains("ENETUNREACH", true) ->
                "Host non raggiungibile: telefono e orologio devono stare sulla stessa rete"
            raw.contains("PairingRequired", true) || raw.contains("pairing", true) ->
                "Abbinamento mancante o scaduto: rifai il pairing con un nuovo codice"
            raw.contains("AuthenticationFailed", true) ->
                "Autenticazione rifiutata dal daemon ADB dell'orologio"
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
import androidx.compose.material.icons.filled.Lock
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
    var pairPort by rememberSaveable { mutableStateOf(prefs.getString("pair_port", "") ?: "") }
    var pairCode by rememberSaveable { mutableStateOf("") }
    var connPort by rememberSaveable { mutableStateOf(prefs.getString("conn_port", "") ?: "") }
    var paired by rememberSaveable { mutableStateOf(prefs.getBoolean("paired", false)) }
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
            val result = block()
            outcome = result
            busy = false
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
            SectionCard(title = "1 - Abbinamento (una volta sola)") {
                OutlinedTextField(
                    value = host,
                    onValueChange = { host = it.trim() },
                    label = { Text("Indirizzo IP Wear OS") },
                    placeholder = { Text("192.168.1.42") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))

                OutlinedTextField(
                    value = pairPort,
                    onValueChange = { value -> pairPort = value.filter { it.isDigit() }.take(5) },
                    label = { Text("Porta di abbinamento") },
                    singleLine = true,
                    supportingText = { Text("Quella nella schermata del codice a 6 cifre") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))

                OutlinedTextField(
                    value = pairCode,
                    onValueChange = { value -> pairCode = value.filter { it.isDigit() }.take(6) },
                    label = { Text("Codice a 6 cifre") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))

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
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Filled.Lock, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (paired) "Riabbina orologio" else "Abbina orologio")
                }

                if (paired) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Orologio gia' abbinato",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }

            // -------------------------------------------------- 2. Connessione
            SectionCard(title = "2 - Connessione") {
                OutlinedTextField(
                    value = connPort,
                    onValueChange = { value -> connPort = value.filter { it.isDigit() }.take(5) },
                    label = { Text("Porta di connessione") },
                    singleLine = true,
                    supportingText = { Text("Diversa dalla precedente, cambia a ogni riavvio del debug") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))

                OutlinedButton(
                    onClick = {
                        run {
                            installer.testConnection(
                                host = host.trim(),
                                port = connPortNumber ?: 0
                            ) { logs.add(it) }
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

            // ------------------------------------------------------ 3. APK
            SectionCard(title = "3 - Pacchetto APK") {
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

            // -------------------------------------------------- 4. Installa
            Button(
                onClick = {
                    val uri = apkUri ?: return@Button
                    run {
                        installer.install(
                            apkUri = uri,
                            host = host.trim(),
                            port = connPortNumber ?: 0
                        ) { logs.add(it) }
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

            // ----------------------------------------------------- 5. Stato
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

            // ------------------------------------------------------ 6. Guida
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
    "1. Sull'orologio: Impostazioni > Sistema > Informazioni, 7 tap su \"Numero build\".\n\n" +
    "2. Opzioni sviluppatore > attiva \"Debug wireless\". La schermata principale " +
    "mostra IP e PORTA DI CONNESSIONE.\n\n" +
    "3. Tocca \"Abbina nuovo dispositivo\": compare il codice a 6 cifre e una " +
    "PORTA DIVERSA, quella di abbinamento. Non confonderle.\n\n" +
    "4. Fai l'abbinamento mentre il dialog e' aperto sull'orologio. Dopo, per " +
    "installare basta la porta di connessione.\n\n" +
    "5. La porta di connessione cambia ogni volta che disattivi e riattivi il " +
    "debug wireless: l'abbinamento invece resta."

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
echo "==> Migrazione completata. File modificati:"
echo "    settings.gradle.kts        (+ JitPack)"
echo "    app/build.gradle.kts       (- dadb, + libadb-android, + BouncyCastle)"
echo "    app/proguard-rules.pro"
echo "    ${PKG_DIR}/WearDropAdbManager.kt   (nuovo)"
echo "    ${PKG_DIR}/AdbInstaller.kt         (riscritto)"
echo "    ${PKG_DIR}/MainActivity.kt         (riscritto)"
echo ""
echo "==> Prossimo passo: commit + push, poi controlla la tab Actions."
