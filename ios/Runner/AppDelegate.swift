import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications 플러그인을 위한 설정
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }
     
    // iOS 10+ 알림 권한 설정
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // iOS 27+ UIScene 라이프사이클: 플러그인 등록은 엔진 초기화 콜백에서 수행
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // 화면 방향 정책
  // - 폰 / 접힌 폴더블(짧은 변 < 600pt): 세로 고정
  // - 펼친 폴더블 / 태블릿(짧은 변 ≥ 600pt): 모든 방향 허용
  // 펼친 iPhone Duo의 창 모드에서는 앱이 방향을 프로그램으로 바꿀 수 없어서
  // (UISceneErrorDomain 101) Dart가 아니라 여기서 시스템 질의에 답한다.
  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    let bounds = window?.windowScene?.screen.bounds ?? window?.bounds ?? UIScreen.main.bounds
    let shortestSide = min(bounds.width, bounds.height)
    return shortestSide >= 600 ? .all : .portrait
  }
}
