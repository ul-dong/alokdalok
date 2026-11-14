// 눈 지킴이 (웹) 얼굴 인식 일꾼(Web Worker): MediaPipe 얼굴 랜드마크를 화면(메인 스레드) 밖에서 돌린다.
// 웹은 화면 그리기와 터치 처리가 한 스레드라서, 인식(한 번에 수십 ms, 처음 준비는 수백 ms)을
// 메인 스레드에서 하면 그동안 터치가 늦게 먹힌다. 영상 한 장(ImageBitmap)만 받아서 숫자만 돌려준다.
// 보통(classic) 일꾼으로 띄운다: MediaPipe가 importScripts를 쓴다. vision_bundle.mjs는 import()로 부른다.
// 영상은 이 기기 안에서만 처리하고 저장하거나 어디로도 보내지 않는다.
let landmarker = null;
let making = null;

async function make(base) {
  const vision = await import(base + '/vision_bundle.mjs');
  const files = await vision.FilesetResolver.forVisionTasks(base + '/wasm');
  const opts = (delegate) => ({
    baseOptions: { modelAssetPath: base + '/face_landmarker.task', delegate },
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

self.onmessage = async (ev) => {
  const m = ev.data || {};
  try {
    if (m.type === 'init') {
      making = making || make(m.base);
      landmarker = await making;
      self.postMessage({ id: m.id, ok: true });
    } else if (m.type === 'detect') {
      const bmp = m.bitmap;
      try {
        if (!landmarker) landmarker = await making;
        const t0 = performance.now();
        const res = landmarker.detectForVideo(bmp, m.ts);
        const ms = performance.now() - t0;
        // 결과에서 필요한 숫자만 꺼내 보낸다 (얼굴 점 478개 중 홍채 4점 + 고개 각도 행렬)
        let pts = null, mat = null;
        const p = res && res.faceLandmarks && res.faceLandmarks[0];
        if (p && p.length >= 478) {
          pts = [469, 471, 474, 476].map((i) => [p[i].x, p[i].y]);
          const t = res.facialTransformationMatrixes && res.facialTransformationMatrixes[0];
          if (t && t.data) mat = Array.from(t.data);
        }
        self.postMessage({ id: m.id, ok: true, pts, mat, ms });
      } finally {
        if (bmp && bmp.close) bmp.close();
      }
    }
  } catch (e) {
    self.postMessage({ id: m.id, ok: false, error: String((e && e.message) || e) });
  }
};
