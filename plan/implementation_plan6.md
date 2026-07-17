# 주입 중 제어 및 BLE 주입 완료 연동 공통 모니터링 구현 계획서 (수정본)

'주입 중' 상태일 때 대시보드의 빠른 실행 메뉴 진입을 방지하고, 타 페이지에 있더라도 BLE 수신 완료(또는 테스트용 타이머 만료) 시 대시보드로 자동 이동하여 완료 팝업을 노출하는 구조를 설계합니다. 특히, 실제품 빌드를 고려해 타이머 기능을 손쉽게 온/오프할 수 있도록 옵션을 제공하고, 경고 UI는 모던한 토스트 알림으로 구현합니다.

## User Review Required

> [!IMPORTANT]
> - **시뮬레이션 타이머 온/오프 사양 (CONFIG_USE_TIMER)**:
>   - 공통 및 대시보드 스크립트 최상단에 `const CONFIG_USE_TIMER = true;` 상수를 선언합니다.
>   - 최종 빌드 시 이 값을 `false`로 바꾸거나, 로컬 스토리지에 `localStorage.setItem('CONFIG_USE_TIMER', 'false')`를 설정하면 타이머에 의한 5초 완료 처리가 완전히 차단됩니다.
>   - 타이머가 꺼진 상태에서는 실제 BLE 통신 모듈(또는 에뮬레이터 네이티브 영역)에서 `localStorage.setItem('isInjecting', 'false')`를 호출했을 때, `storage` 이벤트 감지를 통해 즉시 대시보드로 이동하고 완료 팝업을 노출하도록 반응형으로 연동합니다.
> - **토스트(Toast) 알림 UI 적용**:
>   - 기존의 브라우저 `alert` 대신, 화면 하단 중앙에 부드럽게 페이드인/아웃되는 다크 반투명 토스트 팝업을 동적으로 생성하여 띄웁니다.
>   - 노출 문구: `"주입 중에서 수행할 수 없습니다"`
>   - 대시보드에서 차단 버튼 클릭 시 혹은 주입 관련 서브 페이지로 직접 접근하여 튕겨나갔을 때 모두 이 토스트 알림이 노출됩니다.

## Proposed Changes

### [Dashboard Component]

---

#### [MODIFY] [dashboard/code.html](file:///e:/projects/healus/ui_design/dashboard/code.html)
- 스크립트 영역 최상단에 `const CONFIG_USE_TIMER = true;` 상수를 배치합니다.
- `DOMContentLoaded` 리스너에서 다음 처리를 추가합니다:
  - `localStorage.getItem('isInjecting') === 'true'` 검사: 참일 경우 `globalState.isInjecting = true`로 활성화하고, `CONFIG_USE_TIMER`가 활성화된 경우에만 완료 타이머를 구동합니다.
  - `localStorage.getItem('showCompleteModal') === 'true'` 검사: 참일 경우 즉시 완료 팝업(`openModal('complete')`)을 띄우고 해당 키를 초기화합니다.
- `navigateToAction(actionKey)` 함수 내부에서 주입 중(`localStorage.getItem('isInjecting') === 'true'`)일 때:
  - 이동하지 않고, 화면 내에 토스트 UI `"주입 중에서 수행할 수 없습니다"`를 띄우도록 차단합니다.
- 긴급 정지 및 완료 확인 시 `localStorage` 내 주입 관련 데이터(`isInjecting`, `injectingEndTime`)를 말끔히 비웁니다.
- 화면 내에 부드러운 애니메이션 효과를 가지는 `showToast(message)` 헬퍼 함수를 추가합니다.

### [Common Monitoring Script Component]

---

#### [MODIFY] 대시보드를 제외한 18개 서브 HTML 파일들
- 대상 파일 목록:
  1. `ui_design/add_injection/code.html`
  2. `ui_design/app_info/code.html`
  3. `ui_design/basal_setting/code.html`
  4. `ui_design/battery_change/code.html`
  5. `ui_design/ble_connect/code.html`
  6. `ui_design/dining/code.html`
  7. `ui_design/exercise/code.html`
  8. `ui_design/guidelines/code.html`
  9. `ui_design/history/code.html`
  10. `ui_design/infomation/code.html`
  11. `ui_design/infusionset_change/code.html`
  12. `ui_design/language_setting/code.html`
  13. `ui_design/main_setting/code.html`
  14. `ui_design/meal_injection/code.html`
  15. `ui_design/meal_setting/code.html`
  16. `ui_design/password/code.html`
  17. `ui_design/product/code.html`
  18. `ui_design/usage/code.html`
- 각 파일의 `<head>` 태그 맨 앞(또는 상단 영역)에 다음 공통 감시 스크립트를 삽입합니다:
  ```html
  <script>
    (function() {
      // 최종 빌드 시 false로 설정하여 시뮬레이션 타이머를 비활성화할 수 있습니다.
      const CONFIG_USE_TIMER = true; 
      
      const isInjecting = localStorage.getItem('isInjecting') === 'true';
      const currentPath = window.location.pathname;
      const preventPaths = ['meal_injection', 'add_injection', 'dining', 'exercise'];
      const isPreventPath = preventPaths.some(path => currentPath.includes(path));
      
      // 토스트 UI 표시 함수
      function showToast(message) {
        const toast = document.createElement('div');
        toast.className = 'fixed bottom-24 left-1/2 -translate-x-1/2 bg-slate-800/90 text-white text-[13px] px-5 py-3 rounded-full shadow-lg z-[9999] transition-all duration-300 opacity-0 transform translate-y-2 pointer-events-none whitespace-nowrap font-medium';
        toast.innerText = message;
        document.body.appendChild(toast);
        
        toast.offsetHeight; // force reflow
        toast.classList.remove('opacity-0', 'translate-y-2');
        toast.classList.add('opacity-100', 'translate-y-0');
        
        setTimeout(() => {
          toast.classList.remove('opacity-100', 'translate-y-0');
          toast.classList.add('opacity-0', 'translate-y-2');
          setTimeout(() => toast.remove(), 300);
        }, 2000);
      }
      
      // 1. 주입 중일 때 빠른 실행 화면 직접 진입 방어
      if (isInjecting && isPreventPath) {
        localStorage.setItem('showToastMsg', '주입 중에서 수행할 수 없습니다');
        window.location.href = '../dashboard/code.html';
        return;
      }
      
      // 2. 타이머 및 완료 감시 로직
      let activeTimer = null;
      
      function checkInjectingStatus() {
        const activeInjecting = localStorage.getItem('isInjecting') === 'true';
        if (!activeInjecting) {
          if (activeTimer) {
            clearTimeout(activeTimer);
            activeTimer = null;
          }
          return;
        }
        
        const endTime = parseInt(localStorage.getItem('injectingEndTime') || '0', 10);
        const now = Date.now();
        const useTimer = CONFIG_USE_TIMER && (localStorage.getItem('CONFIG_USE_TIMER') !== 'false');
        
        if (useTimer && endTime > 0) {
          if (now >= endTime) {
            triggerComplete();
          } else {
            const delay = endTime - now;
            if (activeTimer) clearTimeout(activeTimer);
            activeTimer = setTimeout(triggerComplete, delay);
          }
        }
      }
      
      function triggerComplete() {
        console.log('BLE 수신 시뮬레이션: BT_INJ_STOP_IND (0x3B) 주입 완료 수신');
        localStorage.setItem('isInjecting', 'false');
        localStorage.removeItem('injectingEndTime');
        localStorage.setItem('showCompleteModal', 'true');
        window.location.href = '../dashboard/code.html';
      }
      
      function init() {
        const pendingToast = localStorage.getItem('showToastMsg');
        if (pendingToast) {
          localStorage.removeItem('showToastMsg');
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => showToast(pendingToast));
          } else {
            showToast(pendingToast);
          }
        }
        checkInjectingStatus();
      }
      
      init();
      
      // 스토리지 상태 변경 실시간 모니터링
      window.addEventListener('storage', (e) => {
        if (e.key === 'isInjecting') {
          const updatedInjecting = localStorage.getItem('isInjecting') === 'true';
          if (updatedInjecting && isPreventPath) {
            localStorage.setItem('showToastMsg', '주입 중에서 수행할 수 없습니다');
            window.location.href = '../dashboard/code.html';
          } else if (!updatedInjecting && isInjecting && !isPreventPath) {
            // 외부에서 주입 완료(false)로 변경 시 대시보드로 복귀하여 완료 모달 노출
            localStorage.setItem('showCompleteModal', 'true');
            window.location.href = '../dashboard/code.html';
          }
        }
        if (e.key === 'isInjecting' || e.key === 'injectingEndTime' || e.key === 'CONFIG_USE_TIMER') {
          checkInjectingStatus();
        }
      });
    })();
  </script>
  ```

## Verification Plan

### Automated / Manual Tests
1. **타이머 제어(CONFIG_USE_TIMER = false) 동작 검증**:
   - `localStorage.setItem('CONFIG_USE_TIMER', 'false')`를 실행해 타이머를 끕니다.
   - 대시보드에서 주입을 수락한 뒤 5초가 지나도 완료 모달이 뜨지 않는지 확인합니다.
   - 이 상태에서 수동으로 `localStorage.setItem('isInjecting', 'false')`를 콘솔 혹은 다른 페이지에서 갱신했을 때, 대시보드로 돌아가며 완료 모달이 뜨는지 확인합니다. (실제 BLE `0x3B` 수신 시나리오 모사)
2. **토스트 UI 출력 검증**:
   - 주입 중에 대시보드의 빠른 실행 버튼을 누를 때, 화면 중앙 아래쪽에 `"주입 중에서 수행할 수 없습니다"` 토스트 팝업이 2초간 떴다가 부드럽게 사라지는지 확인합니다.
   - 주입 중에 뒤로 가기를 통해 `dining/code.html` 등으로 진입을 시도할 때, 대시보드로 튕겨나가며 동일한 토스트가 노출되는지 확인합니다.
3. **타 페이지에서의 완료 리다이렉션 검증**:
   - `CONFIG_USE_TIMER = true` 환경에서 주입 시작 후 '설정' 페이지로 이동하여 대기하다가, 5초 경과 시 자동으로 대시보드로 돌아와 완료 팝업이 노출되는지 확인합니다.
