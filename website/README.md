# MacFan 产品官网

线上地址：<https://badpx.github.io/MacFan/>。托管于 GitHub Pages，由 `.github/workflows/pages.yml` 发布。做法与 NotesMate 官网相同：静态页面、英语在站点根路径、其余语言为独立目录，由 GitHub Actions 构建并部署。

## 内容与维护

- `index.template.html`、`style.css`、`site.js` 是官网源文件，无第三方运行时、字体服务或统计脚本。
- 文案在 `locales/*.json`。构建会检查这些语言与 `Sources/MacFan/L10n.swift` 里的语言表一致，并检查模板键完整，不允许漏译后回退英文。
- 英文位于根路径，其他语言有独立目录、页面语言、标题、描述、canonical 和 hreflang。语言选择器切换静态页面。正文与下载链接在禁用 JavaScript 时仍可用；切换语言需要 JavaScript。
- 浅色、深色和设置页预览是当前应用用 `MacFan --ui-snapshot` 截下的原生界面，放在 `website/preview/`。英语、简体中文、繁体中文各一套；其他语言页面用英语界面。图标仍复用 `Design/MacFan-UI/MacFan-AppIcon.png`。
- 构建会给 CSS 和 JavaScript 链接附加内容摘要，避免新页面继续加载浏览器缓存中的旧样式或脚本。
- 工作流在相关源码合入 main、Release 变更或手动触发时重建。线上构建从 GitHub API 读取最新正式 Release 的 `MacFan-<tag>.zip`；失败会中止部署，不会用过期版本替换网站。Release 事件始终检出 main，避免旧版本标签覆盖官网源码。
- `release.json` 是本地离线预览快照（当前为 v1.1.2）。线上构建用最新 API 数据覆盖输入。不要把 API token 写入该文件。

## 本地预览

```bash
python3 Scripts/build-website.py --base ''
python3 -m http.server 8000 --directory build/website
```

打开 `http://localhost:8000/` 或 `http://localhost:8000/zh-Hans/`。

要按线上路径检查 base path：

```bash
python3 Scripts/build-website.py
mkdir -p /tmp/macfan-pages
ln -sfn "$PWD/build/website" /tmp/macfan-pages/MacFan
python3 -m http.server 8000 --directory /tmp/macfan-pages
```

打开 `http://localhost:8000/MacFan/`。默认构建参数为实际项目站点路径 `/MacFan`；输出位于已忽略的 `build/website`。

## GitHub Pages 手动设置

仓库需要先指定用 Actions 发布，工作流里的 `actions/configure-pages` 与 `actions/deploy-pages` 才会成功：

1. 打开仓库 **Settings → Pages**。
2. 在 **Build and deployment** 里把 **Source** 选为 **GitHub Actions**。不要选 “Deploy from a branch”。
3. 合入 main（或在 Actions 里手动运行 “Deploy product website”）后，站点发布到 Environment `github-pages`。
4. 若部署停在等待批准，到 **Settings → Environments → github-pages** 允许本仓库部署。
5. 发布完成后从 `https://badpx.github.io/MacFan/` 访问。英语在该地址，其他语言在 `/zh-Hans/`、`/zh-Hant/`、`/ja/` 等子路径。

本仓库没有自定义域名。Pages 只发布 `build/website` 这份构建产物，不发布 Swift 源码目录。
