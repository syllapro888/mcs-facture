import 'dart:convert';

/// Identité de l'entreprise et réglages, modifiables dans les Paramètres.
class CompanySettings {
  final String name;
  final String activities;
  final String slogan;
  final String address;
  final String phones;
  final String email;
  final String managerName;
  final String? logoPath; // chemin relatif
  final int primaryColor; // bleu foncé
  final int secondaryColor; // bleu clair
  final int accentColor; // jaune
  final bool vatEnabled;
  final double vatRate;
  final String defaultPaymentTerms;
  final String salesConditions;
  final String qualityText;
  final String installText;
  final String afterSalesText;

  const CompanySettings({
    this.name = 'MCS VISION',
    this.activities =
        'Vente et installation d’appareils électroniques, vidéosurveillance CCTV et panneaux solaires',
    this.slogan = '« MCS VISION, plus qu’un service, une vision ! »',
    this.address = '82 rue Bandza\nBrazzaville, République du Congo',
    this.phones = '+242 069 981 616\n+242 056 926 262',
    this.email = 'Mahamadousyllapro8@gmail.com',
    this.managerName = '',
    this.logoPath,
    this.primaryColor = 0xFF0B2A5B,
    this.secondaryColor = 0xFF3FA9F5,
    this.accentColor = 0xFFF7B500,
    this.vatEnabled = false,
    this.vatRate = 18,
    this.defaultPaymentTerms = 'Paiement à la commande ou à la livraison.',
    this.salesConditions =
        'Matériel garanti selon les conditions du fabricant. '
            'Les marchandises vendues ne sont ni reprises ni échangées sauf défaut constaté. '
            'Devis valable 30 jours.',
    this.qualityText = 'Produits de qualité, sélectionnés et testés.',
    this.installText = 'Installation professionnelle par nos techniciens.',
    this.afterSalesText = 'Service après-vente réactif et suivi de vos équipements.',
  });

  CompanySettings copyWith({
    String? name,
    String? activities,
    String? slogan,
    String? address,
    String? phones,
    String? email,
    String? managerName,
    String? logoPath,
    bool clearLogo = false,
    int? primaryColor,
    int? secondaryColor,
    int? accentColor,
    bool? vatEnabled,
    double? vatRate,
    String? defaultPaymentTerms,
    String? salesConditions,
    String? qualityText,
    String? installText,
    String? afterSalesText,
  }) =>
      CompanySettings(
        name: name ?? this.name,
        activities: activities ?? this.activities,
        slogan: slogan ?? this.slogan,
        address: address ?? this.address,
        phones: phones ?? this.phones,
        email: email ?? this.email,
        managerName: managerName ?? this.managerName,
        logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        accentColor: accentColor ?? this.accentColor,
        vatEnabled: vatEnabled ?? this.vatEnabled,
        vatRate: vatRate ?? this.vatRate,
        defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
        salesConditions: salesConditions ?? this.salesConditions,
        qualityText: qualityText ?? this.qualityText,
        installText: installText ?? this.installText,
        afterSalesText: afterSalesText ?? this.afterSalesText,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'activities': activities,
        'slogan': slogan,
        'address': address,
        'phones': phones,
        'email': email,
        'managerName': managerName,
        'logoPath': logoPath,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentColor': accentColor,
        'vatEnabled': vatEnabled,
        'vatRate': vatRate,
        'defaultPaymentTerms': defaultPaymentTerms,
        'salesConditions': salesConditions,
        'qualityText': qualityText,
        'installText': installText,
        'afterSalesText': afterSalesText,
      };

  factory CompanySettings.fromJson(Map<String, Object?> j) {
    const d = CompanySettings();
    String s(String k, String def) => (j[k] as String?) ?? def;
    return CompanySettings(
      name: s('name', d.name),
      activities: s('activities', d.activities),
      slogan: s('slogan', d.slogan),
      address: s('address', d.address),
      phones: s('phones', d.phones),
      email: s('email', d.email),
      managerName: s('managerName', d.managerName),
      logoPath: j['logoPath'] as String?,
      primaryColor: (j['primaryColor'] as num?)?.toInt() ?? d.primaryColor,
      secondaryColor:
          (j['secondaryColor'] as num?)?.toInt() ?? d.secondaryColor,
      accentColor: (j['accentColor'] as num?)?.toInt() ?? d.accentColor,
      vatEnabled: (j['vatEnabled'] as bool?) ?? d.vatEnabled,
      vatRate: (j['vatRate'] as num?)?.toDouble() ?? d.vatRate,
      defaultPaymentTerms: s('defaultPaymentTerms', d.defaultPaymentTerms),
      salesConditions: s('salesConditions', d.salesConditions),
      qualityText: s('qualityText', d.qualityText),
      installText: s('installText', d.installText),
      afterSalesText: s('afterSalesText', d.afterSalesText),
    );
  }

  String encode() => jsonEncode(toJson());

  static CompanySettings decode(String? text) {
    if (text == null || text.isEmpty) return const CompanySettings();
    try {
      return CompanySettings.fromJson(
          (jsonDecode(text) as Map).cast<String, Object?>());
    } catch (_) {
      return const CompanySettings();
    }
  }
}
