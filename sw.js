const CACHE='motoca-v1';
const ARQUIVOS=['./','index.html','three.min.js','manifest.json','icon-192.png','icon-512.png','icon-maskable-512.png'];
self.addEventListener('install',e=>{ e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ARQUIVOS))); self.skipWaiting(); });
self.addEventListener('activate',e=>{ e.waitUntil(caches.keys().then(n=>Promise.all(n.filter(k=>k.startsWith('motoca-')&&k!==CACHE).map(k=>caches.delete(k))))); self.clients.claim(); });
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET') return;
  const u=new URL(e.request.url);
  if(u.origin!==location.origin||!u.pathname.includes('/motoca')) return;
  e.respondWith(fetch(e.request).then(r=>{
    if(r.ok){ const c=r.clone(); caches.open(CACHE).then(cc=>cc.put(e.request,c)); }
    return r;
  }).catch(()=>caches.match(e.request).then(r=>r||caches.match('index.html'))));
});
