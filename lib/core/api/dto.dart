/// 与服务端 JSON 一一对应的传输对象。
/// 字段名不能改：后端 DTO 就是这些（见 /swagger/v1/swagger.json）。
library;

int? _int(dynamic v) => v is num ? v.toInt() : null;
int _intRequired(dynamic v) => v is num ? v.toInt() : 0;
String _str(dynamic v) => v is String ? v : '';
List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

class TodoDto {
  const TodoDto({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.content,
    required this.images,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    this.dueAt,
    this.doneAt,
    this.doneBy,
    this.deletedAt,
  });

  factory TodoDto.fromJson(Map<String, dynamic> j) => TodoDto(
        id: _str(j['id']),
        spaceId: _str(j['spaceId']),
        title: _str(j['title']),
        content: _str(j['content']),
        images: _strList(j['images']),
        createdBy: _str(j['createdBy']),
        createdAt: _intRequired(j['createdAt']),
        updatedAt: _intRequired(j['updatedAt']),
        rev: _intRequired(j['rev']),
        dueAt: _int(j['dueAt']),
        doneAt: _int(j['doneAt']),
        doneBy: j['doneBy'] as String?,
        deletedAt: _int(j['deletedAt']),
      );

  final String id;
  final String spaceId;
  final String title;
  final String content;
  final List<String> images;
  final String createdBy;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int? dueAt;
  final int? doneAt;
  final String? doneBy;
  final int? deletedAt;
}

class PeriodLogDto {
  const PeriodLogDto({
    required this.id,
    required this.startedOn,
    required this.flow,
    required this.symptoms,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    this.endedOn,
    this.deletedAt,
  });

  factory PeriodLogDto.fromJson(Map<String, dynamic> j) => PeriodLogDto(
        id: _str(j['id']),
        startedOn: _intRequired(j['startedOn']),
        flow: _intRequired(j['flow']),
        symptoms: _strList(j['symptoms']),
        note: _str(j['note']),
        createdAt: _intRequired(j['createdAt']),
        updatedAt: _intRequired(j['updatedAt']),
        rev: _intRequired(j['rev']),
        endedOn: _int(j['endedOn']),
        deletedAt: _int(j['deletedAt']),
      );

  final String id;
  final int startedOn;
  final int flow;
  final List<String> symptoms;
  final String note;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int? endedOn;
  final int? deletedAt;
}

class FileDto {
  const FileDto({
    required this.id,
    required this.url,
    required this.size,
    required this.sha256,
    this.width,
    this.height,
  });

  factory FileDto.fromJson(Map<String, dynamic> j) => FileDto(
        id: _str(j['id']),
        url: _str(j['url']),
        size: _intRequired(j['size']),
        sha256: _str(j['sha256']),
        width: _int(j['width']),
        height: _int(j['height']),
      );

  final String id;
  final String url;
  final int size;
  final String sha256;
  final int? width;
  final int? height;
}

class WishDto {
  const WishDto({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.price,
    required this.priority,
    required this.link,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    this.deletedAt,
  });

  factory WishDto.fromJson(Map<String, dynamic> j) => WishDto(
        id: _str(j['id']),
        spaceId: _str(j['spaceId']),
        title: _str(j['title']),
        price: _intRequired(j['price']),
        priority: _intRequired(j['priority']),
        link: _str(j['link']),
        note: _str(j['note']),
        createdBy: _str(j['createdBy']),
        createdAt: _intRequired(j['createdAt']),
        updatedAt: _intRequired(j['updatedAt']),
        rev: _intRequired(j['rev']),
        deletedAt: _int(j['deletedAt']),
      );

  final String id;
  final String spaceId;
  final String title;
  final int price;
  final int priority;
  final String link;
  final String note;
  final String createdBy;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int? deletedAt;
}

class SavingDto {
  const SavingDto({
    required this.id,
    required this.wishId,
    required this.memberId,
    required this.amount,
    required this.savedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    this.deletedAt,
  });

  factory SavingDto.fromJson(Map<String, dynamic> j) => SavingDto(
        id: _str(j['id']),
        wishId: _str(j['wishId']),
        memberId: _str(j['memberId']),
        amount: _intRequired(j['amount']),
        savedAt: _intRequired(j['savedAt']),
        createdAt: _intRequired(j['createdAt']),
        updatedAt: _intRequired(j['updatedAt']),
        rev: _intRequired(j['rev']),
        deletedAt: _int(j['deletedAt']),
      );

  final String id;
  final String wishId;
  final String memberId;
  final int amount;
  final int savedAt;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int? deletedAt;
}

class PhotoDto {
  const PhotoDto({
    required this.id,
    required this.spaceId,
    required this.fileId,
    required this.caption,
    required this.takenAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    this.deletedAt,
  });

  factory PhotoDto.fromJson(Map<String, dynamic> j) => PhotoDto(
        id: _str(j['id']),
        spaceId: _str(j['spaceId']),
        fileId: _str(j['fileId']),
        caption: _str(j['caption']),
        takenAt: _intRequired(j['takenAt']),
        createdBy: _str(j['createdBy']),
        createdAt: _intRequired(j['createdAt']),
        updatedAt: _intRequired(j['updatedAt']),
        rev: _intRequired(j['rev']),
        deletedAt: _int(j['deletedAt']),
      );

  final String id;
  final String spaceId;
  final String fileId;
  final String caption;
  final int takenAt;
  final String createdBy;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int? deletedAt;
}
