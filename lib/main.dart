import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'services/database/local_db.dart';
import 'services/sync/basal_sync_controller.dart';

void main() async {
  // 1. Flutter 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 2. SQLite 로컬 DB 인스턴스 싱글톤 생성 및 스키마 초기화
  final sqfliteDb = SqflitePumpDatabase();
  try {
    await sqfliteDb.init();
  } catch (e) {
    print("SQLite DB 초기화 중 치명적 에러 발생: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        pumpDatabaseProvider.overrideWithValue(sqfliteDb),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealUs Pump Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
      ),
      home: const WebViewHomeScreen(),
    );
  }
}

class WebViewHomeScreen extends StatefulWidget {
  const WebViewHomeScreen({super.key});

  @override
  State<WebViewHomeScreen> createState() => _WebViewHomeScreenState();
}

class _WebViewHomeScreenState extends State<WebViewHomeScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    // WebViewController 초기화 및 설정
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8FAFA))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            _controller.runJavaScript('''
              (function() {
                // 1. 기존 메타 뷰포트를 반응형 지원하도록 강제 조정 또는 생성
                var viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                  viewport = document.createElement('meta');
                  viewport.name = 'viewport';
                  document.head.appendChild(viewport);
                }
                viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

                // 2. 비례 스케일링을 위한 CSS 룰 정의 (body 직접 scale)
                var style = document.createElement('style');
                style.type = 'text/css';
                style.innerHTML = `
                  html {
                    width: 100% !important;
                    height: 100% !important;
                    overflow: hidden !important;
                    background-color: #f8fafa !important;
                    margin: 0 !important;
                    padding: 0 !important;
                  }
                  body {
                    transform-origin: top left !important;
                    position: absolute !important;
                    top: 0 !important;
                    left: 0 !important;
                    margin: 0 !important;
                    box-shadow: none !important;
                    border: none !important;
                    border-radius: 0 !important;
                    overflow: hidden !important;
                    display: flex !important;
                    flex-direction: column !important;
                  }
                  /* 메인 콘텐츠 스크롤 영역 고정 확보 */
                  main {
                    flex: 1 !important;
                    overflow-y: auto !important;
                    -webkit-overflow-scrolling: touch !important;
                  }
                  /* 하단 고정 요소들을 최하단에 절대 좌표로 붙여 짤림 현상 방지 */
                  nav, footer, .fixed.bottom-0 {
                    position: absolute !important;
                    bottom: 0 !important;
                    left: 0 !important;
                    width: 100% !important;
                    transform: none !important;
                    z-index: 50 !important;
                  }
                  /* 특정 fixed 팝업들이 깨지지 않도록 scale 콘텍스트 안에 강제 */
                  .modal-overlay {
                    position: absolute !important;
                    width: 100% !important;
                    height: 100% !important;
                    left: 0 !important;
                    top: 0 !important;
                  }
                `;
                document.head.appendChild(style);

                // 3. 동적 비례 계산 및 새로고침 바인딩
                function adjustScale() {
                  var body = document.body;
                  if (!body) return;

                  // 기본 디자인 가로 기준 감지
                  var baseW = 390;

                  if (body.classList.contains('w-[393px]') || body.classList.contains('w-393')) {
                    baseW = 393;
                  } else if (body.classList.contains('w-[390px]') || body.classList.contains('w-390')) {
                    baseW = 390;
                  }

                  var winW = window.innerWidth;
                  var winH = window.innerHeight;

                  // 가로폭 기준 비례 스케일 계산
                  var scale = winW / baseW;
                  // 세로 높이는 기기 가용 세로 높이에 스케일 역산 적용
                  var targetH = winH / scale;

                  // body에 스타일 주입 (!important로 기존 고정 높이 오버라이드)
                  body.style.setProperty('width', baseW + 'px', 'important');
                  body.style.setProperty('height', targetH + 'px', 'important');
                  body.style.setProperty('max-height', 'none', 'important');
                  body.style.setProperty('min-height', targetH + 'px', 'important');
                  body.style.setProperty('transform', 'scale(' + scale + ')', 'important');
                }

                function bindRefreshButton() {
                  var refreshBtn = document.getElementById('btn-refresh');
                  if (refreshBtn) {
                    // 중복 바인딩 방지
                    if (!refreshBtn.dataset.boundRefresh) {
                      refreshBtn.dataset.boundRefresh = 'true';
                      refreshBtn.addEventListener('click', function() {
                        setTimeout(function() {
                          window.location.reload();
                        }, 400); // 회전 애니메이션 이후 새로고침 실행
                      });
                    }
                  }
                }

                window.addEventListener('resize', adjustScale);
                adjustScale();
                bindRefreshButton();
                
                // 동적 로딩을 보정하기 위한 지연 처리
                setTimeout(function() {
                  adjustScale();
                  bindRefreshButton();
                }, 100);
                setTimeout(adjustScale, 300);
                setTimeout(adjustScale, 700);
              })();
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadFlutterAsset('ui_design/ble_connect/code.html');

    // 안드로이드 플랫폼 관련 디버그 및 파일 액세스 활성화
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          if (context.mounted) {
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
