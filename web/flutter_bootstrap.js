{{flutter_js}}
{{flutter_build_config}}

// 오프라인: Flutter 기본 서비스 워커(flutter_service_worker.js)는 이제 스스로 등록을 지우는 빈 껍데기라서,
// 직접 만든 offline_sw.js 를 쓴다. 미리 담을 파일 목록(offline_files.json)은 tool/build_web.sh 가 만든다.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('offline_sw.js').catch(function (e) {
      console.warn('알록달록: 오프라인 준비 실패', e);
    });
  });
}

// 앱은 body 전체가 아니라 안전 영역 안의 #app-host 에 띄운다 (web/index.html 참고).
// 이렇게 하면 Flutter가 viewport 메타(viewport-fit=cover)를 바꿔 쓰지도 않는다.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.getElementById('app-host'),
    });
    await appRunner.runApp();
  },
});
