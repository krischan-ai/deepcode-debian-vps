# Deep Code · Debian VPS 一键安装

适用于全新 **Debian 12 / Debian 13** VPS，默认使用 **DeepSeek V4.1 Flash**（API 模型 ID：`deepseek-flash`）。

## 一键安装

以 `root` 登录 VPS 后执行：

```bash
curl -fsSLo /tmp/deepcode-install.sh https://raw.githubusercontent.com/krischan-ai/deepcode-debian-vps/main/install.sh && bash /tmp/deepcode-install.sh
```

> **仓库访问权限**：当前仓库如为 Private，以上匿名 Raw URL 会返回 404。先将仓库设置为 Public，或使用下文的 GitHub CLI 授权下载方式。**在运行通过网络下载的脚本前，建议先阅读 [install.sh](./install.sh)。**

### 私有仓库的安装方式（已安装并登录 GitHub CLI）

```bash
gh api -H 'Accept: application/vnd.github.raw+json' repos/krischan-ai/deepcode-debian-vps/contents/install.sh > /tmp/deepcode-install.sh
bash /tmp/deepcode-install.sh
```

## 安装内容

- 更新 apt 软件索引，安装 `curl`、`git`、`python3`、`ca-certificates` 等基础组件
- 安装 Node.js 22、npm 和 `@vegamo/deepcode-cli`
- 创建 `~/.deepcode/settings.json` 并交互式读取 DeepSeek API Key（输入不回显）
- 自动建立 `~/workspace` 并启动 `deepcode`
- 可选安装 tmux 保持 SSH 断开后的终端会话

默认配置：

```json
{
  "env": {
    "MODEL": "deepseek-flash",
    "BASE_URL": "https://api.deepseek.com",
    "API_KEY": "sk-..."
  },
  "thinkingEnabled": true,
  "reasoningEffort": "max"
}
```

API Key **不会提交至 GitHub**。配置文件权限为 `600`，配置目录权限为 `700`。

## 日常使用

```bash
cd ~/workspace
deepcode
```

编辑配置：`nano ~/.deepcode/settings.json`

可选 tmux：

```bash
apt-get install -y tmux
tmux new -s deepcode
cd ~/workspace && deepcode
```

在 tmux 中按 `Ctrl+B` 后按 `D` 分离会话；重新连接后运行 `tmux attach -t deepcode`。

## 前提与注意事项

- 目标系统：Debian 12/13，具有 root 或 sudo 管理权限；可联网访问 Debian、NodeSource 和 npm。
- 安装脚本使用 `apt-get`，当前仅支持 Debian；非 root 用户会尝试通过 sudo 获取权限。
- 如果已有 `~/.deepcode/settings.json`，脚本会先备份成带时间戳的文件再写入新配置。
- 官方 DeepSeek API 于 2026-09-10 将最新 Flash 模型标识指定为 `deepseek-flash`（V4.1 Flash）。
- 依赖和 CLI 来自第三方，安装前自行核实源及软件可信性。

参考：[Deep Code CLI](https://www.npmjs.com/package/@vegamo/deepcode-cli) · [DeepSeek API 更新日志](https://api-docs.deepseek.com/zh-cn/updates/)
