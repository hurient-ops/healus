// P0 요구사항: 위험 구간 알림 로직 (스트레스 테스트 결과 기반)
export interface RiskData {
    sensorId: string;
    threshold: number;
    currentValue: number;
    securityStatus: 'OK' | 'WARNING' | 'CRITICAL';
}

export function assessRisk(data: RiskData): RiskData {
    let status: 'OK' | 'WARNING' | 'CRITICAL';
    if (data.currentValue > data.threshold * 1.2) {
        status = 'CRITICAL'; // 스트레스 임계치 초과 시 즉시 경고
    } else if (data.currentValue > data.threshold) {
        status = 'WARNING'; // 주의 구간 진입 시 경고
    } else {
        status = 'OK';
    }

    return { ...data, securityStatus: status };
}

export function triggerAlert(riskData: RiskData): string {
    if (riskData.securityStatus === 'CRITICAL') {
        // BLE 통신을 통해 즉시 위험 알림 메시지 전송 로직 호출 (API/Hook 연계)
        const alertMessage = `CRITICAL ALERT: Sensor ${riskData.sensorId} exceeded threshold (${riskData.currentValue}). Security Status: CRITICAL.`;
        console.error(alertMessage);
        // TODO: BLE 통신 모듈로 알림 전송 API 호출
        return alertMessage;
    } else if (riskData.securityStatus === 'WARNING') {
        // WARNING 상태 발생 시 사용자에게 경고 표시 로직 호출
        console.warn(`WARNING: Sensor ${riskData.sensorId} approaching threshold (${riskData.currentValue}).`);
        return `Warning: Sensor ${riskData.sensorId} is at ${riskData.currentValue}.`;
    } else {
        return `Sensor ${riskData.sensorId} is operating normally.`;
    }
}