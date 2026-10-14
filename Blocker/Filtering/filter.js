// Injected into the Instagram / YouTube web views at document end.
// __BLOCKER_RULES__ is replaced with the site's SiteRules as JSON before injection.
(function () {
  if (window.__blockerInstalled) return;
  window.__blockerInstalled = true;

  const rules = __BLOCKER_RULES__;
  const home = new URL(rules.homeURL).pathname || '/';

  // The rules come from a file anyone on the team edits, so a typo must not break the page:
  // drop any selector the browser can't parse (a stray brace could otherwise restyle everything).
  // Browsers auto-close a missing ] or ) when testing a selector, but inside a stylesheet the
  // open bracket swallows every rule after it, so check the pairs ourselves.
  function balanced(selector) {
    const open = [];
    let quote = null;
    for (const ch of selector) {
      if (quote) {
        if (ch === quote) quote = null;
      } else if (ch === '"' || ch === "'") {
        quote = ch;
      } else if (ch === '[' || ch === '(') {
        open.push(ch);
      } else if (ch === ']' || ch === ')') {
        if (open.pop() !== (ch === ']' ? '[' : '(')) return false;
      }
    }
    return quote === null && open.length === 0;
  }

  function validSelector(selector) {
    if (typeof selector !== 'string' || selector.trim() === '' || /[{}]/.test(selector)) return false;
    if (!balanced(selector)) return false;
    try {
      document.createDocumentFragment().querySelector(selector);
      return true;
    } catch (e) {
      return false;
    }
  }
  const hideSelectors = rules.hideSelectors.filter(validSelector);
  const collapseSelectors = rules.collapseSelectors.filter(validSelector);
  const viewerCloseSelector = validSelector(rules.viewerCloseSelector) ? rules.viewerCloseSelector : null;

  // 1. Hide links, and shrink feed items to a slim bar. CSS also applies to items loaded later.
  //    Collapsed items keep a small height: zero-height posts make Instagram's feed go blank.
  const css = hideSelectors.map((s) => s + ' { display: none !important; }');
  for (const s of collapseSelectors) {
    css.push(
      s + ' { height: 44px !important; min-height: 0 !important; overflow: hidden !important; position: relative !important; }',
      s + ' > * { visibility: hidden !important; }',
      s + '::after { content: "Reel hidden"; position: absolute; inset: 0; display: flex; align-items: center;' +
        ' justify-content: center; font: 13px -apple-system, sans-serif; color: #8e8e8e; }'
    );
  }
  const style = document.createElement('style');
  style.textContent = css.join('\n');
  (document.head || document.documentElement).appendChild(style);

  function post(message) {
    try {
      window.webkit.messageHandlers.blocker.postMessage(message);
    } catch (e) {}
  }

  // "Reel blocked" toast (plus a tap of haptic feedback from the app) on every block. The app's
  // counter goes up at most once every 3s, so one reel that fires several events counts once.
  let lastCounted = 0;
  let toast = null;
  let toastTimer = null;
  function showToast() {
    if (!toast) {
      toast = document.createElement('div');
      toast.textContent = 'Reel blocked';
      toast.style.cssText =
        'position:fixed;left:50%;bottom:96px;z-index:2147483647;pointer-events:none;' +
        'padding:10px 18px;border-radius:999px;background:#FFD43B;color:#14110F;' +
        'font:700 15px -apple-system,sans-serif;letter-spacing:-0.01em;' +
        'box-shadow:0 6px 20px rgba(0,0,0,.25);' +
        'transform:translate(-50%,16px) scale(.9);opacity:0;' +
        'transition:transform .25s cubic-bezier(.2,.9,.3,1.3),opacity .2s';
      document.documentElement.appendChild(toast);
    }
    toast.style.opacity = '1';
    toast.style.transform = 'translate(-50%,0) scale(1)';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translate(-50%,16px) scale(.9)';
    }, 1300);
  }
  window.__blockerToast = showToast; // the app calls this for blocks it makes itself

  function report() {
    const counted = Date.now() - lastCounted > 3000;
    if (counted) lastCounted = Date.now();
    post({ event: 'blocked', counted: counted });
    showToast();
  }

  // Tell the app when the page shows real content, so it can drop its loading screen.
  let ready = false;
  function signalReady() {
    if (ready) return;
    ready = true;
    post({ event: 'ready' });
  }
  const readySelector = validSelector(rules.readySelector) ? rules.readySelector : null;
  const readyStarted = Date.now();
  const readyTimer = setInterval(() => {
    if ((readySelector && document.querySelector(readySelector)) || Date.now() - readyStarted > 15000) {
      clearInterval(readyTimer);
      signalReady();
    }
  }, 150);
  if (!readySelector) {
    clearInterval(readyTimer);
    signalReady();
  }

  // Counts for the Home stats and the rule-health check: feed posts seen, reels hidden in the
  // feed (each post once), and which of our selectors matched anything. No names or links leave
  // the page, only counts and our own selectors.
  const seenPosts = new Set();
  const hiddenPosts = new Set();
  const matchedSelectors = new Set();
  let newPosts = 0;
  let newHidden = 0;
  let newMatched = [];
  function postId(article) {
    const link = article.querySelector('a[href*="/p/"], a[href*="/reel/"]');
    const match = link && link.getAttribute('href').match(/\/(p|reel)\/([^/?#]+)/);
    return match ? match[2] : null;
  }
  setInterval(() => {
    for (const article of document.querySelectorAll('article')) {
      const id = postId(article);
      if (!id) continue;
      if (!seenPosts.has(id)) {
        seenPosts.add(id);
        newPosts++;
      }
      if (!hiddenPosts.has(id) && collapseSelectors.some((s) => article.matches(s))) {
        hiddenPosts.add(id);
        newHidden++;
      }
    }
    for (const selector of hideSelectors.concat(collapseSelectors)) {
      if (!matchedSelectors.has(selector) && document.querySelector(selector)) {
        matchedSelectors.add(selector);
        newMatched.push(selector);
      }
    }
    if (newPosts || newHidden || newMatched.length) {
      post({ event: 'stats', posts: newPosts, hidden: newHidden, matched: newMatched });
      newPosts = 0;
      newHidden = 0;
      newMatched = [];
    }
  }, 3000);

  // 2. These sites are single-page apps, so most taps never reach the native navigation check.
  //    Watch the path ourselves and bounce off blocked pages.
  function isBlocked(path) {
    if (rules.allowedPaths.some((prefix) => path.startsWith(prefix))) return false;
    return rules.blockedPaths.some((part) => path.includes(part));
  }

  // Taps on links to blocked pages are stopped before the site starts navigating,
  // so the reels page never flashes up. This runs before the site's own click handlers.
  document.addEventListener('click', (e) => {
    const link = e.target.closest && e.target.closest('a[href]');
    if (!link) return;
    let url;
    try {
      url = new URL(link.getAttribute('href'), location.href);
    } catch (err) {
      return;
    }
    if (url.origin !== location.origin || rules.redirects[url.pathname]) return;
    if (!isBlocked(url.pathname)) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    report();
  }, true);

  // Fallback for navigation that doesn't come from a link tap.
  let bouncing = false;
  function check() {
    const path = location.pathname;

    const target = rules.redirects[path];
    if (target) {
      location.replace(target);
      return;
    }

    if (!isBlocked(path)) {
      bouncing = false;
      return;
    }
    if (bouncing) return;
    bouncing = true;
    report();

    // Go back to where the user was (e.g. the DM thread a reel was shared in), else home.
    if (history.length > 1) {
      history.back();
      setTimeout(() => {
        if (isBlocked(location.pathname)) location.replace(home);
      }, 500);
    } else {
      location.replace(home);
    }
  }

  for (const name of ['pushState', 'replaceState']) {
    const original = history[name];
    history[name] = function () {
      const result = original.apply(this, arguments);
      setTimeout(check, 0);
      return result;
    };
  }
  window.addEventListener('popstate', () => setTimeout(check, 0));
  setInterval(check, 1000); // safety net in case the site changes the URL some other way
  check();

  // 3. Videos. Allowed: everything on videoAllowedPaths (stories), and videos inside
  //    videoAllowedIn containers (normal feed posts) unless that post is collapsed as a reel.
  //    On singleVideoPaths (DM threads) the one reel the user tapped may play, but swiping to
  //    the next one is blocked. Any other video is stopped and the viewer it plays in is closed.
  if (rules.videoAllowedPaths) {
    const collapsed = collapseSelectors.join(', ');
    const allowedIn = (rules.videoAllowedIn || []).filter(validSelector).join(', ');
    const singleVideoPaths = rules.singleVideoPaths || [];

    let lastTap = { time: 0, target: null };
    document.addEventListener('click', (e) => {
      lastTap = { time: Date.now(), target: e.target };
    }, true);

    function closeViewer() {
      const close = viewerCloseSelector && document.querySelector(viewerCloseSelector);
      if (close) close.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }

    function stop(video, alsoCloseViewer) {
      video.muted = true;
      video.pause();
      report();
      if (alsoCloseViewer) closeViewer();
    }

    // The full-screen viewer a video plays in: its nearest fixed-position ancestor.
    function overlayOf(video) {
      for (let el = video.parentElement; el && el !== document.body; el = el.parentElement) {
        if (getComputedStyle(el).position === 'fixed') return el;
      }
      return null;
    }

    // The one reel the user opened from a DM, and the swipe lock on its viewer.
    let allowed = null; // { video, src, overlay }
    function blockSwipe(e) {
      if (e.pointerType && e.pointerType !== 'touch') return;
      e.preventDefault();
      e.stopPropagation();
    }
    function lockSwipe(overlay) {
      overlay.addEventListener('touchmove', blockSwipe, { capture: true, passive: false });
      overlay.addEventListener('pointermove', blockSwipe, { capture: true, passive: false });
    }
    function release() {
      if (allowed && allowed.overlay) {
        allowed.overlay.removeEventListener('touchmove', blockSwipe, { capture: true });
        allowed.overlay.removeEventListener('pointermove', blockSwipe, { capture: true });
      }
      allowed = null;
    }
    // Viewer closed (video gone or hidden) or the user left the chat: unlock.
    setInterval(() => {
      if (!allowed) return;
      const gone = !allowed.video.isConnected || allowed.video.getBoundingClientRect().height === 0;
      const left = !singleVideoPaths.some((p) => location.pathname.startsWith(p));
      if (gone || left) release();
    }, 500);

    function isSameReel(video) {
      return allowed && allowed.video === video && allowed.src === video.currentSrc;
    }

    document.addEventListener('play', (e) => {
      const video = e.target;
      if (!(video instanceof HTMLVideoElement)) return;
      const path = location.pathname;
      if (rules.videoAllowedPaths.some((prefix) => path.startsWith(prefix))) return;
      if (collapsed && video.closest(collapsed)) return stop(video, false);
      if (allowedIn && video.closest(allowedIn)) return;

      if (singleVideoPaths.some((prefix) => path.startsWith(prefix))) {
        if (isSameReel(video)) return;
        // A fresh tap outside the open viewer (e.g. on a reel in the chat) opens a new one.
        const tappedOutside = Date.now() - lastTap.time < 2000 &&
          !(allowed && allowed.overlay && allowed.overlay.contains(lastTap.target));
        if (tappedOutside) {
          release();
          allowed = { video: video, src: video.currentSrc, overlay: overlayOf(video) };
          if (allowed.overlay) lockSwipe(allowed.overlay);
          debug('reelAllowed', { overlay: allowed.overlay ? allowed.overlay.tagName.toLowerCase() + ' ' +
            Math.round(allowed.overlay.getBoundingClientRect().height) + 'px' : null });
          return;
        }
        // Swiped (or autoplayed) to another reel: stop it and close the viewer.
        stop(video, true);
        release();
        return;
      }

      stop(video, true);
    }, true);
  }

  function debug(kind, data) {
    try {
      const payload = Object.assign({ kind: kind, path: location.pathname }, data || {});
      window.webkit.messageHandlers.blockerDebug.postMessage(JSON.stringify(payload));
    } catch (e) {} // only debug builds listen
  }
})();
