# mous

基于 uncleluo/mous 镜像的 VMess/WebSocket 代理工具，自定义启动脚本，自动识别平台域名和节点名称。

## 部署方式

### Docker 镜像部署

```bash
docker pull ghcr.io/zaofengyue/mous:latest
```

```bash
docker run -d \
  -e DOMAIN=你的域名 \
  -e PORT=3000 \
  -p 3000:3000 \
  ghcr.io/zaofengyue/mous:latest
```

## 支持平台

| 平台 | 域名自动识别 |
|---|---|
| Railway | ✅ |
| Render | ✅ |
| Zeabur | ✅ |
| Koyeb | ✅ |
| CloudFoundry | ✅ |
| 其他 VPS / 容器平台 | 自动获取公网 IP |

## 环境变量

| 变量名 | 说明 | 默认值 |
|---|---|---|
| `UUID` | 节点唯一ID | 自动生成 |
| `PORT` | 监听端口 | `3000` |
| `DOMAIN` | 手动指定域名 | 自动识别 |
| `NAME` | 手动指定节点名称 | 自动识别国家+平台/ASN |

## 使用cloudflare workers 或 snippets 反代域名给节点套cdn加速

```bsah
export default {
    async fetch(request, env) {
        let url = new URL(request.url);
        if (url.pathname.startsWith('/')) {
            var arrStr = [
                'change.your.domain', // 此处单引号里填写你的节点伪装域名
            ];
            url.protocol = 'https:'
            url.hostname = getRandomArray(arrStr)
            let new_request = new Request(url, request);
            return fetch(new_request);
        }
        return env.ASSETS.fetch(request);
    },
};
function getRandomArray(array) {
  const randomIndex = Math.floor(Math.random() * array.length);
  return array[randomIndex];
}
```

## 订阅链接

部署成功后在容器日志里查看 VMess 链接：

```bash
docker logs 容器名
```

## 注意事项

- 仅供学习研究使用，请遵守当地法律法规
- 部署在境外服务器使用效果更佳
