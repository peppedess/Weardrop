# WearDrop

Installa file APK su smartwatch **Wear OS** direttamente dal telefono, via
**Wireless ADB**, senza PC.

## Stack

| Componente | Versione |
|---|---|
| JDK | 17 |
| Gradle Wrapper | 8.9 (bin) |
| Android Gradle Plugin | 8.7.3 |
| Kotlin | 2.0.21 (+ plugin Compose) |
| compileSdk / targetSdk | 35 |
| minSdk | 26 |
| Compose BOM | 2024.10.01 |
| Engine ADB | `dev.mobile:dadb:1.2.6` (Maven Central) |

## Come si usa

1. Sull'orologio: Impostazioni > Sistema > Informazioni > 7 tap su "Numero build".
2. Opzioni sviluppatore > attiva **Debug ADB** e **Debug via Wi-Fi**.
3. Annota IP e porta mostrati (di norma `5555`).
4. In WearDrop inserisci IP e porta, premi **Test connessione**.
5. Accetta il prompt di autorizzazione che compare sull'orologio.
6. Seleziona l'APK e premi **Installa sullo smartwatch**.

Telefono e orologio devono essere sulla stessa rete Wi-Fi.

## Build

La pipeline GitHub Actions compila la variante debug e pubblica
`app-debug.apk` come artifact.
