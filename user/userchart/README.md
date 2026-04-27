# userchart 使用说明

`userchart` 用于在联泰 Kubernetes 集群中为用户创建一个 GPU 任务。它会生成：

- `Deployment`：实际运行的容器任务。
- `Service`：用于暴露容器内端口。
- `PersistentVolumeClaim`：每次任务独立申请的 `/scratch` 本地临时盘。

## 基本使用流程

不要直接修改 `values-template.yaml`。先复制一份自己的 values 文件：

```bash
cp values-template.yaml values-yourname.yaml
```

修改 `values-yourname.yaml` 后部署：

```bash
helm upgrade --install yourname-test ./userchart \
  -n yourname \
  -f values-yourname.yaml
```

查看任务：

```bash
kubectl get pod,svc -n yourname
```

进入容器：

```bash
kubectl exec -it -n yourname deploy/<DeployName> -- bash
```

更新任务：

```bash
helm upgrade yourname-test ./userchart \
  -n yourname \
  -f values-yourname.yaml
```

删除任务：

```bash
helm uninstall yourname-test -n yourname
```

## 常用字段说明

### 必填字段

```yaml
NameSpace: yourname
BaseName: pytorch
ContainerImage: harbor.xa.xshixun.com:7443/llm-course/lab:v2
GPU: stuff-H200
```

字段说明：

- `NameSpace`：自己的 namespace，通常和用户名一致。
- `BaseName`：任务基本名称，用于生成 Deployment、Service 等资源名。
- `ContainerImage`：容器镜像地址。
- `GPU`：调度到哪类 GPU 节点，目前常用为 `stuff-H200`。

### 资源配置

```yaml
Limits:
  GPU: 1
  CPU: 8
  memory: 16Gi
```

字段说明：

- `Limits.GPU`：申请 GPU 数量。
- `Limits.CPU`：CPU 上限，不写默认 `8`。
- `Limits.memory`：内存上限，不写默认 `16Gi`。

注意：申请资源总量不能超过自己 namespace 的 quota。

### 共享内存

```yaml
UseShm: true
ShmSize: 16Gi
```

字段说明：

- `UseShm`：是否挂载 `/dev/shm`。
- `ShmSize`：`/dev/shm` 大小。

训练或推理框架需要较大共享内存时建议开启。

### 副本数

```yaml
Replicas: 1
```

字段说明：

- `Replicas`：Pod 副本数，默认 `1`。

普通单机任务保持 `1` 即可。

## 容器内默认目录

容器内常见目录：

```text
/root        用户 home PVC，来自 pvc-gpfshome-<NameSpace>
/scratch     本次任务独立临时盘，来自 rancher-local-path
/share       公共共享目录，默认只读
/ssdshare    公共缓存/中转目录，默认只读
/gpfs-share  历史共享目录，默认只读
```

默认情况下，`/share`、`/ssdshare`、`/gpfs-share` 都是只读挂载。

## 挂载个人模型/数据 PVC

如果 namespace 下已经有个人模型数据 PVC，例如：

```text
pvc-models-data-yourname
```

可以开启：

```yaml
ModelsDataPVC:
  enabled: true
  claimName: pvc-models-data-yourname
  mountPath: /data
  readOnly: false
```

字段说明：

- `ModelsDataPVC.enabled`：是否挂载个人 PVC，默认关闭。
- `ModelsDataPVC.claimName`：PVC 名称。留空时默认使用 `pvc-models-data-<NameSpace>`。
- `ModelsDataPVC.mountPath`：容器内挂载路径，默认 `/data`。
- `ModelsDataPVC.readOnly`：是否只读挂载，默认 `false`。

## 挂载公共模型权重

公共模型权重默认不挂载。需要使用时在 values 中开启：

```yaml
SharedModels:
  enabled: true
  hostPath: /mnt/gpfs2/hqzy-mg3226/share/public/models
  mountPath: /data/share/models
```

开启后，容器内可以通过以下路径读取公共模型：

```text
/data/share/models
```

例如：

```text
/data/share/models/GLM-4.7-FP8-dynamic
```

说明：

- `SharedModels.enabled`：是否挂载公共模型权重，默认 `false`。
- `SharedModels.hostPath`：宿主机公共模型目录，一般不要改。
- `SharedModels.mountPath`：容器内模型目录，默认 `/data/share/models`。
- 该挂载始终是只读的，适合读取模型权重参数。

## 端口和域名

如果容器内有 Web 服务，可以配置额外端口：

```yaml
ExtraPort: 7860
```

如果需要 Ingress 域名：

```yaml
IngressHost: test.xa.xshixun.cn
```

注意域名后缀是 `.cn`。

## 自定义启动命令

默认启动命令会让容器常驻：

```bash
while true; do sleep 30; done
```

如果要启动自己的程序，可以配置：

```yaml
Command: '["python", "/app/app.py"]'
Args: ''
```

或使用 bash：

```yaml
Command: '["bash", "-lc", "--"]'
Args: '["cd /data/yourname && python train.py"]'
```

## 高级配置

### IB 网络

```yaml
UseIB: true
```

开启后会申请 RDMA 相关资源。只有明确需要 IB/RDMA 的任务才开启。

### EGL 渲染库

```yaml
UseEGL: true
```

开启后会通过 initContainer 注入 NVIDIA EGL 相关库。

### 关闭 `/gpfs-share`

```yaml
NoGPFSSHARE: true
```

开启后不挂载 `/gpfs-share`。

## 完整示例

```yaml
NameSpace: yourname
BaseName: glm-test
ContainerImage: harbor.xa.xshixun.com:7443/llm-course/lab:v2
GPU: stuff-H200

Limits:
  GPU: 1
  CPU: 8
  memory: 32Gi

UseShm: true
ShmSize: 16Gi

ModelsDataPVC:
  enabled: true
  claimName: pvc-models-data-yourname
  mountPath: /data
  readOnly: false

SharedModels:
  enabled: true
  hostPath: /mnt/gpfs2/hqzy-mg3226/share/public/models
  mountPath: /data/share/models

Command: '["bash", "-lc", "--"]'
Args: '["while true; do sleep 3600; done"]'
```

部署：

```bash
helm upgrade --install yourname-glm-test ./userchart \
  -n yourname \
  -f values-yourname.yaml
```

进入容器后检查：

```bash
ls -lah /data
ls -lah /data/share/models
ls -lah /data/share/models/GLM-4.7-FP8-dynamic
```

## 常见排查命令

查看 Helm release：

```bash
helm list -n yourname
```

查看 Pod：

```bash
kubectl get pod -n yourname -o wide
```

查看 Pod 事件：

```bash
kubectl describe pod -n yourname <pod-name>
```

查看日志：

```bash
kubectl logs -n yourname <pod-name> --tail=100
```

检查挂载：

```bash
kubectl exec -it -n yourname <pod-name> -- df -h
kubectl exec -it -n yourname <pod-name> -- ls -lah /data /share /ssdshare
```

## 注意事项

- 修改 values 后，需要执行 `helm upgrade` 才会生效。
- 已经运行的 Pod 不会自动获得新的挂载，需要通过 Helm 更新触发重建。
- `/share`、`/ssdshare`、`/gpfs-share` 默认只读，普通任务不要直接写这些目录。
- 公共模型权重路径 `/data/share/models` 只有在 `SharedModels.enabled: true` 时才会出现。
- 删除 Helm release 会删除 Deployment、Service 和本次任务的 `/scratch` PVC；不要把长期重要数据只放在 `/scratch`。

