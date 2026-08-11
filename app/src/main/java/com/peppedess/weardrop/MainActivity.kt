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
