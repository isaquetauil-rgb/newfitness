import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Liga o app ao Firebase Emulator do computador, em vez do projeto real:
/// `flutter run --dart-define=USE_LOCAL_FIREBASE=true`. Fora do modo debug é
/// sempre desligado, para um APK nunca apontar para o emulador.
const bool useLocalFirebase =
    kDebugMode && bool.fromEnvironment('USE_LOCAL_FIREBASE');

/// `10.0.2.2` é o computador visto de dentro do emulador Android. Para outro
/// alvo, passe `--dart-define=LOCAL_FIREBASE_HOST=<ip>`.
const String _host = String.fromEnvironment(
  'LOCAL_FIREBASE_HOST',
  defaultValue: '10.0.2.2',
);

/// Portas iguais às de `firebase.json`. Chame antes de qualquer uso do
/// Firebase.
Future<void> connectToLocalFirebase() async {
  await FirebaseAuth.instance.useAuthEmulator(_host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_host, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(_host, 5001);
  await FirebaseStorage.instance.useStorageEmulator(_host, 9199);
}
