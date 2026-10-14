// Injected into the Instagram / YouTube web views at document end.
// __BLOCKER_RULES__ is replaced with the site's SiteRules as JSON before injection.
(function () {
  if (window.__blockerInstalled) return;
  window.__blockerInstalled = true;

  const rules = __BLOCKER_RULES__;
  const home = new URL(rules.homeURL).pathname || '/';

  // 1. Hide links, and shrink feed items to a slim bar. CSS also applies to items loaded later.
  //    Collapsed items keep a small height: zero-height posts make Instagram's feed go blank.
  const css = rules.hideSelectors.map((s) => s + ' { display: none !important; }');
  for (const s of rules.collapseSelectors) {
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

  // Small "Reel blocked" toast, and tells the app to count it (at most once every 3s).
  let lastReport = 0;
  function report() {
    if (Date.now() - lastReport < 3000) return;
    lastReport = Date.now();
    try {
      window.webkit.messageHandlers.blocker.postMessage('blocked');
    } catch (e) {}

    const toast = document.createElement('div');
    toast.textContent = 'Reel blocked';
    toast.style.cssText =
      'position:fixed;left:50%;bottom:90px;transform:translateX(-50%);z-index:2147483647;' +
      'padding:8px 14px;border-radius:16px;background:rgba(0,0,0,.8);color:#fff;' +
      'font:600 14px -apple-system,sans-serif;pointer-events:none;transition:opacity .4s';
    document.documentElement.appendChild(toast);
    setTimeout(() => (toast.style.opacity = '0'), 1200);
    setTimeout(() => toast.remove(), 1700);
  }

  // 2. These sites are single-page apps, so most taps never reach the native navigation check.
  //    Watch the path ourselves and bounce off blocked pages.
  function isBlocked(path) {
    if (rules.allowedPaths.some((prefix) => path.startsWith(prefix))) return false;
    return rules.blockedPaths.some((part) => path.includes(part));
  }

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

  // 3. Some viewers play reels without changing the URL (e.g. a reel opened from a DM).
  //    Stop any video that starts outside the allowed paths, and close the viewer it's in.
  if (rules.videoAllowedPaths) {
    const collapsed = rules.collapseSelectors.join(', ');
    document.addEventListener('play', (e) => {
      const video = e.target;
      if (!(video instanceof HTMLVideoElement)) return;
      if (rules.videoAllowedPaths.some((prefix) => location.pathname.startsWith(prefix))) return;

      video.muted = true;
      video.pause();
      report();

      const inFeed = collapsed && video.closest(collapsed);
      const close = rules.viewerCloseSelector && document.querySelector(rules.viewerCloseSelector);
      if (!inFeed && close) {
        close.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      }
    }, true);
  }
})();
