// ============================================================
// 文档自动同步（代码变更 → .md 文档跟上）：
//   1. 版本号（事实源 app/pubspec.yaml）→ docs/ui-demo/index.html 关于页版本串
//   2. README 状态表测试计数（SERVER_TESTS / FLUTTER_TESTS 环境变量传入，可选）
//   3. API 端点清单 → docs/api-endpoints.generated.md（扫描 server/src/**/*.controller.ts）
// 用法：node scripts/sync-docs.mjs [--server-tests=N] [--flutter-tests=N]
// 由 .github/workflows/docs-sync.yml 在每次 master 推送后自动执行；
// 结果有变更时工作流会以 [docs-sync] 提交并推回仓库。
// ============================================================

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const arg = (name, dflt) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=')[1] : (process.env[name.toUpperCase()] ?? dflt);
};

const changes = [];

const writeIfChanged = (path, content) => {
  const p = join(root, path);
  const old = existsSync(p) ? readFileSync(p, 'utf8') : null;
  if (old === content) return;
  writeFileSync(p, content, 'utf8');
  changes.push(path);
};

// ---------- 1) 版本号：pubspec.yaml → ui-demo 关于页版本串 ----------
const pubspec = readFileSync(join(root, 'app/pubspec.yaml'), 'utf8');
const vm = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$/m);
if (!vm) throw new Error('pubspec.yaml 未找到 version: x.y.z(+build)');
const [, ver, build] = vm;

const config = readFileSync(join(root, 'app/lib/core/config.dart'), 'utf8');
if (!config.includes(`appVersion = '${ver}'`) || !config.includes(`appBuildNumber = '${build}'`)) {
  throw new Error(
    `config.dart 与 pubspec 不一致（pubspec=${ver}+${build}）——请先同步代码侧版本号再运行文档同步`,
  );
}

const demoHtml = readFileSync(join(root, 'docs/ui-demo/index.html'), 'utf8');
const nextHtml = demoHtml.replace(/v\d+\.\d+\.\d+ · 构建 \d+/, `v${ver} · 构建 ${build}`);
writeIfChanged('docs/ui-demo/index.html', nextHtml);

// ---------- 2) README 状态表测试计数（可选，由 CI 传入实测值） ----------
const serverTests = arg('server-tests', '');
const flutterTests = arg('flutter-tests', '');
if (serverTests || flutterTests) {
  let readme = readFileSync(join(root, 'README.md'), 'utf8');
  if (serverTests) {
    readme = readme.replace(/(`npm test`（\*\*)\d+\/\d+(\*\*)/, `$1${serverTests}/${serverTests}$2`);
  }
  if (flutterTests) {
    readme = readme.replace(/(`flutter test` \*\*)\d+\/\d+(\*\*)/, `$1${flutterTests}/${flutterTests}$2`);
  }
  writeIfChanged('README.md', readme);
}

// ---------- 3) API 端点清单：扫描控制器 → docs/api-endpoints.generated.md ----------
const apiPrefix = 'api/v1';
const ctrlDir = join(root, 'server/src');
const controllers = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (name.endsWith('.controller.ts')) controllers.push(p);
  }
})(ctrlDir);

const rows = [];
for (const file of controllers.sort()) {
  const src = readFileSync(file, 'utf8');
  const classM = src.match(/@Controller\('([^']+)'\)/);
  const prefix = classM ? classM[1] : '';
  const lines = src.split('\n');
  const blocks = [];
  let buf = [];
  for (const line of lines) {
    // 方法签名行（Nest 控制器方法通常不带 async）：新块开始
    if (/^\s*(?:async\s+)?\w+\s*\(/.test(line) && !line.trim().startsWith('@')) {
      if (buf.length) blocks.push(buf);
      buf = [];
    }
    buf.push(line);
  }
  if (buf.length) blocks.push(buf);

  for (const block of blocks) {
    const route = block.find((l) => /^\s*@(Get|Post|Patch|Delete|Put)\s*\(/i.test(l));
    if (!route) continue;
    const m = route.match(/@(Get|Post|Patch|Delete|Put)\(\s*'([^']*)'\s*\)/i);
    if (!m) continue;
    const http = m[1].toUpperCase().padEnd(6);
    const path = [prefix, m[2]].filter(Boolean).join('/');
    const auth = block.some((l) => l.includes('@Public()')) || prefix === 'health'
        ? '公开'
        : '🔒 登录';
    // 说明：取该块内最后一个 `/** ... */` 或 `//` 注释的首个有效文本行
    const blockText = block.join('\n');
    let comment = null;
    const docBlocks = blockText.match(/\/\*\*[\s\S]*?\*\//g);
    if (docBlocks && docBlocks.length) {
      comment = docBlocks[docBlocks.length - 1];
    } else {
      const lineMatches = blockText.match(/\n\s*\/\/\s*(.+?)\s*$/gm);
      if (lineMatches && lineMatches.length) comment = lineMatches[lineMatches.length - 1];
    }
    const summary = comment
        ? comment
            .replace(/\/\*\*|\*\//g, '')
            .split('\n')
            .map((l) => l.replace(/^\s*\*\s?/, '').trim())
            .find((l) => l)
            ?.slice(0, 80) ?? ''
        : '';
    rows.push(`| ${http} | \`${apiPrefix}/${path}\` | ${auth} | ${summary} |`);
  }
}

rows.sort();
const doc = `# API 端点清单（自动生成）

> ⚙️ 本文件由 \`scripts/sync-docs.mjs\` 从 \`server/src/**/*.controller.ts\` 自动生成，**请勿手改**；
> 每次 master 推送后由 \`.github/workflows/docs-sync.yml\` 自动更新（人工改动会被覆盖）。
> 完整契约见 [技术方案](./AA分账App-技术方案.md)；Swagger：\`GET /api/docs\`。

共 ${rows.length} 个端点。表格：HTTP 方法 | 路径（\`${apiPrefix}\` 为全局前缀）| 鉴权 | 说明。

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
${rows.join('\n')}
`;
writeIfChanged('docs/api-endpoints.generated.md', doc);

console.log(`[sync-docs] version=${ver}+${build} apiEndpoints=${rows.length}`);
console.log(changes.length ? `[sync-docs] 已更新：${changes.join(', ')}` : '[sync-docs] 全部一致，无变更');
