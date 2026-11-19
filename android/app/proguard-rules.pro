# Flutter / Agp varsayilanlari
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# AdMob (Google Mobile Ads)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.ads.** { *; }

# Dart tarafi R8 ile obfuscate edilmez; JSON modelleri icin kural gerekmez.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# R8: gereksiz log cagrilari kalsin
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
