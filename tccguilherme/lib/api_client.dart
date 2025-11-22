import 'dart:io' show Platform;

/// Eu criei esta função para obter a URL base correta para a API.
/// Durante o desenvolvimento, o emulador do Android não consegue acessar
/// o `localhost` da máquina diretamente, então eu preciso usar o endereço
/// especial `10.0.2.2`. Já o simulador do iOS consegue usar `localhost`.
/// Esta função abstrai essa diferença de plataforma.
String getBaseUrl() {
  if (Platform.isIOS) {
    return 'http://localhost:3000';
  } else {
    return 'http://10.0.2.2:3000';
  }
}
