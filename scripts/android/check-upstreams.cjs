const fs = require('node:fs');

const marker = '<!-- dusklight-upstream-tracking -->';
const sources = ['TwilitRealm/dusklight', 'igawa6/dusklight'];

function readPins(provenance) {
  return sources.map(repository => {
    const line = provenance.split('\n').find(line =>
      line.includes(`https://github.com/${repository}/releases/tag/`));
    const tag = line?.match(/\/releases\/tag\/([^\s)]+)/)?.[1];
    const commit = line?.match(/commit `([a-f0-9]{40})`/)?.[1];
    if (!tag || !commit) throw new Error(`Missing provenance tag/commit for ${repository}`);
    return { repository, tag, commit };
  });
}

async function check({ github, context, core, provenance }) {
  const pins = readPins(provenance ?? fs.readFileSync('docs/android/PROVENANCE.md', 'utf8'));
  // Complete both upstream reads before changing the tracking issue. API errors
  // must fail the workflow, never close an issue using incomplete evidence.
  const results = await Promise.all(pins.map(async pin => {
    const [owner, repo] = pin.repository.split('/');
    const { data: release } = await github.rest.repos.getLatestRelease({ owner, repo });
    if (release.draft || release.prerelease || !release.tag_name) {
      throw new Error(`No eligible stable release for ${pin.repository}`);
    }
    const { data: commit } = await github.rest.repos.getCommit({ owner, repo, ref: release.tag_name });
    return { ...pin, latestTag: release.tag_name, latestCommit: commit.sha,
      url: release.html_url,
      changed: release.tag_name !== pin.tag || commit.sha !== pin.commit };
  }));
  const pending = results.some(result => result.changed);
  const table = [
    '| Source | Integrated tag / commit | Latest stable tag / commit | Status |',
    '| --- | --- | --- | --- |',
    ...results.map(r => `| [${r.repository}](https://github.com/${r.repository}) | \`${r.tag}\` / \`${r.commit}\` | [${r.latestTag}](${r.url}) / \`${r.latestCommit}\` | ${r.changed ? 'Update requires integration' : 'Current'} |`),
  ].join('\n');
  const body = `${marker}\n## Upstream release tracking\n\n${table}\n\nThe local weekly Native Android updater performs integration, tests, builds, persistent signing, and publication. This issue closes automatically when the provenance matches both upstream releases. A changed tag or commit is a review signal; it never triggers a blind merge.\n`;
  core.summary.addHeading(pending ? 'Upstream integration pending' : 'Both upstreams current').addRaw(table);
  await core.summary.write();

  const issues = await github.paginate(github.rest.issues.listForRepo, {
    ...context.repo, state: 'all', per_page: 100,
  });
  const matching = issues.filter(issue => !issue.pull_request &&
    issue.user?.login === 'github-actions[bot]' && issue.body?.startsWith(marker));
  if (matching.length > 1) throw new Error('Multiple managed upstream issues; resolve the duplicate before continuing');
  const existing = matching[0];
  const title = 'Upstream release integration';
  if (!existing && pending) {
    await github.rest.issues.create({ ...context.repo, title, body });
  } else if (existing && (existing.body !== body || existing.state !== (pending ? 'open' : 'closed'))) {
    await github.rest.issues.update({ ...context.repo, issue_number: existing.number,
      title, body, state: pending ? 'open' : 'closed' });
  }
  core.info(pending ? 'Upstream changes recorded in the tracking issue.' : 'Both integrated sources match their latest stable releases.');
  return results;
}

module.exports = { check, readPins };
