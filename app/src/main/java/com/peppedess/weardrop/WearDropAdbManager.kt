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
