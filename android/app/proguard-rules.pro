# Regras básicas do Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sheets e API do Google (Total proteção)
-keep class com.google.api.** { *; }
-keep interface com.google.api.** { *; }
-keep class com.google.api.client.** { *; }
-keep class com.google.api.services.sheets.** { *; }
-keep class com.google.auth.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.api.client.json.gson.** { *; }

# Google Sign-in e Play Services Auth (CRÍTICO para login com Google)
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
-dontwarn com.google.android.gms.**

# Notificações e permissões (Regras específicas)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.baseflow.permissionhandler.PermissionHandlerPlugin { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin { *; }

# Manter classes de recursos (importante para ícones de notificação)
-keep class .**.R$* { *; }

# PDF e Printing
-keep class com.baseflow.printing.** { *; }
-keep class net.nfet.pdf.** { *; }

# ML Kit Text Recognition (Latino)
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Ignorar classes de línguas não utilizadas (Chinês, Japonês, etc) que causam erro no R8
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Manter as classes que são usadas por reflexão
-keepattributes *Annotation*,Signature,EnclosingMethod,InnerClasses
-keepclassmembers class * {
  @com.google.api.client.util.Key <fields>;
}

# WorkManager
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class androidx.work.** { *; }

# Ignorar avisos de classes faltantes (evita erro de build)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.api.**
-dontwarn com.google.auth.**
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**
-dontwarn com.google.j2objc.annotations.**
