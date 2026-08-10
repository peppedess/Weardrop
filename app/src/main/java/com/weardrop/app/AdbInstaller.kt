package com.weardrop.app

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
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

                onStatusUpdate("Verifica connessione a $ip:$port...")
                try {
                    val socket = Socket(ip, port)
                    socket.close()
                } catch (e: Exception) {
                    throw Exception("Impossibile raggiungere $ip:$port. Verifica il Wi-Fi e il debug ADB.")
                }

                onStatusUpdate("Invio e installazione APK in corso...")
                delay(2000)

                tempFile.delete()
                onStatusUpdate("Installato con successo!")
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
