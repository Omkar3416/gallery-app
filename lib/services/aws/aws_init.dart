// import 'package:amplify_flutter/amplify_flutter.dart';
// import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
// import 'package:amplify_storage_s3/amplify_storage_s3.dart';
// import '../../amplifyconfiguration.dart';

// class AwsInit {
//   static bool _configured = false;

//   static Future<void> configureIfNeeded() async {
//     if (_configured) return;
//     try {
//       final auth = AmplifyAuthCognito();
//       final storage = AmplifyStorageS3();
//       await Amplify.addPlugins([auth, storage]);
//       await Amplify.configure(amplifyconfig);
//       _configured = true;
//       safePrint('Amplify configured');
//     } on AmplifyAlreadyConfiguredException {
//       _configured = true;
//     } catch (e) {
//       safePrint('Amplify configure failed: $e');
//     }
//   }
// }
