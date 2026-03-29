/// Replace this content with the output from `amplify pull`
/// or `amplify init` + `amplify add auth` + `amplify add storage`.
/// Keep the variable name the same.
const amplifyconfig = r'''
{
  "auth": { "plugins": { "awsCognitoAuthPlugin": { } } },
  "storage": { "plugins": { "awsS3StoragePlugin": { } } }
}
''';
