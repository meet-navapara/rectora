# The ads SDK starts WorkManager at launch. Room finds its database by adding
# "_Impl" to the class name, so R8 renaming that class crashes the release
# build before the first frame.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keepnames class * extends androidx.room.RoomDatabase
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# Newer Flutter plugins call their Java code from Dart through JNI, by name.
# R8 cannot see those calls, so it would rename or remove the targets.
-keep class io.flutter.plugins.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
