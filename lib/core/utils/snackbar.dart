import 'package:all_commerce/core/utils/auth_error_mapper.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';

void showErrorSnackBar(
  BuildContext context,
  Object error, {
  bool clearNavBar = true,
}) {
  showAppSnackBar(
    context,
    AuthErrorMapper.toMessage(error),
    clearNavBar: clearNavBar,
    isError: true,
  );
}
