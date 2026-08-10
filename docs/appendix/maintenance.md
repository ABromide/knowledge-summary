# 内容维护指南

站点基于 VitePress，所有内容都保存在 `docs/` 目录中，使用 Markdown 编写。

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

## 自动部署

推送到 `main` 分支后，GitHub Actions 会构建站点并发布到 GitHub Pages。部署配置位于 `.github/workflows/deploy-pages.yml`。
