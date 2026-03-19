<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Site Viewer — Local Mini Browser</title>
<style>
  :root{--bg:#0f1720;--card:#0b1220;--muted:#9aa4b2;--accent:#4f46e5;color-scheme:dark}
  body{font-family:Inter,system-ui,Segoe UI,Roboto,Helvetica,Arial; margin:0;min-height:100vh;background:linear-gradient(180deg,#071028 0%, #07172a 100%);color:#e6eef8;display:flex;flex-direction:column}
  header{padding:18px 20px;display:flex;gap:12px;align-items:center}
  h1{font-size:16px;margin:0}
  .controls{display:flex;gap:8px;flex:1}
  input[type="url"]{flex:1;padding:10px 12px;border-radius:8px;border:1px solid rgba(255,255,255,0.06);background:transparent;color:inherit;outline:none}
  button{background:var(--accent);border:none;padding:10px 12px;border-radius:8px;color:white;cursor:pointer}
  button.secondary{background:transparent;border:1px solid rgba(255,255,255,0.06)}
  label.small{font-size:12px;color:var(--muted);margin-left:8px;display:flex;align-items:center;gap:6px}
  main{display:grid;grid-template-columns:320px 1fr;gap:12px;padding:12px}
  aside{background:rgba(255,255,255,0.02);padding:12px;border-radius:10px;min-height:60vh;overflow:auto}
  .iframeWrap{background:#fff;border-radius:8px;overflow:hidden;min-height:60vh;border:1px solid rgba(0,0,0,0.1)}
  iframe{width:100%;height:100%;min-height:60vh;border:0;display:block}
  .list{margin-top:8px}
  .item{display:flex;justify-content:space-between;padding:8px;border-radius:6px;align-items:center}
  .item a{color:var(--muted);text-decoration:none;max-width:200px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .foot{padding:12px;text-align:center;color:var(--muted);font-size:13px}
  .warning{background:#3b1f1f;padding:10px;border-radius:8px;color:#ffdede;margin-top:8px}
</style>
</head>
<body>
<header>
  <h1>Site Viewer</h1>
  <div class="controls">
    <input id="urlInput" type="url" placeholder="Enter a website URL (e.g. example.com or https://example.com)">
    <button id="goBtn">Load</button>
    <button id="openBtn" class="secondary">Open in new tab</button>
    <button id="bookmarkBtn" class="secondary" title="Save current URL">★</button>
    <label class="small"><input id="sandboxToggle" type="checkbox"> Use iframe sandbox</label>
  </div>
</header>

<main>
  <aside>
    <strong>History</strong>
    <div id="history" class="list"></div>

    <strong style="margin-top:12px;display:block">Bookmarks</strong>
    <div id="bookmarks" class="list"></div>

    <div class="warning" id="note">
      Note: Many sites (banks, Google, most major sites) block embedding. If the page looks blank or broken, use "Open in new tab".
    </div>
  </aside>

  <section>
    <div style="display:flex;gap:8px;align-items:center;margin-bottom:8px">
      <div style="flex:1;color:var(--muted);font-size:13px" id="status">Ready.</div>
      <button id="refreshBtn" class="secondary">Refresh iframe</button>
      <button id="clearBtn" class="secondary">Clear history</button>
    </div>

    <div class="iframeWrap" id="frameContainer">
      <iframe id="viewer" srcdoc="<p style='padding:18px;color:#333;font-family:Arial'>Enter a URL above and press Load to view a site here.</p>"></iframe>
    </div>
    <div class="foot">Saved locally in your browser (no server). Works best for sites that allow framing.</div>
  </section>
</main>

<script>
(function(){
  const urlInput = document.getElementById('urlInput');
  const goBtn = document.getElementById('goBtn');
  const openBtn = document.getElementById('openBtn');
  const bookmarkBtn = document.getElementById('bookmarkBtn');
  const viewer = document.getElementById('viewer');
  const historyEl = document.getElementById('history');
  const bookmarksEl = document.getElementById('bookmarks');
  const status = document.getElementById('status');
  const refreshBtn = document.getElementById('refreshBtn');
  const clearBtn = document.getElementById('clearBtn');
  const sandboxToggle = document.getElementById('sandboxToggle');

  const STORAGE = { H: 'siteviewer_history_v1', B: 'siteviewer_bookmarks_v1' };
  const maxHistory = 50;

  function normUrl(raw) {
    if (!raw) return '';
    raw = raw.trim();
    // if user typed only hostname like example.com
    if (!/^([a-zA-Z][a-zA-Z0-9+.-]*:)?\/\//.test(raw)) {
      raw = 'https://' + raw;
    }
    try {
      return (new URL(raw)).toString();
    } catch (e) {
      return '';
    }
  }

  function saveHistory(url) {
    if(!url) return;
    const arr = JSON.parse(localStorage.getItem(STORAGE.H) || '[]');
    // remove duplicate
    const filtered = arr.filter(u => u !== url);
    filtered.unshift(url);
    filtered.splice(maxHistory);
    localStorage.setItem(STORAGE.H, JSON.stringify(filtered));
    renderHistory();
  }

  function loadHistory(){ renderHistory(); }
  function loadBookmarks(){ renderBookmarks(); }

  function renderHistory(){
    const arr = JSON.parse(localStorage.getItem(STORAGE.H) || '[]');
    historyEl.innerHTML = arr.length ? arr.map(u=>`
      <div class="item">
        <a href="#" data-url="${u}" title="${u}">${u}</a>
        <button data-url="${u}" class="btnDel">x</button>
      </div>`).join('') : '<div style="color:var(--muted);padding:8px">No history yet</div>';
  }

  function renderBookmarks(){
    const arr = JSON.parse(localStorage.getItem(STORAGE.B) || '[]');
    bookmarksEl.innerHTML = arr.length ? arr.map(u=>`
      <div class="item">
        <a href="#" data-url="${u}" title="${u}">${u}</a>
        <button data-url="${u}" class="btnDel">x</button>
      </div>`).join('') : '<div style="color:var(--muted);padding:8px">No bookmarks</div>';
  }

  // attach listeners for dynamic lists
  function listClickHandler(e){
    const a = e.target.closest('a[data-url]');
    if (a) {
      e.preventDefault();
      const u = a.getAttribute('data-url');
      urlInput.value = u;
      loadURL(u);
      return;
    }
    const btn = e.target.closest('button[data-url]');
    if (btn) {
      const u = btn.getAttribute('data-url');
      // detect which list
      const parent = btn.closest('#bookmarks') ? STORAGE.B : STORAGE.H;
      let arr = JSON.parse(localStorage.getItem(parent) || '[]');
      arr = arr.filter(x=>x !== u);
      localStorage.setItem(parent, JSON.stringify(arr));
      renderHistory(); renderBookmarks();
    }
  }
  historyEl.addEventListener('click', listClickHandler);
  bookmarksEl.addEventListener('click', listClickHandler);

  // load into iframe
  let lastLoaded = '';
  function loadURL(raw) {
    const u = normUrl(raw);
    if(!u){ status.textContent = 'Invalid URL'; return; }
    urlInput.value = u;
    status.textContent = 'Loading… ' + u;
    // set sandbox attribute if toggled
    if (sandboxToggle.checked) {
      viewer.setAttribute('sandbox','allow-forms allow-scripts allow-popups allow-modals');
    } else {
      viewer.removeAttribute('sandbox');
    }

    // attempt to display in iframe
    viewer.src = u;
    lastLoaded = u;
    saveHistory(u);

    // set a timeout to detect likely blocked/failed loads (not perfect)
    clearTimeout(window.__sv_check);
    let loaded = false;
    function onLoad(){
      loaded = true;
      // Try to guess whether content is visible. Note: cross-origin pages can't be inspected for security reasons.
      status.textContent = 'Loaded: ' + u;
      viewer.removeEventListener('load', onLoad);
      clearTimeout(window.__sv_check);
    }
    viewer.addEventListener('load', onLoad);

    // if no load event within 6s, warn user (not definitive)
    window.__sv_check = setTimeout(()=>{
      if (!loaded) {
        status.textContent = 'Load timeout — the site may block framing. Try "Open in new tab".';
      }
    }, 6000);
  }

  // click handlers
  goBtn.addEventListener('click', ()=> loadURL(urlInput.value));
  urlInput.addEventListener('keydown', (e)=> { if(e.key === 'Enter') loadURL(urlInput.value); });

  openBtn.addEventListener('click', ()=>{
    const u = normUrl(urlInput.value) || lastLoaded || urlInput.placeholder;
    if (!u) { status.textContent = 'No URL to open'; return; }
    window.open(u, '_blank', 'noopener,noreferrer');
  });

  bookmarkBtn.addEventListener('click', ()=>{
    const u = normUrl(urlInput.value) || lastLoaded;
    if (!u) { status.textContent = 'No URL to bookmark'; return; }
    const arr = JSON.parse(localStorage.getItem(STORAGE.B) || '[]');
    if (!arr.includes(u)) arr.unshift(u);
    localStorage.setItem(STORAGE.B, JSON.stringify(arr.slice(0,100)));
    renderBookmarks();
    status.textContent = 'Bookmarked';
  });

  refreshBtn.addEventListener('click', ()=> {
    if (lastLoaded) {
      viewer.src = lastLoaded;
      status.textContent = 'Refreshing…';
    } else status.textContent = 'Nothing loaded yet';
  });

  clearBtn.addEventListener('click', ()=>{
    localStorage.removeItem(STORAGE.H);
    renderHistory();
    status.textContent = 'History cleared';
  });

  // init
  loadHistory(); loadBookmarks();

  // quick paste helper: if user pastes a URL with leading whitespace, normalize
  urlInput.addEventListener('paste', (e)=>{
    setTimeout(()=>{ urlInput.value = urlInput.value.trim(); }, 10);
  });

  // helpful tip: if you want to view a local HTML file, drag it into the iframe by using "Open in new tab" on the file or enter file:// (browser may block)
})();
</script>
</body>
</html>