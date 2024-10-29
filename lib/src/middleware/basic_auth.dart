import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:laska/src/context.dart';
import 'package:laska/src/middleware/middleware.dart';

class BasicAuth implements Middleware {
  String? digest;
  String realm;

  BasicAuth(String username, String password,
      {this.realm = 'Access to the Laska Server'}) {
    digest = base64.encode(utf8.encode('$username:$password'));
  }

  @override
  Future<Function> execute(Function next, Context context) async {
    return (Context c) {
      // Check request for `Authorization` header.
      var authHeader = context.request.headers.value('authorization');

      // `Authorization` value should be larger than 6 because of `Basic `.
      if (authHeader == null || authHeader.length <= 6) {
        return sendUnauthorized(context);
      }

      log('BasicAuth: $digest == ${authHeader.substring(6)}');

      // Check auth digest
      if (digest == authHeader.substring(6)) {
        next(c);
        return;
      }

      return sendUnauthorized(context);
    };
  }

  void sendUnauthorized(Context context) {
    context.response!
      ..headers.add('WWW-Authenticate', 'Basic realm="$realm", charset="UTF-8"')
      ..statusCode = HttpStatus.unauthorized;
  }
}
