# Deep Code · 国内 Debian VPS 一键安装

本分支 `china-mirrors` 面向国内网络环境，支持 **Debian 12 / 13**（amd64 / arm64 / armhf），默认模型为 `deepseek-flash`。

## 一键安装

在 root 终端执行：

```bash
curl -fsSLo /tmp/deepcode-install-cn.sh https://raw.githubusercontent.com/krischan-ai/deepcode-debian-vps/china-mirrors/install.sh && bash /tmp/deepcode-install-cn.sh
```

**注意：仓库如果仍为 Private，匿名访问 raw.githubusercontent.com 会返回 404；国内网络也可能无法连通 GitHub Raw。** 你可以通过可访问 GitHub 的电脑下载 [install.sh](./install.sh) 后通过 SCP 传到 VPS 执行，或在服务器已安装且登录 `gh` 的情况下运行：

```bash
gh api -H 'Accept: application/vnd.github.raw+json' repos/krischan-ai/deepcode-debian-vps/contents/install.sh?ref=china-mirrors > /tmp/deepcode-install-cn.sh
bash /tmp/deepcode-install-cn.sh
```

## 国内镜像配置

| 用途 | 镜像 | 说明 |
| --- | --- | --- |
| Debian APT | 清华 TUNA | 自动将官方 Debian/安全更新源地址替换为清华镜像，保留其他第三方源 |
| Node.js 22 | npmmirror | 下载最新 22.x 的 Linux 预编译压缩包并校验 SHA-256 |
| npm 依赖 | npmmirror | 安装 `@vegamo/deepcode-cli` 时使用 `https://registry.npmmirror.com` |
| DeepSeek API | 官方 | `https://api.deepseek.com`，模型 `deepseek-flash` |

安装前会将原有 APT 配置备份到 `/root/apt-sources-backup-时间戳/`。清华镜像的安全更新同步可能慢于 Debian 官方安全源，需要自行衡量同步延迟。Node.js/npm 和第三方包镜像也可能有同步延迟。

## 配置及日常启动

安装时交互式输入 DeepSeek API Key，密钥不回显，存储在 `~/.deepcode/settings.json`，文件权限为 `600`，**不会提交到 GitHub**。

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

以后启动：

```bash
cd ~/workspace
deepcode
```

## 风险及排查

- `curl: (7)` 或 `curl: (28)`：镜像或 GitHub Raw 访问失败，确认网络连通性。
- `404`：先检查仓库是否为 Public，以及所选文件路径和分支是否正确。
- `npm ERR!`：可能是包在 npm 国内镜像尚未同步；可以手动切回官方 registry。
- `model not found`：检查 API 服务实际支持的模型 ID。
- 默认直接修改系统的 APT 源，请先检查 [install.sh](./install.sh)；生产环境建议快照备份后再运行。

参考：[清华 Debian 镜像帮助](https://mirrors.tuna.tsinghua.edu.cn/help/debian/) · [清华 Debian Security 镜像帮助](https://mirrors.tuna.tsinghua.edu.cn/help/debian-security/)
