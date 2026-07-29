# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Google ML Kit Text Recognition ──────────────────────────────────────────
# Plugin google_mlkit_text_recognition mereferensikan semua script model
# (Latin, Chinese, Devanagari, Japanese, Korean) meski yang dipakai cuma Latin.
# R8 akan error jika class-class ini tidak di-keep.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# ── General ML Kit ───────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── Sqflite ──────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── Local Auth (Biometric) ───────────────────────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }

# ── File Picker ──────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ── Suppress common dontwarn ─────────────────────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
