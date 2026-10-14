// Debug builds only: reports what the page is doing to the Xcode console,
// so we can see why something slipped past filter.js.
(function () {
  if (window.__blockerDebugInstalled) return;
  window.__blockerDebugInstalled = true;

  function send(kind, data) {
    try {
      const payload = Object.assign({ kind: kind, path: location.pathname }, data || {});
      window.webkit.messageHandlers.blockerDebug.postMessage(JSON.stringify(payload));
    } catch (e) {}
  }

  function describe(el) {
    if (!el || !el.closest) return {};
    const link = el.closest('a');
    const labelled = el.closest('[aria-label]');
    const icon = el.closest('svg[aria-label]') || (el.querySelector && el.querySelector('svg[aria-label]'));
    return {
      tag: el.tagName.toLowerCase(),
      href: link ? link.getAttribute('href') : null,
      role: el.closest('[role]') ? el.closest('[role]').getAttribute('role') : null,
      label: (labelled && labelled.getAttribute('aria-label')) || (icon && icon.getAttribute('aria-label')) || null,
      text: (el.innerText || '').trim().slice(0, 60),
    };
  }

  // Every icon with a label and what it links to: shows whether "New post" etc. exist.
  function dumpIcons() {
    const items = Array.from(document.querySelectorAll('svg[aria-label]')).map((svg) => {
      const target = svg.closest('a, button, [role=button], [role=link]');
      const where = target ? target.getAttribute('href') || target.tagName.toLowerCase() : '-';
      const hidden = target && getComputedStyle(target).display === 'none' ? ' (hidden)' : '';
      return svg.getAttribute('aria-label') + ' => ' + where + hidden;
    });
    send('icons', { items: Array.from(new Set(items)).slice(0, 40) });
  }

  let lastPath = location.pathname;
  setInterval(() => {
    if (location.pathname === lastPath) return;
    lastPath = location.pathname;
    send('path');
    setTimeout(dumpIcons, 2000);
  }, 300);

  document.addEventListener('click', (e) => send('click', describe(e.target)), true);

  // Videos that start playing, and where they live (feed post, dialog, DM thread...).
  document.addEventListener('play', (e) => {
    const video = e.target;
    const container = video.closest('[role=dialog], article, [role=presentation]');
    const reelLink = container && container.querySelector('a[href*="/reel"]');
    send('play', {
      inArticle: !!video.closest('article'),
      inDialog: !!video.closest('[role=dialog]'),
      link: video.closest('a') ? video.closest('a').getAttribute('href') : reelLink ? reelLink.getAttribute('href') : null,
    });
  }, true);

  // Feed health, logged when it changes: helps explain a blank feed.
  let lastState = '';
  setInterval(() => {
    const articles = Array.from(document.querySelectorAll('article'));
    const hidden = articles.filter((a) => getComputedStyle(a).display === 'none').length;
    const videos = Array.from(document.querySelectorAll('video')).filter((v) => v.getBoundingClientRect().height > 0).length;
    const main = document.querySelector('main');
    const state = 'articles=' + articles.length + ' hidden=' + hidden + ' visibleVideos=' + videos +
      ' scrollY=' + Math.round(scrollY) + ' height=' + document.documentElement.scrollHeight +
      ' mainText=' + (main ? main.innerText.trim().length : -1);
    if (state === lastState) return;
    lastState = state;
    send('feed', { state: state });
  }, 3000);

  // Each feed post with a video, once: does it link to /reel/ (collapsed) or not (allowed to play)?
  const seenVideoPosts = new WeakSet();
  setInterval(() => {
    for (const article of document.querySelectorAll('article')) {
      if (seenVideoPosts.has(article) || !article.querySelector('video')) continue;
      seenVideoPosts.add(article);
      const links = Array.from(new Set(Array.from(article.querySelectorAll('a[href*="/p/"], a[href*="/reel/"]'))
        .map((a) => a.getAttribute('href').replace(/^\/[^/]+(?=\/(p|reel)\/)/, '')))).slice(0, 3);
      send('videoPost', {
        collapsed: getComputedStyle(article).height === '44px',
        reelLink: !!article.querySelector('a[href*="/reel/"]'),
        carousel: !!article.querySelector('[aria-label="Next"], [aria-label="Go back"]'),
        links: links,
        text: (article.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60),
      });
    }
  }, 2000);

  // Speed: load milestones, when the first feed post shows, data downloaded, and stutter
  // (frames slower than 50 ms, where 16 ms is smooth).
  const jank = { frames: 0, slow: 0, longest: 0, lost: 0 };
  let lastFrame = performance.now();
  (function frame(now) {
    const gap = now - lastFrame;
    lastFrame = now;
    if (!document.hidden) {
      jank.frames++;
      if (gap > 50) {
        jank.slow++;
        jank.lost += gap - 16.7;
        jank.longest = Math.max(jank.longest, gap);
      }
    }
    requestAnimationFrame(frame);
  })(performance.now());

  function jankSummary() {
    const s = { frames: jank.frames, slowFrames: jank.slow, longestMs: Math.round(jank.longest), lostMs: Math.round(jank.lost) };
    jank.frames = jank.slow = jank.longest = jank.lost = 0;
    return s;
  }

  function networkSummary() {
    const resources = performance.getEntriesByType('resource');
    const kb = resources.reduce((sum, r) => sum + (r.transferSize || 0), 0) / 1024;
    // The slowest requests, and when they started/ended (ms since the page started loading).
    const slowest = resources.slice().sort((a, b) => b.duration - a.duration).slice(0, 6).map((r) => {
      const url = r.name.replace(/^https?:\/\//, '').replace(/\?.*$/, '');
      return Math.round(r.startTime) + '-' + Math.round(r.responseEnd) + 'ms ' + r.initiatorType + ' ' + url.slice(0, 70);
    });
    // Big gaps where nothing was loading: the page was waiting on something else.
    const ends = resources.map((r) => [r.startTime, r.responseEnd]).sort((a, b) => a[0] - b[0]);
    let idle = 0, longestIdle = 0, cursor = 0;
    for (const [start, end] of ends) {
      if (start > cursor) { longestIdle = Math.max(longestIdle, start - cursor); idle += start - cursor; }
      cursor = Math.max(cursor, end);
    }
    return { requests: resources.length, downloadedKB: Math.round(kb), slowest: slowest, longestIdleMs: Math.round(longestIdle) };
  }

  const startedAt = performance.now();
  const firstPostTimer = setInterval(() => {
    const found = document.querySelector('article');
    const waited = performance.now() - startedAt;
    if (!found && waited < 30000) return;
    clearInterval(firstPostTimer);
    const nav = performance.getEntriesByType('navigation')[0] || {};
    send('speed', Object.assign({
      firstPostMs: found ? Math.round(performance.now()) : null,
      serverRespondedMs: Math.round(nav.responseStart || 0),
      pageReadyMs: Math.round(nav.domContentLoadedEventEnd || 0),
      pageLoadedMs: Math.round(nav.loadEventEnd || 0),
    }, networkSummary(), { loadStutter: jankSummary() }));
  }, 100);

  // While scrolling: stutter per 5 seconds of scrolling.
  let lastScrollY = scrollY;
  setInterval(() => {
    const scrolled = Math.abs(scrollY - lastScrollY);
    lastScrollY = scrollY;
    const summary = jankSummary();
    if (scrolled > 200) send('scrollSpeed', Object.assign({ scrolledPx: Math.round(scrolled) }, summary));
  }, 5000);

  window.addEventListener('error', (e) => send('jserror', { message: String(e.message).slice(0, 200) }));

  setTimeout(dumpIcons, 4000);
})();
