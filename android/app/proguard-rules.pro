# R8 runs on release builds and strips anything it cannot see being used.
# Reflection-based libraries are invisible to it, so what they need has to be
# named explicitly here. Without these rules the app builds, installs and runs
# — and then dies the moment a scheduled notification fires, which is the worst
# kind of failure: one that only appears in release, days after install.

# Gson resolves generic types at runtime through TypeToken, which reads the
# Signature attribute. R8 drops that attribute by default, and Gson then throws
# "Missing type parameter." flutter_local_notifications uses Gson to persist
# scheduled notifications and to read them back when the alarm fires, so
# without this the reminder crashes its own broadcast receiver.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# The plugin's model classes are serialised by field name. Renaming them breaks
# the round trip between scheduling a notification and rebuilding it later.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson's own type adapters and the fields it reflects over.
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**

# local_auth's biometric prompt is resolved reflectively by AndroidX.
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**
