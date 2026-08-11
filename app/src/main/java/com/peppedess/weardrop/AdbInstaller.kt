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
