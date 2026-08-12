---
title: 互连、RDMA 与集合通信
description: 从 PCIe、NVLink 到 InfiniBand，理解大模型集群的数据路径、集合通信算法与拓扑优化。
---

# 互连、RDMA 与集合通信

把更多 GPU 接到一起，不等于得到一块线性放大的 GPU。参数、梯度、激活或 token 要穿过多层互连；任何一层带宽不足、绕路或出现尾延迟，计算单元都会等待。分析时应沿真实路径确认数据从哪块显存出发、经过哪些交换层、由哪个 rank 消费。

<TopologyExplorer preset="collectives" />

## 先建立层次化视角

一条典型的跨节点 GPU 通信路径可能是：发送 GPU 的 HBM → GPU I/O 接口 → PCIe Switch → RNIC → InfiniBand 交换网络 → 对端 RNIC → 对端 PCIe Switch → 接收 GPU 的 HBM。节点内若有 NVLink/NVSwitch，GPU 间数据可走专用的 Scale-Up Fabric；节点外则通常进入 InfiniBand 或 RoCE 这类 Scale-Out 网络。CPU 仍参与控制面、内存注册和任务发起，但在 GPUDirect RDMA 生效时，数据面无需先落到主机内存。

通信时间可简化为 `T ≈ α × 消息轮次 + 数据量 / 有效带宽`。`α` 包含发起、同步和网络跳数；有效带宽受最窄链路、共享与拥塞限制。小消息更怕延迟，大消息更怕带宽，因此通信库需按尺寸选择算法与协议。

## PCIe：设备连接的地基，而不是一根理想总线

PCIe 用 Root Complex、Switch 和 Endpoint 组成树状拓扑。GPU 与网卡即使都标称 x16，也可能挂在不同 CPU Socket、不同 Root Complex 下；此时一次 GPU—NIC 传输可能跨 NUMA 互连，甚至退化为主机内存中转。相反，当 GPU 和 RNIC 位于同一个 PCIe Switch 下，Peer-to-Peer 数据路径更短，更容易接近 GPUDirect RDMA 的目标性能。NVIDIA 的 [GPUDirect RDMA 拓扑说明](https://developer.nvidia.com/blog/benchmarking-gpudirect-rdma-on-modern-server-platforms/)也明确展示了 PCIe 拓扑与 NUMA 效应会成为带宽瓶颈。

不能把链路速率直接当作应用可用吞吐。以 PCIe 6.0 为例，[PCI-SIG 官方 FAQ](https://pcisig.com/faq?field_category_value%5B%5D=pci_express_6.0&keys=PAM4)给出的 x16 双向带宽上限是 256 GB/s；这一代通过 PAM4 达到 64 GT/s，并引入 256 Byte FLIT、低延迟 FEC 与 CRC。这里的“双向”是两个方向之和，协议头、流控、包长、读写方向和上游共享都会继续降低业务有效值。工程测量必须注明单向还是双向、读还是写、单设备还是多设备并发。

## NVLink 与 NVSwitch：扩大节点内一致的高速域

NVLink 是面向 GPU 高带宽、低延迟访问设计的专用互连。直连 NVLink 让若干 GPU 成对连接，但每块 GPU 的链路数量有限；规模增大后，如果链路被拆给多个邻居，不同 GPU 对之间的带宽与跳数可能不一致。NVSwitch 将点到点链路接入交换芯片，提供更接近任意 GPU 对之间等带宽的交换结构。以 Hopper HGX 为例，NVIDIA 的 [NVLink/NVSwitch 架构说明](https://developer.nvidia.com/blog/nvidia-nvlink-and-nvidia-nvswitch-supercharge-large-language-model-inference/)记录了单 GPU 900 GB/s 的第四代 NVLink 连接，并强调 NVSwitch 下任意 GPU 对同时通信时的非阻塞特性。

这类 Scale-Up 域特别适合频繁触发 AllReduce/AllGather 的张量并行，也有利于专家并行的 AllToAll。但 NVSwitch 不是“自动共享显存”，框架仍要明确数据分片；域外流量最终还会经过 RNIC，不能用节点内指标推断跨节点性能。

<TradeoffExplorer preset="interconnect" />

## InfiniBand 与 RDMA：把数据面从主机协议栈中解耦

RDMA 的关键不是“网卡更快”，而是数据路径与传统 socket 不同。应用预先注册内存、创建 Queue Pair，再通过 Work Queue 提交操作；RNIC 执行 DMA 和传输，并在 Completion Queue 留下结果。注册减少重复映射，也带来 Pinned Memory 与权限管理成本。

InfiniBand 原生提供 RDMA 传输、子网管理、服务等级与虚拟通道；RoCE 则把 RDMA 承载在以太网上，两者不能只按端口速率比较。InfiniBand Fat-Tree/Clos 网络是否无阻塞，取决于叶脊上行是否足够、路由能否分散等价路径、作业是否被放在连续叶交换机或同一 rail。NVIDIA 的 [InfiniBand 自适应路由文档](https://docs.nvidia.com/networking/display/NVIDIAMLNXOSUserManualv3104400LTS/Subnet%2BManager)说明，自适应路由会依据网络当时状态把流量移到较不拥塞的多路径；它改善热点，却不能弥补结构性的过订阅。

GPUDirect RDMA 允许 RNIC 直接读写 GPU 显存，避免 GPU→CPU DRAM→RNIC 的额外复制。它依赖 GPU、RNIC、驱动、Peer Memory 模块和 PCIe 拓扑共同满足条件。NVIDIA 给出的 [GPUdev/GPUDirect 数据路径](https://developer.nvidia.com/blog/optimizing-inline-packet-processing-using-dpdk-and-gpudev-with-gpus/)指出，GPU 与 NIC 共挂一个专用 PCIe Switch 是最大化内部吞吐的理想拓扑。若 NIC 离目标 GPU 太远，即使网络 Fabric 空闲，主机内路径也可能先饱和。

## 集合通信：逻辑原语决定流量形状

集合通信不是“所有 GPU 互相发同样的数据”。不同原语形成完全不同的流量：

| 原语 | 每个 rank 最终得到什么 | AI 工作负载中的典型位置 |
| --- | --- | --- |
| AllReduce | 所有输入规约后的完整结果 | 数据并行梯度同步、张量并行局部和 |
| ReduceScatter | 规约结果的一段 | ZeRO/FSDP 梯度分片 |
| AllGather | 所有 rank 分片拼接后的完整结果 | 参数或激活重组 |
| AllToAll | 每个 rank 发给每个目标的不同分片 | MoE token 分发与回收 |
| Broadcast | 根 rank 的完整缓冲区 | 初始化、状态同步 |
| Send/Recv | 指定邻居间点对点数据 | 流水线并行激活 |

[NCCL 集合通信定义](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/usage/collectives.html)还指出，ReduceScatter 后接 AllGather 在数学上等价于 AllReduce。这一分解很重要：当优化器状态本来就按 rank 分片时，不必让每张卡先拿到完整梯度再切开，可以让通信结果直接落到所属分片，减少峰值显存与不必要的数据移动。

## Ring、Tree 与分层算法

Ring AllReduce 分成 ReduceScatter 与 AllGather。`p` 个 rank 围成环，每轮发送一个分块；每个 rank 的总通信量接近 `2 × (p-1)/p × N`，适合大消息，但约 `2(p-1)` 轮会累积延迟。Tree 先向上规约、再向下广播，轮数近似 `log p`，更适合小消息，但上层链路可能成为热点。

真实系统常先在 NVLink 域内规约，再由代表 GPU 通过 InfiniBand 跨节点规约，最后在节点内广播。多 RNIC 节点还要让 GPU 使用最近的 NIC，并把通道分布到不同 rail；所有 GPU 争用一张 NIC 会制造出口热点。

AllToAll 更难优化，因为流量天然接近全交换，而且 MoE 路由可能让专家负载不均。即使总字节数不大，某个热点专家也会拖住整个同步点。优化顺序应是先控制 token balance 与容量，再检查 rank 到拓扑的映射、分块和并发；不能指望网络算法替业务层完全修复倾斜。

## NCCL 如何把原语映射到硬件

NCCL 会发现 GPU、CPU、PCIe、NVLink 与网卡拓扑，构造通信图，并按消息大小与平台能力选择算法和协议。当前 [NCCL 环境变量文档](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/env.html)列出 Ring、Tree、CollNet、NVLS 等算法，以及 Simple、LL、LL128 协议；官方同时不建议为了追求某次 benchmark 数字而长期强制协议，因为错误地在不支持的平台启用 LL128 甚至可能产生数据损坏。环境变量更适合诊断和受控实验，生产默认应让库基于拓扑选择，再用稳定证据覆盖个别异常。

每个 rank 必须以相同顺序发起匹配的 collective，否则其他 rank 可能无限等待。CUDA Stream 只保证本地排队，不会修复跨 rank 控制流分叉；所谓“随机 NCCL hang”也可能是某个 rank 提前 OOM 或未进入同一原语。[TACCL 论文](https://arxiv.org/abs/2111.04867)还展示了按拓扑自动合成调度的价值：链路不对称、并发冲突与分块共同决定性能，不能只判断网络是否连通。

## 拥塞、尾延迟与在网规约

大模型通信往往同步发生：反向传播到同一层时，成百上千个 rank 同时发出梯度，形成周期性 burst。平均链路利用率不高也可能出现短时队列堆积。Fat-Tree 中错误的 ECMP 哈希、rail 映射或作业交叠会让少数上行过热；坏线缆、FEC 重传和降速端口则会制造稳定的 straggler。应把端口计数器、队列/拥塞标记、路由和 NCCL collective 延迟放到同一时间轴，而不是只观察 GPU 利用率。

在网规约把部分 Reduce 操作下沉到交换网络，减少相同数据反复穿越端点。NVIDIA 的 [SHARP 官方说明](https://docs.nvidia.com/networking/display/sharpv390/introduction)强调，聚合节点越向上，后续网络中承载的数据越少，同时 CPU/GPU 无需处理全部规约步骤。但 SHARP 只加速可支持的规约类型，仍需正确配置通信库、作业管理器和 Fabric；它不会改善 AllToAll 的专家倾斜，也不会修复 PCIe 侧的瓶颈。

## 一套可复现的诊断顺序

1. **确认问题边界**：记录模型并行组合、rank 数、消息尺寸分布，区分小消息延迟与大消息带宽。
2. **画真实拓扑**：采集 GPU—GPU、GPU—NIC、NIC—NUMA 关系，标记 PCIe Switch、NVLink 域和 rail，不从服务器型号猜测。
3. **逐层基线**：先测单 GPU/单 NIC，再测节点内 P2P、两节点 RDMA，最后测全规模 collective。
4. **测量竞争**：增加多 GPU、多 NIC 并发和双向流量，观察共享上游是否饱和。
5. **检查尾部而非均值**：记录 collective 的 P50/P95/P99、最慢 rank、端口错误与重传。
6. **最后再调算法**：固定拓扑与负载做 A/B，并保留环境、拓扑和日志以便回滚。

设计评审最终要确认：张量并行组是否落在同一 NVLink 域，GPU 是否使用最近的 RNIC，并行组是否映射到合适的 rail，多租户时叶脊是否仍无阻塞，报告是否区分理论、单流与全作业带宽。只有这些问题有可验证答案后，Ring、Tree、NVLS 或 SHARP 才是可靠的优化手段。

## 拓扑验收：从资产表到通信矩阵

拓扑验收不能只保存一张机柜连线图。每台服务器都应生成机器可读的资产快照，至少关联 GPU UUID、PCIe 地址、CPU NUMA 节点、NVLink 邻接关系、RNIC 端口、交换机端口和 rail。调度器分配作业后，再把 rank、并行组和上述资产关联起来。这样发生慢通信时，才能从最慢 rank 反查具体 GPU—NIC—叶交换机路径，而不是在几千个端口中盲目排查。固件升级、换卡或重新布线后必须重新生成快照并与基线比较，避免物理变化未进入调度视图。

验收测试应形成由近到远的矩阵。节点内先覆盖所有 GPU 对的单向与双向 P2P，确认同类路径的带宽和延迟分布；再让每张 GPU 分别访问每个本机 RNIC，找出跨 Socket 或共享上游路径；跨节点测试则固定消息尺寸，分别覆盖同叶、跨叶、同 rail 与跨 rail。结果不只记录平均值，还要保存中位数、尾延迟、离群设备和测试时的链路计数器。任何“备用路径”即使不会被正常调度，也应测试，因为故障切换后它可能成为生产路径。

全规模 collective 验收要同时覆盖小消息与大消息。小消息可以暴露软件发起、同步、路由跳数和树算法的问题；大消息更容易暴露链路降速、过订阅与共享 PCIe 上游。测试进程的 CPU 绑核、GPU 顺序、rank 映射、NCCL 版本和环境变量必须随结果归档，否则两次测试的差异无法归因。验收阈值应基于同型号设备的分布，例如低于同组中位数一定比例即隔离复查，而不是用无法达到的理论峰值一刀切。

## 常见故障指纹与定位分支

**固定 GPU 对持续偏慢**，而换到其他节点后恢复，优先检查本机 PCIe 链路宽度、NVLink 错误、GPU 降频和 Peer Access；若固定 GPU 到所有 RNIC 都慢，则进一步检查其 PCIe 上游。**固定 RNIC 下的多张 GPU 同时变慢**，更像是 RNIC 端口、PCIe Switch 或 CPU Socket 出口问题。**固定远端机架变慢**则应沿叶脊路径检查降速端口、路由集中和光模块误码。

**吞吐周期性锯齿且端口无硬错误**，常见原因是多个作业的同步 burst 相位重合、拥塞控制反复收敛，或后台 checkpoint 与梯度通信争用同一 rail。此时单独重跑通信 benchmark 可能完全正常，必须对齐训练 step、NCCL 时序、checkpoint 窗口和交换机队列。可以错开 checkpoint、隔离存储网络或调整作业放置做受控实验，不能仅因重启后暂时恢复就判定故障消失。

**少量 collective 偶发超长但最终完成**，要先区分网络重传与计算 straggler。若最慢 rank 在进入 collective 前已经落后，应检查数据加载、GPU 纠错、内核执行和主机调度；若各 rank 同时进入而某条路径完成晚，再检查链路。若始终在相同 tensor 或相同原语停住，则核对所有 rank 的调用顺序、count、dtype 和 communicator，避免把控制流不一致错误归因给网络。

故障隔离后的恢复也需要验收。禁用一个 RNIC、关闭一条上行或迁移一个节点后，应确认作业是按设计快速失败、重建 communicator，还是通过备用路径继续；继续运行时还要验证带宽下降是否在容量预算内。仅验证“ping 仍通”无法证明 collective 可用。恢复完成后应重跑对应层级的通信矩阵，并确认端口错误不再增长、rank 映射未跨越新的慢路径，最后才解除节点隔离。

## 来源

- [PCI-SIG：PCI Express 6.0 FAQ](https://pcisig.com/faq?field_category_value%5B%5D=pci_express_6.0&keys=PAM4)
- [NVIDIA：NCCL Collective Operations](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/usage/collectives.html)
- [NVIDIA：NCCL Environment Variables](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/env.html)
- [NVIDIA：NVLink and NVSwitch for LLM Inference](https://developer.nvidia.com/blog/nvidia-nvlink-and-nvidia-nvswitch-supercharge-large-language-model-inference/)
- [NVIDIA：Benchmarking GPUDirect RDMA](https://developer.nvidia.com/blog/benchmarking-gpudirect-rdma-on-modern-server-platforms/)
- [NVIDIA：InfiniBand Subnet Manager and Adaptive Routing](https://docs.nvidia.com/networking/display/NVIDIAMLNXOSUserManualv3104400LTS/Subnet%2BManager)
- [NVIDIA：SHARP Introduction](https://docs.nvidia.com/networking/display/sharpv390/introduction)
- [Shah et al.：TACCL: Guiding Collective Algorithm Synthesis using Communication Sketches](https://arxiv.org/abs/2111.04867)
