package com.weardrop.app

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader

class AdbInstaller(private val context: Context) {

    suspend fun installApk(ip: String, port: Int, apkUri: Uri, onStatusUpdate: (String) -> Unit): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                onStatusUpdate("Preparazione file APK...")
                val tempFile = createTempApkFile(apkUri) ?: throw Exception("Impossibile leggere il file APK")

                onStatusUpdate("Connessione ad ADB ($ip:$port)...")
                runCommand("adb connect $ip:$port")

                onStatusUpdate("Installazione APK su Wear OS in corso...")
                val installResult = runCommand("adb -s $ip:$port install -r ${tempFile.absolutePath}")

                tempFile.delete()

                if (installResult.contains("Success", ignoreCase = true)) {
                    onStatusUpdate("Installazione completata con successo!")
                    true
                } else {
                    onStatusUpdate("Risultato: $installResult")
                    false
                }
            } catch (e: Exception) {
                onStatusUpdate("Errore: ${e.localizedMessage}")
                false
            }
        }
    }

    private fun runCommand(command: String): String {
        return try {
            val process = Runtime.getRuntime().exec(command)
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.append(line).append("\n")
            }
            process.waitFor()
            output.toString().ifBlank { "Comando eseguito" }
        } catch (e: Exception) {
            "Errore esecuzione: ${e.localizedMessage}"
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
        } catch (e: Exception) {
            null
        }
    }
}
