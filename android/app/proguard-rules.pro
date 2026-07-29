##──────────────────────────────────────────────────────────────────────────────
## Flutter core
##──────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

##──────────────────────────────────────────────────────────────────────────────
## Google ML Kit – Text Recognition
## Plugin mereferensikan semua script (Chinese/Devanagari/Japanese/Korean)
## meski hanya Latin yang dipakai. R8 gagal jika class ini tidak di-keep.
##──────────────────────────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google.mlkit.**

## Google Play Services (dipakai ML Kit di balik layar)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

##──────────────────────────────────────────────────────────────────────────────
## Sqflite
##──────────────────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Local Auth (Biometric)
##──────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Flutter Secure Storage
##──────────────────────────────────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## File Picker
##──────────────────────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Image Picker
##──────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Photo View
##──────────────────────────────────────────────────────────────────────────────
-keep class com.github.chrisbanes.photoview.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Shared Preferences
##──────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Path Provider
##──────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

##──────────────────────────────────────────────────────────────────────────────
## Suppress common dontwarn – library internal classes
##──────────────────────────────────────────────────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn sun.misc.Unsafe
-dontwarn java.lang.invoke.**
