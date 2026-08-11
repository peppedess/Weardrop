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
