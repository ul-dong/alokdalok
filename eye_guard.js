// 눈 지킴이 (웹): 앞카메라 + MediaPipe 얼굴 랜드마크로 거리·고개 각도를 잰다.
// 영상은 이 기기 안에서만 처리하고 저장하거나 어디로도 보내지 않는다.
// 발열을 줄이려고 낮은 해상도(320x240)·낮은 프레임(초당 5~10)으로 받고,
// 카메라를 계속 돌리지 않는다: 앱이 창을 열 때(open) video.play(), 2~3장을 detect()로 보고
// 창을 닫을 때(pause) video.pause(). 창 주기(넉넉 10초, 기준 가까이 3초, 경고 중 1.5초)는 앱이 정한다.
// 렉 줄이기: 얼굴 인식은 Web Worker(eye_worker.js)에서 한다. 웹은 화면 그리기·터치 처리와
// 자바스크립트가 한 스레드라서, 메인 스레드에서 인식하면 그동안(처음 준비는 수백 ms) 터치가 늦게 먹힌다.
// 메인 스레드는 영상 한 장을 ImageBitmap으로 떠서 넘기기만 한다. 일꾼을 못 쓰는 브라우저만 메인에서 한다.
(function () {
  // MediaPipe(구글, Apache 2.0) 파일을 앱과 같은 곳(mediapipe/)에 두고 쓴다 (외부 CDN에 기대지 않게)
  const CDN = new URL('mediapipe', document.baseURI).href;
  const MODEL = CDN + '/face_landmarker.task';
  let landmarker = null;
  let stream = null;
  let video = null;
  // 창이 열려 있는지 (열려 있을 때만 영상을 돌린다)
  let opened = false;
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

  // ---------- 일꾼 (Web Worker) ----------
  let worker = null; // null: 아직, false: 못 씀 (메인에서 인식)
  let workerReady = null;
  let seq = 0;
  const waiting = new Map();

  function call(msg, transfer) {
    return new Promise((resolve, reject) => {
      const id = ++seq;
      waiting.set(id, { resolve, reject });
      msg.id = id;
      worker.postMessage(msg, transfer || []);
    });
  }

  function startWorker() {
    if (worker !== null) return workerReady;
    if (typeof Worker === 'undefined' || typeof createImageBitmap === 'undefined') {
      worker = false;
      return null;
    }
    try {
      // 보통(classic) 일꾼: MediaPipe가 안에서 importScripts를 쓰므로 module 일꾼으로는 안 된다
      worker = new Worker(new URL('eye_worker.js', document.baseURI).href);
    } catch (e) {
      worker = false;
      return null;
    }
    worker.onmessage = (ev) => {
      const m = ev.data || {};
      const w = waiting.get(m.id);
      if (!w) return;
      waiting.delete(m.id);
      m.ok ? w.resolve(m) : w.reject(new Error(m.error));
    };
    worker.onerror = () => {
      // 일꾼을 못 띄움 (module worker 미지원 등): 메인 스레드로
      worker = false;
      for (const w of waiting.values()) w.reject(new Error('worker'));
      waiting.clear();
    };
    const t0 = performance.now();
    workerReady = call({ type: 'init', base: CDN }).then(
      () => {
        stats.initMs = performance.now() - t0;
      },
      (e) => {
        if (worker) worker.terminate();
        worker = false;
      },
    );
    return workerReady;
  }

  // 진단 칸에 보이는 숫자: 인식 한 번에 걸린 시간(ms), 메인 스레드를 막은 시간(ms), 어디서 인식하는지
  const stats = { where: '', lastMs: -1, maxMs: 0, mainMs: -1, initMs: -1, count: 0 };

  function note(ms, mainMs) {
    stats.lastMs = ms;
    stats.mainMs = mainMs;
    stats.count++;
    if (ms > stats.maxMs) stats.maxMs = ms;
  }

  function deg(r) {
    return (r * 180) / Math.PI;
  }

  // 홍채 4점([x, y] 0~1)과 고개 각도 행렬(4x4, 열 우선) → 크기·각도
  function measurePts(pts, mat, w, h) {
    if (!pts) return null;
    const d = (a, b) => Math.hypot((a[0] - b[0]) * w, (a[1] - b[1]) * h);
    // 홍채 지름 (양쪽 평균): 사람마다 거의 같아서(약 11.7mm) 거리 재기에 좋다
    const iris = (d(pts[0], pts[1]) + d(pts[2], pts[3])) / 2;
    let yaw = 0, pitch = 0, roll = 0;
    if (mat) {
      const R = (r, c) => mat[c * 4 + r];
      pitch = deg(Math.atan2(R(2, 1), R(2, 2)));
      yaw = deg(Math.atan2(-R(2, 0), Math.hypot(R(2, 1), R(2, 2))));
      roll = deg(Math.atan2(R(1, 0), R(0, 0)));
    }
    return { size: iris / w, yaw, pitch, roll };
  }

  function measure(res, w, h) {
    if (!res || !res.faceLandmarks || res.faceLandmarks.length === 0) return null;
    const p = res.faceLandmarks[0];
    if (p.length < 478) return null;
    const pts = [469, 471, 474, 476].map((i) => [p[i].x, p[i].y]);
    const t = res.facialTransformationMatrixes && res.facialTransformationMatrixes[0];
    return measurePts(pts, t && t.data ? Array.from(t.data) : null, w, h);
  }

  // 카메라 트랙이 끝났는지 (다른 앱이 카메라를 가져감, 브라우저가 뒤에서 끊음 등)
  function ended() {
    return !stream || stream.getVideoTracks().every((t) => t.readyState !== 'live');
  }

  function release() {
    if (stream) stream.getTracks().forEach((t) => t.stop());
    stream = null;
    if (video) {
      video.pause();
      video.srcObject = null;
    }
    video = null;
  }

  function fatal(message) {
    const e = new Error(message);
    e.fatal = true;
    return e;
  }

  window.alokEyeGuard = {
    // 창을 연다: 처음이면 카메라를 켜고 얼굴 인식기를 만든다, 아니면 멈춰 둔 영상을 다시 돌린다.
    // 잘 열리면 null, 실패하면 사람이 읽을 수 있는 메시지(문자열)로 resolve 한다.
    open: async function () {
      const my = gen;
      const stale = () => my !== gen;
      opened = true;
      try {
        // 살려 둔 스트림이 끊겼으면 놓고 새로 연다 (멈춘 영상만 계속 보게 되지 않게)
        if (stream && ended()) release();
        if (!stream) {
          if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            throw fatal('이 브라우저는 카메라를 쓸 수 없어요');
          }
          let s;
          try {
            s = await navigator.mediaDevices.getUserMedia({
              video: {
                facingMode: 'user',
                width: { ideal: 320 },
                height: { ideal: 240 },
                frameRate: { ideal: 5, max: 10 },
              },
              audio: false,
            });
          } catch (e) {
            const n = e && e.name;
            if (n === 'NotAllowedError' || n === 'SecurityError') {
              throw fatal('카메라 사용을 허용해 주세요');
            }
            if (n === 'NotFoundError' || n === 'OverconstrainedError') {
              throw fatal('앞카메라가 없어요');
            }
            throw e; // NotReadableError(다른 앱이 쓰는 중) 등: 다음 창에서 다시
          }
          if (stale()) {
            s.getTracks().forEach((t) => t.stop());
            return null;
          }
          stream = s;
          video = document.createElement('video');
          video.setAttribute('playsinline', '');
          video.muted = true;
          video.srcObject = stream;
        }
        await video.play();
        if (stale()) return null;
        // 인식기 준비: 일꾼에서 (못 쓰면 메인 스레드에서)
        const ready = startWorker();
        if (ready) await ready;
        if (stale()) return null;
        if (worker) {
          stats.where = '일꾼';
        } else if (!landmarker) {
          stats.where = '메인';
          const t0 = performance.now();
          landmarker = await makeLandmarker();
          stats.initMs = performance.now() - t0;
        }
        return null;
      } catch (e) {
        if (stale()) return null;
        opened = false;
        release();
        // '!'로 시작하면 카메라를 아예 쓸 수 없음 (눈 지킴이를 멈춤), 아니면 다음 창에서 다시
        if (e && e.fatal) return '!' + e.message;
        return String((e && e.message) || e);
      }
    },
    // 지금 프레임 한 장을 본다 (Promise): [size, yaw, pitch, roll] / 얼굴 없음 [] / 아직 볼 수 없음 null
    detect: async function () {
      if (!opened || !video || video.readyState < 2) return null;
      const w = video.videoWidth, h = video.videoHeight;
      try {
        if (worker) {
          const t0 = performance.now();
          const bmp = await createImageBitmap(video);
          const main = performance.now() - t0;
          if (!worker) {
            bmp.close();
            return null;
          }
          const r = await call({ type: 'detect', bitmap: bmp, ts: performance.now() }, [bmp]);
          note(r.ms, main);
          const m = measurePts(r.pts, r.mat, w, h);
          return m ? [m.size, m.yaw, m.pitch, m.roll] : [];
        }
        if (!landmarker) return null;
        const t0 = performance.now();
        const res = landmarker.detectForVideo(video, performance.now());
        const ms = performance.now() - t0;
        note(ms, ms);
        const r = measure(res, w, h);
        return r ? [r.size, r.yaw, r.pitch, r.roll] : [];
      } catch (e) {
        return null;
      }
    },
    // 진단 칸: [어디서, 마지막 인식 ms, 1회 최대 ms, 메인 스레드를 막은 ms, 준비 ms, 횟수]
    stats: function () {
      return [stats.where, stats.lastMs, stats.maxMs, stats.mainMs, stats.initMs, stats.count];
    },
    // 창을 닫는다: 영상을 멈춰 둔다 (카메라 스트림은 살려 두어 다음 창이 빨리 열린다)
    pause: function () {
      opened = false;
      if (video) video.pause();
    },
    // 카메라를 완전히 끈다 (놀이 화면을 벗어남, 또는 창마다 끄는 방식)
    stop: function () {
      gen++;
      opened = false;
      release();
    },
  };

  // 다른 탭으로 가면 카메라를 잠시 쉬게 한다 (배터리·발열). 돌아와도 창이 열려 있을 때만 다시 돌린다.
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && video) video.pause();
    else if (!document.hidden && video && opened) video.play().catch(() => {});
  });
})();
