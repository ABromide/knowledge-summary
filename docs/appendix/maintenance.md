# 内容维护指南

站点基于 VitePress，所有正式内容都保存在 `docs/` 目录中，使用中文 Markdown 编写。当前知识正文来自个人 Notion 的分组总结。

## 同步 Notion 内容

1. 只读检索目标页面、数据库与父子关系。
2. 先更新 `docs/appendix/notion-sources.md` 的来源映射和同步日期。
3. 按主题合并内容，不把 Notion 目录机械复制成网站目录。
4. 重复条目合并展示；无正文收藏标记为待消化。
5. 更新正文后运行 `./scripts/check.sh`，检查导航与深层路由。

## 新增页面

1. 在对应主题目录新建 `.md` 文件。
2. 在 `docs/.vitepress/config.mts` 的 `sidebar` 中增加入口。
3. 使用 `./scripts/check.sh` 完成构建与静态产物检查。

## 本地运行

首次使用运行：

```bash
./scripts/setup.sh
```

启动开发服务：

```bash
./scripts/dev.sh
```

构建与验证：

```bash
./scripts/check.sh
```

## 部署到 GitHub Pages

完成内容更新并推送源码后，运行下面的脚本。脚本会使用 `/knowledge-summary/` 子路径重新构建，并把静态产物发布到 `gh-pages` 分支：

```bash
./scripts/deploy.sh
```
