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

_flutter.loader.load();
