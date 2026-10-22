// 알록달록 꼬마 놀이터 - 오프라인 서비스 워커
// - 설치할 때 offline_files.json 에 적힌 파일(앱, 글꼴, 소리, 녹음, MediaPipe)을 모두 미리 담는다.
// - 그 뒤로는 담아 둔 파일을 먼저 쓰고, 없으면 네트워크에서 받아 담는다.
// - 페이지(index.html)는 네트워크를 먼저 시도하고, 연결이 없으면 담아 둔 것을 연다.
// tool/build_web.sh 가 빌드마다 이 파일 끝에 빌드 번호를 붙여서, 새 버전이 나오면 다시 설치된다.
'use strict';

const PREFIX = 'alokdalok-';
const LIST = 'offline_files.json';

async function readList() {
  try {
    const res = await fetch(LIST, { cache: 'no-store' });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) {
    return null;
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const list = await readList();
    const version = (list && list.version) || 'dev';
    const cache = await caches.open(PREFIX + version);
    const files = ['./', ...((list && list.files) || [])];
    // 한 번에 너무 많이 받지 않게 나눠서 담는다. 하나라도 실패하면 설치를 다시 시도하게 둔다.
    for (let i = 0; i < files.length; i += 8) {
      await cache.addAll(files.slice(i, i + 8).map((f) => new Request(f, { cache: 'reload' })));
    }
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const list = await readList();
    const keep = PREFIX + ((list && list.version) || 'dev');
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== keep) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

async function currentCache() {
  const keys = (await caches.keys()).filter((k) => k.startsWith(PREFIX));
  return caches.open(keys.length ? keys[keys.length - 1] : PREFIX + 'dev');
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;
  // 같은 곳의 파일과, 빠진 글자가 있을 때 Flutter 가 받는 구글 글꼴만 다룬다. 카메라 영상 등은 관여하지 않는다.
  if (!sameOrigin && url.hostname !== 'fonts.gstatic.com') return;
  if (sameOrigin && url.pathname.endsWith('/' + LIST)) return;

  if (req.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const res = await fetch(req);
        if (res.ok) (await currentCache()).put('./', res.clone());
        return res;
      } catch (e) {
        return (await caches.match('./', { ignoreSearch: true })) ||
          (await caches.match('index.html', { ignoreSearch: true })) ||
          Response.error();
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const hit = await caches.match(req, { ignoreSearch: true });
    if (hit) return hit;
    const res = await fetch(req);
    if (res.ok || res.type === 'opaque') (await currentCache()).put(req, res.clone());
    return res;
  })());
});

// build adee12f677d4
