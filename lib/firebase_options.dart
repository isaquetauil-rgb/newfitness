// ATENÇÃO: este arquivo é um PLACEHOLDER.
//
// Ele deve ser substituído pelo arquivo real, gerado automaticamente ao
// rodar o comando abaixo na raiz do projeto (depois de instalar a CLI do
// FlutterFire — veja o README.md para o passo a passo completo):
//
//   flutterfire configure
//
// Esse comando cria/atualiza este arquivo com as chaves reais do seu
// projeto Firebase para cada plataforma (Android, iOS, Web).

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
    apiKey: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    appId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    projectId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    authDomain: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    appId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    projectId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    appId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    projectId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    iosBundleId: 'com.example.newfitness',
  );
}
