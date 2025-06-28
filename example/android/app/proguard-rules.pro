# Flutter's default rules.
-dontwarn io.flutter.embedding.**

# Rules for MediaPipe and its dependencies.
# This tells R8 not to worry about missing classes from these packages,
# as they are only used during compile time.
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**
