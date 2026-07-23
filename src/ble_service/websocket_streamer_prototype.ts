// WebSocket Streamer Prototype - Initial Architecture Blueprint

import { PerformanceMonitor } from './performance_monitor';
import { BleInterface } from './ble_interface';

/**
 * 실시간 BLE 데이터 스트리밍을 관리하는 핵심 모듈
 * P0/Latency 제약을 반영하여 데이터를 필터링하고 스트리밍합니다.
 */
export class WebSocketStreamer {
    private monitor: PerformanceMonitor;
    private bleInterface: BleInterface;
    private wsServer: any; // 실제 WebSocket 서버 인스턴스 참조

    constructor(monitor: PerformanceMonitor, bleInterface: BleInterface) {
        this.monitor = monitor;
        this.bleInterface = bleInterface;
        // TODO: 실제 WebSocket 연결 초기화 로직 추가 필요
        console.log("WebSocketStreamer initialized with P0/Latency integration.");
    }

    /**
     * BLE 인터페이스로부터 원시 데이터를 받아 처리하고 스트리밍합니다.
     * @param rawData 원시 BLE 데이터 객체
     */
    public async processAndStream(rawData: any): Promise<void> {
        // 1. 실시간 성능 검증 (P0/Latency 반영)
        const performanceMetrics = this.monitor.evaluate(rawData);

        if (!performanceMetrics.is_stable) {
            console.warn(`[WARNING] Data from ${rawData.source_id} rejected due to instability: ${performanceMetrics.reason}`);
            // 불안정하면 스트리밍을 일시 중지하거나 경고만 보낼 수 있음 (P0 유지)
            return;
        }

        // 2. 메시지 포맷 구성
        const payload = this.formatMessage(rawData, performanceMetrics);

        // 3. WebSocket으로 스트리밍 (실제 구현 필요)
        if (this.wsServer && this.wsServer.readyState === WebSocket.OPEN) {
            try {
                this.wsServer.send(JSON.stringify(payload));
            } catch (error) {
                console.error("WebSocket send error:", error);
            }
        } else {
            console.error("WebSocket is not open. Dropping data for source:", rawData.source_id);
        }
    }

    /**
     * 데이터 객체를 최종 스트리밍 포맷으로 변환합니다.
     */
    private formatMessage(rawData: any, metrics: any): any {
        return {
            type: "BLE_DATA",
            timestamp: Date.now(),
            source_id: rawData.source_id,
            data: rawData.data,
            metadata: {
                latency_ms: metrics.latency_ms,
                p0_status: metrics.p0_status, // P0 상태 반영
                sequence_num: rawData.sequence_num // 시퀀스 번호 포함
            }
        };
    }

    // TODO: 실제 WebSocket 연결 및 이벤트 핸들링 메소드 구현 필요
    public connectWebSocket(url: string): void {
        console.log(`Attempting to connect WebSocket to ${url}...`);
        // ... (Actual WebSocket connection logic)
    }
}
// End of Prototype