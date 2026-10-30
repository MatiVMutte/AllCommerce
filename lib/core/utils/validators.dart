abstract final class Validators {
  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    final RegExp regex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
    if (!regex.hasMatch(v)) return 'Ingresá un email válido';
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? fullName(String? value) {
    final int len = (value ?? '').trim().length;
    if (len < 2 || len > 80) return 'Ingresá tu nombre completo';
    return null;
  }

  static String? phone(String? value) {
    final String digits = normalizePhone(value ?? '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Ingresá un WhatsApp válido (ej: 11 2233 4455)';
    }
    return null;
  }

  static String? slug(String? value) {
    final String v = (value ?? '').trim();
    if (!RegExp(r'^[a-z0-9-]{3,40}$').hasMatch(v)) {
      return 'Solo letras minúsculas, números y guiones (3 a 40)';
    }
    return null;
  }

  static String? storeName(String? value) {
    final int len = (value ?? '').trim().length;
    if (len < 2 || len > 80) return 'Ingresá el nombre del local';
    return null;
  }

  /// Strips non-digits, drops a leading '0', and prefixes '549' for
  /// 10-digit local AR numbers.
  static String normalizePhone(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) return '549$digits';
    if (digits.startsWith('54')) return digits;
    if (digits.startsWith('549')) return digits;
    return digits;
  }

  static String slugify(String input) {
    const Map<String, String> accents = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'à': 'a',
      'è': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
      'ä': 'a',
      'ë': 'e',
      'ï': 'i',
      'ö': 'o',
      'ü': 'u',
      'â': 'a',
      'ê': 'e',
      'î': 'i',
      'ô': 'o',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    String result = input.toLowerCase();
    accents.forEach((String from, String to) {
      result = result.replaceAll(from, to);
    });
    result = result.replaceAll(RegExp(r'[^a-z0-9]'), '-');
    result = result.replaceAll(RegExp(r'-+'), '-');
    result = result.replaceAll(RegExp(r'^-+|-+$'), '');
    if (result.length > 40) {
      result = result.substring(0, 40);
      result = result.replaceAll(RegExp(r'-+$'), '');
    }
    return result;
  }
}
