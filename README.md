# Deep Code · 国内 Ubuntu VPS 一键安装

本分支 `ubuntu-china-mirrors` 基于 `china-mirrors`，针对 **Ubuntu 22.04 / 24.04 / 26.04**（x86_64、ARM64、armhf）国内服务器，默认模型 `deepseek-flash`。

## 一键安装（推荐 GitHub 加速）

以 root 登录 VPS，复制整条命令：

```bash
curl -fL --retry 3 -o /tmp/deepcode-install-cn.sh 'https://gh-proxy.com/https://raw.githubusercontent.com/krischan-ai/deepcode-debian-vps/ubuntu-china-mirrors/install.sh' && bash /tmp/deepcode-install-cn.sh
```

直连备用命令：

```bash
curl -fL --retry 3 -o /tmp/deepcode-install-cn.sh 'https://raw.githubusercontent.com/krischan-ai/deepcode-debian-vps/ubuntu-china-mirrors/install.sh' && bash /tmp/deepcode-install-cn.sh
```

**权限提醒：** 仓库必须是 **Public** 才能通过上述匿名 URL 获取脚本。Private 仓库不能简单通过公开加速站访问；不要向第三方代理传送 GitHub Token。如需保持 Private，可在已认证的电脑上下载脚本再使用 `scp` 上传至 VPS，或用已登录的 `gh api` 获取文件。

在通过第三方代理运行脚本之前，建议先查看其内容；请勿无条件执行来自未信任代理的 Shell 脚本。

## 国内镜像

| 安装环节 | 服务 |
| --- | --- |
| GitHub Raw 脚本下载 | [gh-proxy.com](https://gh-proxy.com/) |
| Ubuntu APT 和安全更新 | 中科大 USTC → 阿里云 → Ubuntu 官方自动回退（镜像切换仅适用于标准 `/ubuntu` 源） |
| Node.js 22 二进制 | npmmirror（下载并校验 SHA-256） |
| npm 包 | `https://registry.npmmirror.com` |
| DeepSeek 模型 | 官方 API，`deepseek-flash` |

脚本会备份原 APT 源（兼容传统 `sources.list` 与 Ubuntu 24.04+ 的 `ubuntu.sources`）到 `/root/apt-sources-backup-时间戳/`，安装基础工具、Node.js 和 Deep Code，提示交互式输入 API Key，然后启动 `deepcode`。

## GitHub 下载和克隆加速

下载任意公开 Raw 文件：

```bash
curl -fL -o file.sh 'https://gh-proxy.com/https://raw.githubusercontent.com/OWNER/REPO/BRANCH/file.sh'
```

克隆公开仓库可尝试：

```bash
git clone 'https://gh-proxy.com/https://github.com/OWNER/REPO.git'
```

注意第三方代理对 Git Clone 的支持和稳定性可能不同；加速不等于匿名访问 Private 仓库。为避免影响其他 Git 操作，本安装脚本**不会修改全局 Git 配置或强制代理所有 GitHub 请求**。

## 日常启动和配置

```bash
cd ~/workspace
deepcode
```

`~/.deepcode/settings.json` 内容：

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

密钥仅在 VPS 本地输入，文件权限 `600`。注意 API 服务是否支持指定模型。

## 清华镜像 403 Forbidden 的修复

如果此前运行过旧脚本，APT 源可能仍指向清华镜像。新版脚本会将旧的清华 Ubuntu 路径切换为中科大，并在 `apt-get update` 失败时自动依次尝试阿里云、官方 Ubuntu 镜像，不关闭签名验证。

也可以先手动修复：

```bash
grep -rlZ 'mirrors.tuna.tsinghua.edu.cn/ubuntu' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | xargs -0 -r sed -i 's#https://mirrors.tuna.tsinghua.edu.cn/ubuntu#https://mirrors.ustc.edu.cn/ubuntu#g'
apt-get update
```

注意：`ubuntu-ports`（ARM ports）的镜像规则与普通 `ubuntu` 不同，本脚本暂不自动切换 ports 镜像；此类系统应根据原配置单独检查。每次执行脚本都会备份现有 APT 配置。

## 常见问题

- GitHub 下载 404：检查仓库 Public、分支路径是否正确。
- 代理连接失败：改用直连、换网络，或先在本地下载再通过 SCP 上传。
- npm 镜像未同步：稍后重试或临时换回官方 npm registry。
- APT 镜像更新滞后：安全更新可能落后于官方源，生产环境请评估。
- 使用第三方 GitHub 加速服务时需考虑文件完整性与服务可信度。

参考：[gh-proxy.com 使用文档](https://gh-proxy.com/docs/github-accelerator)。
