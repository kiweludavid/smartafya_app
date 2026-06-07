/// First whitespace-separated word of [fullName], or empty if there is none.
String firstNameFromFullName(String fullName) {
  for (final part in fullName.trim().split(RegExp(r'\s+'))) {
    if (part.isNotEmpty) return part;
  }
  return '';
}
