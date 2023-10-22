/// Email format type constants.
enum EmailType {
  /// Unknown email type.
  unknown(0),

  /// Work email.
  work(1),

  /// Home email.
  home(2);

  const EmailType(this.rawValue);

  factory EmailType.fromRawValue(int value) {
    switch (value) {
      case 1:
        return EmailType.work;
      case 2:
        return EmailType.home;
      case 0:
      default:
        return EmailType.unknown;
    }
  }

  /// The raw email type value.
  final int rawValue;
}
