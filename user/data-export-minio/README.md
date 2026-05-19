# Pod 数据下载到本地

## 入口信息

| 项 | 值 |
|---|---|
| 集群内上传地址 | `https://data-minio-hl.data-export-minio.svc.k8s.xa.cluster:9000` |
| 本机下载地址 | `https://minio-data-xa.xshixun.cn:7443` |
| Bucket | `export` |
| 数据保留 | 14 天自动清理 |

账号由管理员单独发放：

```bash
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

## 1. Pod 内安装 mc

Pod 内需要有 `mc` 命令。Linux x86_64 容器可临时安装：

```bash
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
chmod +x /usr/local/bin/mc
mc --version
```

如果没有 `/usr/local/bin` 写权限：

```bash
mkdir -p "$HOME/bin"
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o "$HOME/bin/mc"
chmod +x "$HOME/bin/mc"
export PATH="$HOME/bin:$PATH"
mc --version
```

在镜像中固化 `mc`：

```dockerfile
RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc \
      -o /usr/local/bin/mc \
    && chmod +x /usr/local/bin/mc
```

Alpine 镜像可用：

```dockerfile
RUN wget -q https://dl.min.io/client/mc/release/linux-amd64/mc \
      -O /usr/local/bin/mc \
    && chmod +x /usr/local/bin/mc
```

## 2. Pod 内上传数据

```bash
export AWS_ACCESS_KEY_ID='<管理员发放>'
export AWS_SECRET_ACCESS_KEY='<管理员发放>'

export MINIO_ENDPOINT='https://data-minio-hl.data-export-minio.svc.k8s.xa.cluster:9000'
export MINIO_BUCKET='export'
export NO_PROXY='localhost,127.0.0.1,.svc,.svc.cluster.local,.svc.k8s.xa.cluster,.cluster.local,.k8s.xa.cluster,10.96.0.0/12,192.168.0.0/16,192.168.3.0/24'

mc --insecure alias set data-minio "$MINIO_ENDPOINT" "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
mc --insecure cp --recursive /path/to/data data-minio/export/<用户名>/<任务名>/
```

也可以使用脚本：

```bash
sh scripts/pod-upload-to-minio.sh /path/to/data <用户名>/<任务名>
```

## 3. 本机下载数据

本机安装 `mc`，macOS Apple Silicon 示例：

```bash
curl -fsSL https://dl.min.io/client/mc/release/darwin-arm64/mc -o mc
chmod +x mc
```

下载：

```bash
export AWS_ACCESS_KEY_ID='<管理员发放>'
export AWS_SECRET_ACCESS_KEY='<管理员发放>'

./mc alias set data-minio https://minio-data-xa.xshixun.cn:7443 "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
./mc cp --recursive data-minio/export/<用户名>/<任务名>/ ./downloads/
```

也可以使用脚本：

```bash
bash scripts/local-download-from-minio.sh <用户名>/<任务名> ./downloads
```

## 4. 查看和清理

查看已上传文件：

```bash
mc ls --recursive data-minio/export/<用户名>/<任务名>/
```

确认本地下载完成后，可删除远端数据：

```bash
mc rm --recursive --force data-minio/export/<用户名>/<任务名>/
```

## 注意事项

- 该服务仅用于临时中转，不用于长期保存。
- 文件默认 14 天后自动清理。
- 大目录建议保持 `<用户名>/<任务名>/` 前缀，避免和其他用户混放。
- Pod 内访问集群内地址时必须保留 `.svc.k8s.xa.cluster` 在 `NO_PROXY` 中。
