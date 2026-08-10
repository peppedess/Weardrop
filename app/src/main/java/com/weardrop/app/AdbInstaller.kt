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
