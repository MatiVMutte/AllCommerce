import 'package:all_commerce/core/utils/auth_error_mapper.dart';
import 'package:flutter/material.dart';

void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AuthErrorMapper.toMessage(error))),
  );
}
