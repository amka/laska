import 'dart:io';
import 'dart:isolate';

import 'package:laska/context.dart';
import 'package:laska/middleware/middleware.dart';
import 'package:laska/router.dart';

import 'config.dart';

class Worker {
  Isolate isolate;
  ReceivePort receivePort;
  SendPort sendPort;
}

class Server {
  Configuration config;
  HttpServer server;
  Router router;
  List<Middleware> middleware;

  Server(this.config) {
    router = config.router;
    middleware = config.middleware;
  }

  void run() async {
    server = await HttpServer.bind(config.address, config.port, shared: true);
    server.listen(handleRequest);
    print('=> worker [PID:${identityHashCode(this)}] is ready');
  }

  void handleRequest(HttpRequest request) async {
    var context = Context(request);

    var route = router.lookup(request.uri.path);

    // Check if route has a handler
    if (route?.handler != null) {
      // Check if route use the same method as requested=
      if (route?.method != request.method) {
        await sendMethodNotAllowed(context);
      } else {
        try {
          context.route = route;
          var handler = route.handler;

          // Iterate over all middlewares and execute them one after another
          if (middleware.isNotEmpty) {
            for (var i = 0; i < middleware.length; i++) {
              // Middleware can return [null] in case
              // if it's need to stop request handling.
              if (handler != null) {
                handler = await middleware[i].execute(handler, context);
              } else {
                break;
              }
            }
          }

          // After all middlewares, if the handler still exists we can safely call it.
          if (handler != null) {
            await handler(context);
          }
        } catch (exception) {
          print(exception);
          await sendInternalError(context);
        }
      }
    } else {
      await sendNotFound(context);
    }

    await request.response.close();
  }

  void sendInternalError(Context context) async {
    context.response.statusCode = HttpStatus.internalServerError;
    await context.Text('Internal Server Error',
        statusCode: HttpStatus.internalServerError);
  }

  void sendNotFound(Context context) async {
    await context.Text('Not Found', statusCode: HttpStatus.notFound);
  }

  void sendMethodNotAllowed(Context context) async {
    await context.Text('Method Not Allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }
}
