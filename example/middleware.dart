import 'dart:developer';

import 'package:laska/laska.dart';

// Custom middleware that checks user access.
class Acl implements Middleware {
  final List<String> allowedRoles;

  Acl(this.allowedRoles);

  @override
  Future<Function> execute(Function next, Context context) async {
    return (Context c) {
      // In this case it's simple check:
      // Does the request contains `role` header with `admin` value.
      final role = context.request.headers.value('role');

      // If the header's `role` is not in `allowedRoles`, reject the request.
      if (!allowedRoles.contains(role)) {
        context.text('Role $role is not allowed.');
        return null;
      }
      log('Role $role is allowed.');

      // Don't forget to call the handler.
      return next(c);
    };
  }
}

// Custom middleware that prints request path and given prefix.
class Logger implements Middleware {
  String prefix;

  Logger(this.prefix);

  @override
  Future<Function> execute(Function next, Context context) async {
    return (Context c) {
      log('$prefix: Path: ${context.path}');

      // Don't forget to call the handler.
      return next(c);
    };
  }
}

void main() async {
  final laska = Laska();

  final aclMiddleware = Acl(['admin']);

  // Add global middleware
  laska.use(Logger('global'));

  // Create handler with per-route middlewares: logger and acl
  laska.get('/secret', secretHandler,
      middlewares: {Logger('route'), aclMiddleware});

  // Add route handler, only global middleware will apply
  laska.get('/users', getUsers);

  // Add route with acl middleware, but only for the POST method.
  laska.post('/users', getUsers, middlewares: {aclMiddleware});

  await run(laska);
}

void secretHandler(Context context) async {
  await context.text('You have access to secret path!');
}

void getUsers(Context context) async {
  await context.json([
    {'id': 1, 'name': 'Make something useful', 'status': 0},
    {'id': 2, 'name': 'Make new website', 'status': 1},
  ]);
}
