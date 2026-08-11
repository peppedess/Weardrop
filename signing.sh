#!/usr/bin/env bash
# =============================================================================
#  WearDrop - keystore persistente
#  Firma debug e release con la stessa chiave, cosi' ogni APK prodotto dalla
#  CI si installa come aggiornamento sopra il precedente.
#  Il versionCode e' gia' legato a GITHUB_RUN_NUMBER, quindi cresce da solo.
# =============================================================================
set -euo pipefail

KEYSTORE="weardrop.jks"
ALIAS="weardrop"
STOREPASS="weardrop2026"

if [ ! -f settings.gradle.kts ]; then
    echo "ERRORE: esegui lo script dalla root del progetto WearDrop."
    exit 1
fi

echo "==> WearDrop :: keystore persistente"

# ============================================================================
#  1. Generazione keystore (solo se assente: rigenerarlo romperebbe la
#     continuita' degli aggiornamenti)
# ============================================================================
if [ -f "${KEYSTORE}" ]; then
    echo "    ${KEYSTORE} gia' presente, lo lascio intatto."
else
    if ! command -v keytool >/dev/null 2>&1; then
        echo "ERRORE: keytool non trovato. Serve un JDK nel Codespace."
        echo "        Prova con: sudo apt-get install -y default-jdk"
        exit 1
    fi
    echo "    Genero ${KEYSTORE}..."
    keytool -genkeypair \
        -keystore "${KEYSTORE}" \
        -alias "${ALIAS}" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass "${STOREPASS}" \
        -keypass "${STOREPASS}" \
        -dname "CN=peppedess, OU=WearDrop, O=peppedess, L=Milano, C=IT" \
        >/dev/null 2>&1
    echo "    Fatto."
fi

# ============================================================================
#  2. app/build.gradle.kts
# ============================================================================
cat << 'EOF' > app/build.gradle.kts
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Keystore persistente committato nel repo: garantisce che ogni build della
// CI sia firmata con la stessa chiave e quindi si installi come aggiornamento
// sopra la precedente. Se il file manca, si ricade sulla firma debug di
// default (utile per chi clona il repo senza keystore).
val persistentKeystore = rootProject.file("weardrop.jks")

android {
    namespace = "com.peppedess.weardrop"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.peppedess.weardrop"
        minSdk = 26
        targetSdk = 36

        val runNumber = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionCode = runNumber
        versionName = "3.0.$runNumber"

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    signingConfigs {
        if (persistentKeystore.exists()) {
            create("persistent") {
                storeFile = persistentKeystore
                storePassword = "weardrop2026"
                keyAlias = "weardrop"
                keyPassword = "weardrop2026"
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            if (persistentKeystore.exists()) {
                signingConfig = signingConfigs.getByName("persistent")
            }
        }
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            if (persistentKeystore.exists()) {
                signingConfig = signingConfigs.getByName("persistent")
            }
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

    buildFeatures {
        compose = true
    }

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

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.12.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    implementation("androidx.activity:activity-compose:1.11.0")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")

    // ATTENZIONE: le API M3 Expressive (MaterialExpressiveTheme, LoadingIndicator,
    // LinearWavyProgressIndicator) sono pubbliche SOLO nel ramo 1.5.0-alpha.
    // La 1.4.x stabile le ha rese interne. Non alzare oltre alpha18 senza
    // verificare le release note: dalla alpha19 servono AGP 9.1 e SDK 37.
    implementation("androidx.compose.material3:material3:1.5.0-alpha12")

    // material3 1.4+ non porta piu' material-icons-core in transitivo
    implementation("androidx.compose.material:material-icons-core:1.7.8")

    // Forme poligonali morphing (stabile)
    implementation("androidx.graphics:graphics-shapes:1.0.1")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    implementation("com.github.MuntashirAkon:libadb-android:1.0.1")

    // bcprov arriva gia' come dipendenza transitiva di libadb-android
    // (jdk15on:1.69): aggiungere jdk15to18 creerebbe classi duplicate.
    implementation("org.bouncycastle:bcpkix-jdk15on:1.69")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
EOF

# ============================================================================
#  3. .gitignore - il keystore DEVE essere committato
# ============================================================================
cat << 'EOF' > .gitignore
*.iml
.gradle/
local.properties
.idea/
.DS_Store
build/
captures/
.externalNativeBuild/
.cxx/
*.apk
*.aab

# Il keystore di WearDrop va committato: e' cio' che rende ogni build
# un aggiornamento della precedente invece di una installazione nuova.
!weardrop.jks
EOF

# ============================================================================
#  4. Verifica
# ============================================================================
echo ""
if [ -f "${KEYSTORE}" ]; then
    echo "==> Impronta della chiave:"
    keytool -list -v -keystore "${KEYSTORE}" -storepass "${STOREPASS}" 2>/dev/null \
        | grep -i "SHA256:" | head -1 || echo "    (non leggibile)"
fi
echo ""
echo "==> Fatto. Da ora ogni APK della CI e' firmato con la stessa chiave."
echo "    ATTENZIONE: la prima installazione dopo questo cambio richiede"
echo "    di disinstallare WearDrop dal telefono, perche' la firma passa"
echo "    dalla chiave debug a questa. Dalla successiva, sempre aggiornamenti."
echo ""
