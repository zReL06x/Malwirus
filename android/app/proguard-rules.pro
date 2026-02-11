# Keep generic type signatures (needed for libraries that may inspect them)
-keepattributes Signature

# Keep Gson core classes and streaming APIs
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }

# Keep our data models that may be serialized/deserialized
-keep class com.zrelxr06.malwirus.sms_security.WhitelistedNumber { *; }
 -keep class com.zrelxr06.malwirus.sms_security.WhitelistedNumber { *; }
 -keep class com.zrelxr06.malwirus.history.SmsHistoryEntry { *; }
 -keep enum com.zrelxr06.malwirus.sms_security.url.UrlScanResult { *; }
 # Keep Safe Browsing request/response models to avoid field obfuscation (Gson relies on field names)
 -keep class com.zrelxr06.malwirus.sms_security.google.safebrowsing.** { *; }

# Do not warn about sun.misc or javax annotations some libs may reference
-dontwarn sun.misc.**
-dontwarn javax.annotation.**

# ------------------------------
# ONNX Runtime JNI protections
# ------------------------------
# Keep all ONNX Runtime API classes and members from obfuscation/removal so
# the JNI layer can locate methods/fields by name.
-keep class ai.onnxruntime.** { *; }

# Keep classes that declare native methods to ensure names/signatures are preserved
-keepclasseswithmembers class ai.onnxruntime.** {
    native <methods>;
}

# Some builds benefit from keeping runtime-visible annotations and inner class data
-keepattributes *Annotation*,InnerClasses,EnclosingMethod

# ------------------------------
# TALSEC SDK (preserve SDK classes & reflection usage)
# ------------------------------
# Keep the TALSEC SDK classes (group/artifact: com.aheaditec.talsec.security)
-keep class com.aheaditec.talsec.** { *; }
-keep interface com.aheaditec.talsec.** { *; }

# Keep any annotations and annotation-usage that the SDK may inspect
-keep @interface com.aheaditec.talsec.** { *; }
-keepclassmembers class * {
    @com.aheaditec.talsec.** *;
}

# If TALSEC uses any callback/listener classes you pass from your app,
# keep public constructors/methods of classes in your app's callback packages.
-keepclassmembers class com.zrelxr06.malwirus.** {
    public <init>(...);
    public *;
}

# Preserve native methods if the SDK or underlying libs use JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Kotlin metadata (helps reflection-based libs)
-keep class kotlin.Metadata { *; }

# Keep AndroidX/Support annotations that some SDKs may check
-keep class androidx.annotation.** { *; }
-keep class android.support.annotation.** { *; }

# Preserve manifest-declared receivers/services/providers referenced by SDK via package manager
-keep class * extends com.zrelxr06.malwirus.device_security.TalsecApplication { *; }
-keep class * extends com.zrelxr06.malwirus.sms_security.receiver.SmsReceiver { *; }
-keep class * extends com.zrelxr06.malwirus.web_security.receiver.RulesUpdateReceiver { *; }

-keep class * extends com.zrelxr06.malwirus.notification.MonitoringService { *; }
-keep class * extends com.zrelxr06.malwirus.web_security.service.WebSecurityVpnService { *; }
-keep class * extends com.zrelxr06.malwirus.notification.action.NotificationActionHandler { *; }
-keep class * extends com.zrelxr06.malwirus.sms_security.receiver.CallReceiver { *; }

# Keep resource names/strings used by SDK via reflection or resource lookup
-keepclassmembers class **.R$* {
    public static <fields>;
}

# (Optional) If you want to be explicit about not obfuscating TALSEC package names
# uncomment the next line — but -keep above is usually sufficient
# -keepnames class com.aheaditec.talsec.** { *; }
