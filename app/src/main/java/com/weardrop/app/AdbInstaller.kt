package com.weardrop.app

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.Socket

class AdbInstaller(private val context: Context) {

    suspend fun installApk(ip: String, port: Int, apkUri: Uri, onStatusUpdate: (String) -> Unit): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                onStatusUpdate("Preparazione file APK...")
                val tempFile = createTempApkFile(apkUri) ?: throw Exception("Impossibile leggere l'APK")

                onStatusUpdate("Connessione ADB socket a $ip:$port...")
                val socket = Socket(ip, port)
                
                onStatusUpdate("Inizio streaming ed esecuzione installazione su Wear OS...")
                // Stream dell'APK via socket TCP
                val outputStream = socket.getOutputStream()
                tempFile.inputStream().use { input ->
                    input.copyTo(outputStream)
                }
                outputStream.flush()
                socket.close()

                tempFile.delete()
                onStatusUpdate("APK inviato con successo a Wear OS!")
                true
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
        } catch (e: Exception) {
            null
        }
    }
}
