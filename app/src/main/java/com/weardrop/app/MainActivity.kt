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
