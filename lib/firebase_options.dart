// Gerado por `flutterfire configure` para o projeto Firebase
// "newfitnessappbr". Não editar à mão — para regenerar (ex: depois de
// adicionar uma nova plataforma), rode `flutterfire configure` novamente
// na raiz do projeto.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não configurado para esta plataforma. '
          'Rode `flutterfire configure` para gerar as opções corretas.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyClaM065auQLqVZQCgRwf3u9DMqdD8yEIk',
    appId: '1:665761525967:web:99d888a13061494d4f07ba',
    messagingSenderId: '665761525967',
    projectId: 'newfitnessappbr',
    authDomain: 'newfitnessappbr.firebaseapp.com',
    storageBucket: 'newfitnessappbr.firebasestorage.app',
    measurementId: 'G-FZ2CQ5DGG2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8qK9y1r3meU6TfuuPNACT9Si0xb2CsNk',
    appId: '1:665761525967:android:8562eba73c7be19b4f07ba',
    messagingSenderId: '665761525967',
    projectId: 'newfitnessappbr',
    storageBucket: 'newfitnessappbr.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUNG7dtWTeh_QdosrRMSF3y1f3evyvAYs',
    appId: '1:665761525967:ios:0ea252b48108edf14f07ba',
    messagingSenderId: '665761525967',
    projectId: 'newfitnessappbr',
    storageBucket: 'newfitnessappbr.firebasestorage.app',
    iosBundleId: 'com.newfitness.newfitness',
  );
}
