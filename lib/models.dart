class Vault {
  final String name;
  final String vaultId;
  final String shareId;

  const Vault({
    required this.name,
    required this.vaultId,
    required this.shareId,
  });

  factory Vault.fromJson(Map<String, dynamic> j) => Vault(
        name: j['name'] as String,
        vaultId: j['vault_id'] as String,
        shareId: j['share_id'] as String,
      );
}

enum ItemType { login, note, creditCard, identity, alias, sshKey, wifi, custom, unknown }

class LoginContent {
  final String email;
  final String username;
  final String password;
  final List<String> urls;
  final String totpUri;

  const LoginContent({
    required this.email,
    required this.username,
    required this.password,
    required this.urls,
    required this.totpUri,
  });

  factory LoginContent.fromJson(Map<String, dynamic> j) => LoginContent(
        email: j['email'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
        urls: (j['urls'] as List<dynamic>? ?? []).cast<String>(),
        totpUri: j['totp_uri'] as String? ?? '',
      );
}

class CreditCardContent {
  final String cardholderName;
  final String number;
  final String expirationDate;
  final String verificationNumber;
  final String pin;
  final String cardType;

  const CreditCardContent({
    required this.cardholderName,
    required this.number,
    required this.expirationDate,
    required this.verificationNumber,
    required this.pin,
    required this.cardType,
  });

  factory CreditCardContent.fromJson(Map<String, dynamic> j) => CreditCardContent(
        cardholderName: j['cardholder_name'] as String? ?? '',
        number: j['number'] as String? ?? '',
        expirationDate: j['expiration_date'] as String? ?? '',
        verificationNumber: j['verification_number'] as String? ?? '',
        pin: j['pin'] as String? ?? '',
        cardType: j['card_type'] as String? ?? '',
      );
}

class IdentityContent {
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String birthdate;
  final String gender;
  final String organization;
  final String streetAddress;
  final String city;
  final String stateOrProvince;
  final String zipOrPostalCode;
  final String countryOrRegion;
  final String passportNumber;
  final String licenseNumber;
  final String socialSecurityNumber;
  final String jobTitle;
  final String workEmail;
  final List<ExtraField> extraPersonalDetails;
  final List<ExtraField> extraAddressDetails;
  final List<ExtraField> extraContactDetails;
  final List<ExtraField> extraWorkDetails;

  const IdentityContent({
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.birthdate,
    required this.gender,
    required this.organization,
    required this.streetAddress,
    required this.city,
    required this.stateOrProvince,
    required this.zipOrPostalCode,
    required this.countryOrRegion,
    required this.passportNumber,
    required this.licenseNumber,
    required this.socialSecurityNumber,
    required this.jobTitle,
    required this.workEmail,
    required this.extraPersonalDetails,
    required this.extraAddressDetails,
    required this.extraContactDetails,
    required this.extraWorkDetails,
  });

  factory IdentityContent.fromJson(Map<String, dynamic> j) {
    List<ExtraField> parseExtras(String key) =>
        (j[key] as List<dynamic>? ?? [])
            .map((e) => ExtraField.fromJson(e as Map<String, dynamic>))
            .where((f) => f.value.isNotEmpty)
            .toList();

    return IdentityContent(
      fullName: j['full_name'] as String? ?? '',
      firstName: j['first_name'] as String? ?? '',
      lastName: j['last_name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      phoneNumber: j['phone_number'] as String? ?? '',
      birthdate: j['birthdate'] as String? ?? '',
      gender: j['gender'] as String? ?? '',
      organization: j['organization'] as String? ?? '',
      streetAddress: j['street_address'] as String? ?? '',
      city: j['city'] as String? ?? '',
      stateOrProvince: j['state_or_province'] as String? ?? '',
      zipOrPostalCode: j['zip_or_postal_code'] as String? ?? '',
      countryOrRegion: j['country_or_region'] as String? ?? '',
      passportNumber: j['passport_number'] as String? ?? '',
      licenseNumber: j['license_number'] as String? ?? '',
      socialSecurityNumber: j['social_security_number'] as String? ?? '',
      jobTitle: j['job_title'] as String? ?? '',
      workEmail: j['work_email'] as String? ?? '',
      extraPersonalDetails: parseExtras('extra_personal_details'),
      extraAddressDetails: parseExtras('extra_address_details'),
      extraContactDetails: parseExtras('extra_contact_details'),
      extraWorkDetails: parseExtras('extra_work_details'),
    );
  }
}

class ExtraField {
  final String name;
  final String value;

  const ExtraField({required this.name, required this.value});

  factory ExtraField.fromJson(Map<String, dynamic> j) {
    final content = j['content'] as Map<String, dynamic>? ?? {};
    String val = '';
    if (content.containsKey('Text')) val = content['Text'] as String? ?? '';
    if (content.containsKey('Hidden')) val = content['Hidden'] as String? ?? '';
    if (content.containsKey('Totp')) val = content['Totp'] as String? ?? '';
    return ExtraField(name: j['name'] as String? ?? '', value: val);
  }
}

class PassItem {
  final String id;
  final String shareId;
  final String vaultId;
  final String title;
  final String note;
  final ItemType type;
  final LoginContent? login;
  final CreditCardContent? creditCard;
  final IdentityContent? identity;
  final List<ExtraField> extraFields;
  final DateTime createTime;
  final DateTime modifyTime;

  const PassItem({
    required this.id,
    required this.shareId,
    required this.vaultId,
    required this.title,
    required this.note,
    required this.type,
    this.login,
    this.creditCard,
    this.identity,
    required this.extraFields,
    required this.createTime,
    required this.modifyTime,
  });

  String get displayUrl {
    if (login != null && login!.urls.isNotEmpty) return login!.urls.first;
    return '';
  }

  String get displayUsername => login?.email.isNotEmpty == true
      ? login!.email
      : login?.username ?? '';

  factory PassItem.fromJson(Map<String, dynamic> j) {
    final content = j['content'] as Map<String, dynamic>? ?? {};
    final title = content['title'] as String? ?? '';
    final note = content['note'] as String? ?? '';
    final inner = content['content'] as Map<String, dynamic>? ?? {};
    final extra = (content['extra_fields'] as List<dynamic>? ?? [])
        .map((e) => ExtraField.fromJson(e as Map<String, dynamic>))
        .where((f) => f.value.isNotEmpty)
        .toList();

    ItemType type = ItemType.unknown;
    LoginContent? login;
    CreditCardContent? creditCard;
    IdentityContent? identity;

    if (inner.containsKey('Login')) {
      type = ItemType.login;
      login = LoginContent.fromJson(inner['Login'] as Map<String, dynamic>);
    } else if (inner.containsKey('Note')) {
      type = ItemType.note;
    } else if (inner.containsKey('CreditCard')) {
      type = ItemType.creditCard;
      creditCard = CreditCardContent.fromJson(inner['CreditCard'] as Map<String, dynamic>);
    } else if (inner.containsKey('Identity')) {
      type = ItemType.identity;
      identity = IdentityContent.fromJson(inner['Identity'] as Map<String, dynamic>);
    } else if (inner.containsKey('Alias')) {
      type = ItemType.alias;
    }

    return PassItem(
      id: j['id'] as String? ?? '',
      shareId: j['share_id'] as String? ?? '',
      vaultId: j['vault_id'] as String? ?? '',
      title: title,
      note: note,
      type: type,
      login: login,
      creditCard: creditCard,
      identity: identity,
      extraFields: extra,
      createTime: DateTime.tryParse(j['create_time'] as String? ?? '') ?? DateTime.now(),
      modifyTime: DateTime.tryParse(j['modify_time'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
