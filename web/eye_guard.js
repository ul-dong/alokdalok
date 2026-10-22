// 눈 지킴이 (웹): 앞카메라 + MediaPipe 얼굴 랜드마크로 거리·고개 각도를 잰다.
// 영상은 이 기기 안에서만 처리하고 저장하거나 어디로도 보내지 않는다.
// 발열을 줄이려고 낮은 해상도(320x240)·낮은 프레임(초당 5~10)으로 받고,
// 평소 1.5초, 기준에 가까우면 0.5초에 한 번만 살펴본다 (간격은 앱이 setInterval로 정한다).
(function () {
  // MediaPipe(구글, Apache 2.0) 파일을 앱과 같은 곳(mediapipe/)에 두고 쓴다 (외부 CDN에 기대지 않게)
  const CDN = new URL('mediapipe', document.baseURI).href;
  const MODEL = CDN + '/face_landmarker.task';
  let interval = 1500;

  let landmarker = null;
  let stream = null;
  let video = null;
  let timer = null;
  let running = false;
  let tick = null;
  let lastRun = 0;
  // 켜고 끌 때마다 늘어난다: 카메라를 여는 사이에 꺼졌으면 연 카메라를 바로 닫는다
  let gen = 0;

  async function makeLandmarker() {
    const vision = await import(CDN + '/vision_bundle.mjs');
    const files = await vision.FilesetResolver.forVisionTasks(CDN + '/wasm');
    const opts = (delegate) => ({
      baseOptions: { modelAssetPath: MODEL, delegate },
      runningMode: 'VIDEO',
      numFaces: 1,
      outputFacialTransformationMatrixes: true,
    });
    try {
      return await vision.FaceLandmarker.createFromOptions(files, opts('GPU'));
    } catch (e) {
      return await vision.FaceLandmarker.createFromOptions(files, opts('CPU'));
    }
  }

  function deg(r) {
    return (r * 180) / Math.PI;
  }

  function measure(res, w, h) {
    if (!res || !res.faceLandmarks || res.faceLandmarks.length === 0) return null;
    const p = res.faceLandmarks[0];
    if (p.length < 478) return null;
    const d = (a, b) => Math.hypot((p[a].x - p[b].x) * w, (p[a].y - p[b].y) * h);
    // 홍채 지름 (양쪽 평균): 사람마다 거의 같아서(약 11.7mm) 거리 재기에 좋다
    const iris = (d(469, 471) + d(474, 476)) / 2;
    let yaw = 0, pitch = 0, roll = 0;
    const m = res.facialTransformationMatrixes && res.facialTransformationMatrixes[0];
    if (m && m.data) {
      const R = (r, c) => m.data[c * 4 + r];
      pitch = deg(Math.atan2(R(2, 1), R(2, 2)));
      yaw = deg(Math.atan2(-R(2, 0), Math.hypot(R(2, 1), R(2, 2))));
      roll = deg(Math.atan2(R(1, 0), R(0, 0)));
    }
    return { size: iris / w, yaw, pitch, roll };
  }

  window.alokEyeGuard = {
    // onFace(size, yaw, pitch, roll) / onNoFace() / onError(message)
    start: async function (onFace, onNoFace, onError) {
      if (running) return;
      running = true;
      const my = ++gen;
      const stale = () => my !== gen;
      try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
          throw new Error('이 브라우저는 카메라를 쓸 수 없어요');
        }
        const s = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: 'user',
            width: { ideal: 320 },
            height: { ideal: 240 },
            frameRate: { ideal: 5, max: 10 },
          },
          audio: false,
        });
        if (stale()) {
          s.getTracks().forEach((t) => t.stop());
          return;
        }
        stream = s;
        video = document.createElement('video');
        video.setAttribute('playsinline', '');
        video.muted = true;
        video.srcObject = stream;
        await video.play();
        if (stale()) return;
        if (!landmarker) landmarker = await makeLandmarker();
        if (stale()) return;
        tick = () => {
          if (!running) return;
          lastRun = performance.now();
          try {
            if (video.readyState >= 2) {
              const r = measure(
                landmarker.detectForVideo(video, performance.now()),
                video.videoWidth,
                video.videoHeight,
              );
              if (r) onFace(r.size, r.yaw, r.pitch, r.roll);
              else onNoFace();
            }
          } catch (e) {}
          timer = setTimeout(tick, interval);
        };
        tick();
      } catch (e) {
        if (stale()) return;
        running = false;
        const msg = e && e.name === 'NotAllowedError'
          ? '카메라 사용을 허용해 주세요'
          : String((e && e.message) || e);
        onError(msg);
        this.stop();
      }
    },
    // 살펴보는 간격(ms). 다음 검사부터 적용된다.
    setInterval: function (ms) {
      interval = Math.max(200, Number(ms) || 1500);
      // 이미 잡아 둔 다음 검사를 새 간격에 맞춰 다시 잡는다
      if (running && timer && tick) {
        clearTimeout(timer);
        timer = setTimeout(tick, Math.max(0, lastRun + interval - performance.now()));
      }
    },
    stop: function () {
      gen++;
      running = false;
      if (timer) clearTimeout(timer);
      timer = null;
      tick = null;
      if (stream) stream.getTracks().forEach((t) => t.stop());
      stream = null;
      if (video) video.srcObject = null;
      video = null;
    },
  };

  // 다른 탭으로 가면 카메라를 잠시 쉬게 한다 (배터리·발열)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && video) video.pause();
    else if (!document.hidden && video) video.play().catch(() => {});
  });
})();
