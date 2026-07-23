interface RealTimeData {
  timestamp: number;       // 데이터 발생 시점 (Latency 측정 기준)
  sensor_data: Record<string, any>; // 인슐린 수치, 상태 등 핵심 데이터
  stability_p0: number;    // 시스템 안정성 지표 ($P_0$)
  latency_ms: number;      // 데이터 수집 및 전송의 총 지연 시간
}

export interface BleStreamer {
  /**
   * BLE 장치로부터 데이터를 스트리밍 시작
   * @param deviceId - 연결된 BLE 장치의 고유 ID
   * @param dataCallback - 데이터를 받았을 때 호출할 콜백 함수 (WebSocket/MQTT 발행)
   */
  startStreaming(deviceId: string, dataCallback: (data: RealTimeData) => void): Promise<void>;

  /**
   * 스트림 연결 종료 및 리소스 해제
   */
  stopStreaming(): Promise<void>;

  /**
   * 실시간 성능 지표 반환 (모니터링용)
   */
  getPerformanceMetrics(): {
    p0_current: number;
    latency_avg_ms: number;
  };
}