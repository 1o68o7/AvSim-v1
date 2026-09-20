class WaterBody {
  const WaterBody({
    required this.id,
    required this.name,
    required this.type,
    this.city,
    this.lat,
    this.lon,
    this.lengthM,
  });

  final String id;
  final String name;
  final String type;
  final String? city;
  final double? lat;
  final double? lon;
  final double? lengthM;

  static WaterBody fromJson(Map<String, dynamic> j) => WaterBody(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'bassin',
        city: j['city'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        lengthM: (j['length_m'] as num?)?.toDouble(),
      );
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    this.city,
    this.lat,
    this.lon,
    this.type = 'club',
    this.discipline = 'riviere',
    this.openToLoisir = false,
    this.definitionLoisir,
    this.licenceRequise = 'aucune',
    this.url,
    this.waterId,
    this.labellise,
    this.distanceKm,
    this.tarifEur,
    this.limiteBateaux,
  });

  final String id;
  final String name;
  final DateTime start;
  final DateTime? end;
  final String? city;
  final double? lat;
  final double? lon;
  final String type;
  final String discipline;
  final bool openToLoisir;
  final String? definitionLoisir;
  final String licenceRequise;
  final String? url;
  final String? waterId;
  final String? labellise;
  final double? distanceKm;
  final double? tarifEur;
  final int? limiteBateaux;

  String get typeLabel => switch (type) {
        'randonnee' => 'Randonnée',
        'master' => 'Master',
        'regate_ouverte' => 'Régate ouverte',
        'indoor_loisir' => 'Indoor loisir',
        'championnat' => 'Championnat',
        _ => type,
      };

  static CalendarEvent fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        start: DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
        city: j['city'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        type: j['type'] as String? ?? 'club',
        discipline: j['discipline'] as String? ?? 'riviere',
        openToLoisir: j['open_to_loisir'] == true,
        definitionLoisir: j['definition_loisir'] as String?,
        licenceRequise: j['licence_requise'] as String? ?? 'aucune',
        url: j['url'] as String?,
        waterId: j['water_id'] as String?,
        labellise: j['labellise'] as String?,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        tarifEur: (j['inscription_tarif_eur'] as num?)?.toDouble(),
        limiteBateaux: (j['limite_bateaux'] as num?)?.toInt(),
      );
}

class ParticipationLoisir {
  const ParticipationLoisir({
    required this.id,
    required this.eventId,
    required this.rowerId,
    required this.type,
    required this.date,
    this.tempsCourse,
    this.distanceKm,
    this.classementLoisir,
    this.source = 'manuel',
  });

  final String id;
  final String eventId;
  final String rowerId;
  final String type;
  final DateTime date;
  final String? tempsCourse;
  final double? distanceKm;
  final String? classementLoisir;
  final String source;

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'rowerId': rowerId,
        'type': type,
        'date': date.toUtc().toIso8601String(),
        'tempsCourse': tempsCourse,
        'distanceKm': distanceKm,
        'classementLoisir': classementLoisir,
        'source': source,
      };

  static ParticipationLoisir fromJson(Map<String, dynamic> j) =>
      ParticipationLoisir(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        rowerId: j['rowerId'] as String,
        type: j['type'] as String? ?? 'regate_ouverte',
        date: DateTime.parse(j['date'] as String),
        tempsCourse: j['tempsCourse'] as String?,
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        classementLoisir: j['classementLoisir'] as String?,
        source: j['source'] as String? ?? 'manuel',
      );
}
