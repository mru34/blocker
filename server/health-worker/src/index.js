// Collects Blocker's anonymous daily rule-health counts, and once a day opens a GitHub issue if
// a rule looks broken (usually Instagram or YouTube changed their site and reels got through).
//
// POST /report  body: { date, appVersion, rulesVersion, sites: { "instagram.com": { postsSeen,
//               reelsHidden, pageLoads, matchedSelectors: [...] } } }  (see RuleHealth.swift)

const MAX_BODY_BYTES = 20_000;
const KEEP_REPORTS_DAYS = 30;

// Thresholds: enough browsing across enough phones before calling something broken.
const MIN_POSTS_FOR_REEL_CHECK = 100;
const MIN_REPORTS_FOR_SELECTOR_CHECK = 3;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST' || url.pathname !== '/report') {
      return new Response('Not found', { status: 404 });
    }
    if (Number(request.headers.get('content-length') || 0) > MAX_BODY_BYTES) {
      return new Response('Too large', { status: 413 });
    }

    let report;
    try {
      report = await request.json();
    } catch {
      return new Response('Bad JSON', { status: 400 });
    }
    const problem = validate(report);
    if (problem) return new Response(problem, { status: 400 });

    const key = `report:${report.date}:${crypto.randomUUID()}`;
    await env.REPORTS.put(key, JSON.stringify(report), { expirationTtl: KEEP_REPORTS_DAYS * 86400 });
    return new Response('ok');
  },

  // Daily (see wrangler.toml): check yesterday's reports and open an issue if anything looks off.
  async scheduled(_event, env) {
    const day = new Date(Date.now() - 86400_000).toISOString().slice(0, 10);
    const reports = await loadReports(env, day);
    if (reports.length === 0) return;

    const rules = await (await fetch(`${env.RULES_URL}?t=${Date.now()}`)).json();
    const problems = findProblems(reports, rules);
    if (problems.length === 0) return;

    await openIssue(env, `Rule health alert: ${day}`, [
      `From ${reports.length} anonymous report(s) for ${day}, against rules version ${rules.version}:`,
      '',
      ...problems.map((p) => `- ${p}`),
      '',
      'Check the selectors against the live site (Safari Web Inspector), fix rules.json in the gist, and bump its version.',
    ].join('\n'));
  },
};

function validate(report) {
  if (!report || typeof report !== 'object') return 'Not an object';
  if (!/^\d{4}-\d{2}-\d{2}$/.test(report.date)) return 'Bad date';
  if (!report.sites || typeof report.sites !== 'object') return 'No sites';
  const sites = Object.entries(report.sites);
  if (sites.length > 5) return 'Too many sites';
  for (const [, site] of sites) {
    for (const field of ['postsSeen', 'reelsHidden', 'pageLoads']) {
      if (!Number.isInteger(site[field]) || site[field] < 0 || site[field] > 100_000) return `Bad ${field}`;
    }
    if (!Array.isArray(site.matchedSelectors) || site.matchedSelectors.length > 50) return 'Bad matchedSelectors';
  }
  return null;
}

async function loadReports(env, day) {
  const reports = [];
  let cursor;
  do {
    const page = await env.REPORTS.list({ prefix: `report:${day}:`, cursor });
    for (const { name } of page.keys) {
      const value = await env.REPORTS.get(name, 'json');
      if (value) reports.push(value);
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return reports;
}

// Same rule as the app: "instagram.com" for "https://www.instagram.com/".
function domainOf(homeURL) {
  return new URL(homeURL).hostname.replace(/^(www|m)\./, '');
}

function findProblems(reports, rules) {
  const problems = [];
  for (const name of ['instagram', 'youtube']) {
    const siteRules = rules[name];
    if (!siteRules) continue;
    const domain = domainOf(siteRules.homeURL);
    const siteReports = reports.map((r) => r.sites[domain]).filter((s) => s && s.pageLoads > 0);
    if (siteReports.length === 0) continue;

    const posts = siteReports.reduce((sum, s) => sum + s.postsSeen, 0);
    const hidden = siteReports.reduce((sum, s) => sum + s.reelsHidden, 0);
    if ((siteRules.collapseSelectors || []).length > 0 && posts >= MIN_POSTS_FOR_REEL_CHECK && hidden === 0) {
      problems.push(`**${domain}**: 0 reels hidden in ${posts} feed posts. The collapseSelectors probably no longer match.`);
    }

    if (siteReports.length >= MIN_REPORTS_FOR_SELECTOR_CHECK) {
      const selectors = [...(siteRules.hideSelectors || []), ...(siteRules.collapseSelectors || [])];
      for (const selector of selectors) {
        const matchedIn = siteReports.filter((s) => s.matchedSelectors.includes(selector)).length;
        if (matchedIn === 0) {
          problems.push(`**${domain}**: \`${selector}\` matched nothing on any of ${siteReports.length} phones.`);
        }
      }
    }
  }
  return problems;
}

async function openIssue(env, title, body) {
  const response = await fetch(`https://api.github.com/repos/${env.GITHUB_REPO}/issues`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'User-Agent': 'blocker-health-worker',
    },
    body: JSON.stringify({ title, body, labels: ['rule-health'] }),
  });
  if (!response.ok) {
    console.error('Opening the GitHub issue failed', response.status, await response.text());
  }
}
