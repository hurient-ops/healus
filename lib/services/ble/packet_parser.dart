import 'dart:typed_data';

/// Big-endian 정수 변환 및 6Byte DATE 구조체 인코딩/디코딩 파서 유틸리티
class PacketParser {
  /// 6Byte DATE 바이트(연, 월, 일, 시, 분, 초)를 [DateTime] 객체로 디코딩합니다.
  /// 연도가 100보다 작은 경우 2000을 더해 2000년대 날짜로 보정합니다.
  static DateTime parseDate(List<int> bytes, {int offset = 0}) {
    if (bytes.length < offset + 6) {
      throw ArgumentError("DATE 파싱을 위한 바이트 길이가 부족합니다. (최소 6바이트 필요)");
    }
    int year = bytes[offset];
    int month = bytes[offset + 1];
    int day = bytes[offset + 2];
    int hour = bytes[offset + 3];
    int minute = bytes[offset + 4];
    int second = bytes[offset + 5];

    // 연도 보정 (예: 17 -> 2017)
    int fullYear = year < 100 ? 2000 + year : year;

    // 월, 일, 시, 분, 초 유효성 방어 코드
    month = month.clamp(1, 12);
    day = day.clamp(1, 31);
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);
    second = second.clamp(0, 59);

    try {
      return DateTime(fullYear, month, day, hour, minute, second);
    } catch (_) {
      // 파싱 실패 시 현재 시간 반환 또는 최소값 반환
      return DateTime(2000, 1, 1, 0, 0, 0);
    }
  }

  /// [DateTime] 객체를 6Byte DATE 바이트 리스트로 인코딩합니다.
  /// 연도는 100으로 나눈 나머지(2자리)로 변환해 저장합니다.
  static List<int> serializeDate(DateTime dt) {
    int yearShort = dt.year % 100;
    return [
      yearShort,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    ];
  }

  /// Big-endian 16비트 정수(2바이트)를 읽습니다.
  static int readUint16(List<int> bytes, int offset) {
    if (bytes.length < offset + 2) {
      throw ArgumentError("Uint16을 읽기 위한 바이트가 부족합니다.");
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  /// Big-endian 16비트 정수(2바이트)를 바이트 버퍼에 씁니다.
  static void writeUint16(List<int> bytes, int offset, int value) {
    if (bytes.length < offset + 2) {
      throw ArgumentError("Uint16을 쓰기 위한 버퍼 크기가 부족합니다.");
    }
    bytes[offset] = (value >> 8) & 0xFF;
    bytes[offset + 1] = value & 0xFF;
  }

  /// Big-endian 32비트 정수(4바이트)를 읽습니다.
  static int readUint32(List<int> bytes, int offset) {
    if (bytes.length < offset + 4) {
      throw ArgumentError("Uint32를 읽기 위한 바이트가 부족합니다.");
    }
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  /// Big-endian 32비트 정수(4바이트)를 바이트 버퍼에 씁니다.
  static void writeUint32(List<int> bytes, int offset, int value) {
    if (bytes.length < offset + 4) {
      throw ArgumentError("Uint32를 쓰기 위한 버퍼 크기가 부족합니다.");
    }
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }
}
