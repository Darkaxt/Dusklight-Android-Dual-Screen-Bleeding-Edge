const { test } = require('node:test');
const assert = require('node:assert/strict');
const { check, readPins } = require('./check-upstreams.cjs');

const provenance = [
  `- [official](https://github.com/TwilitRealm/dusklight/releases/tag/v1.4.1), commit \`${'a'.repeat(40)}\`.`,
  `- [reference](https://github.com/igawa6/dusklight/releases/tag/v1.4.1-ds-2.7), commit \`${'b'.repeat(40)}\`.`,
].join('\n');

function fixture() {
  const pins = readPins(provenance);
  const releases = Object.fromEntries(pins.map(p => [p.repository.split('/')[0], {
    tag_name: p.tag, sha: p.commit, html_url: `https://github.com/${p.repository}/releases/tag/${p.tag}`,
  }]));
  const issues = [];
  const writes = [];
  const github = {
    rest: {
      repos: {
        getLatestRelease: async ({ owner }) => ({ data: releases[owner] }),
        getCommit: async ({ owner }) => ({ data: { sha: releases[owner].sha } }),
      },
      issues: {
        listForRepo: () => {},
        create: async data => {
          writes.push(data);
          issues.push({ ...data, number: 1, state: 'open', user: { login: 'github-actions[bot]' } });
        },
        update: async data => {
          writes.push(data);
          Object.assign(issues.find(i => i.number === data.issue_number), data);
        },
      },
    },
    paginate: async () => issues,
  };
  const summary = { addHeading() { return this; }, addRaw() { return this; }, async write() {} };
  return { releases, issues, writes, github, run: () => check({ github,
    context: { repo: { owner: 'test', repo: 'test' } },
    core: { summary, info() {} }, provenance }) };
}

test('reads both source identities and rejects missing provenance', () => {
  assert.equal(readPins(provenance).length, 2);
  assert.throws(() => readPins(''), /Missing provenance/);
});

test('current sources create no issue', async () => {
  const f = fixture();
  assert.equal((await f.run()).some(r => r.changed), false);
  assert.equal(f.writes.length, 0);
});

test('reference-only update creates one issue, remains quiet, closes and reopens it', async () => {
  const f = fixture();
  f.releases.igawa6.tag_name = 'v1.4.1-ds-2.8';
  await f.run();
  assert.equal(f.issues.length, 1);
  await f.run();
  assert.equal(f.writes.length, 1);
  f.releases.igawa6.tag_name = 'v1.4.1-ds-2.7';
  await f.run();
  assert.equal(f.issues[0].state, 'closed');
  await f.run();
  assert.equal(f.writes.length, 2);
  f.releases.TwilitRealm.tag_name = 'v1.5.0';
  await f.run();
  assert.equal(f.issues.length, 1);
  assert.equal(f.issues[0].state, 'open');
});

test('retagged commit is detected even when tag name matches', async () => {
  const f = fixture();
  f.releases.TwilitRealm.sha = 'c'.repeat(40);
  await f.run();
  assert.equal(f.writes.length, 1);
});

test('API failures preserve an existing issue', async () => {
  const f = fixture();
  f.releases.igawa6.tag_name = 'v1.4.1-ds-2.8';
  await f.run();
  f.github.rest.repos.getLatestRelease = async () => { throw new Error('API unavailable'); };
  await assert.rejects(f.run(), /API unavailable/);
  assert.equal(f.writes.length, 1);
  assert.equal(f.issues[0].state, 'open');
});

test('drafts and prereleases are never accepted', async () => {
  for (const flag of ['draft', 'prerelease']) {
    const f = fixture();
    f.releases.igawa6[flag] = true;
    await assert.rejects(f.run(), /eligible stable release/);
    assert.equal(f.writes.length, 0);
  }
});
