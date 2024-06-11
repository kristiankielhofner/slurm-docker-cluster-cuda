# Example torch_info output

```command
(/data/conda) [root@slurmctld data]# srun -N2 --gres=gpu:1 python /opt/torch_info.py
Hostname: c1
IP Address: 172.18.0.5
Torch version: 2.3.1+rocm5.7
CUDA available: True 
CUDA version: None 
HIP version: 5.7.31921-d1770ee1b 
Current device: 0 
Device arch name: AMD Instinct MI210 
Device capability: (9, 0) 
CUDA Device count: 1 
BF16 support: True 
NCCL available: True 
NCCL version: (2, 17, 1) 
CUDNN version: 2020000 
ROCR_VISIBLE_DEVICES: 0 
HIP_VISIBLE_DEVICES: None 
CUDA_VISIBLE_DEVICES: None 
Using device: cuda

Hostname: c2
IP Address: 172.18.0.6
Torch version: 2.3.1+rocm5.7
CUDA available: True 
CUDA version: None 
HIP version: 5.7.31921-d1770ee1b 
Current device: 0 
Device arch name: AMD Instinct MI210 
Device capability: (9, 0) 
CUDA Device count: 1 
BF16 support: True 
NCCL available: True 
NCCL version: (2, 17, 1) 
CUDNN version: 2020000 
ROCR_VISIBLE_DEVICES: 0 
HIP_VISIBLE_DEVICES: None 
CUDA_VISIBLE_DEVICES: None 
Using device: cuda

(/data/conda) [root@slurmctld data]#
```

```command
(/data/conda) [root@slurmctld data]# srun -N2 --gres=gpu:1 python /opt/torch_info.py
Hostname: c2
IP Address: 172.29.0.6
Torch version: 2.3.1+rocm6.0
CUDA available: True
CUDA version: None
HIP version: 6.0.32830-d62f6a171
Current device: 0
Device arch name: AMD Radeon RX 7800 XT
Device capability: (11, 0)
CUDA Device count: 1
BF16 support: True
NCCL available: True
NCCL version: (2, 18, 3)
CUDNN version: 3000000
ROCR_VISIBLE_DEVICES: 0
HIP_VISIBLE_DEVICES: None
CUDA_VISIBLE_DEVICES: None
Using device: cuda

Hostname: c1
IP Address: 172.29.0.5
Torch version: 2.3.1+rocm6.0
CUDA available: True
CUDA version: None
HIP version: 6.0.32830-d62f6a171
Current device: 0
Device arch name: AMD Radeon RX 7800 XT
Device capability: (11, 0)
CUDA Device count: 1
BF16 support: True
NCCL available: True
NCCL version: (2, 18, 3)
CUDNN version: 3000000
ROCR_VISIBLE_DEVICES: 0
HIP_VISIBLE_DEVICES: None
CUDA_VISIBLE_DEVICES: None
Using device: cuda

(/data/conda) [root@slurmctld data]#
```

```command
(/data/conda) [root@slurmctld data]# srun -N2 --gres=gpu:2 python /opt/torch_info.py
Hostname: c2
IP Address: 172.29.0.5
Torch version: 2.3.1+cu121
CUDA available: True 
CUDA version: 12.1 
HIP version: None 
Current device: 0 
Device arch name: NVIDIA GeForce RTX 4090 
Device capability: (8, 9) 
CUDA Device count: 2 
BF16 support: True 
NCCL available: True 
NCCL version: (2, 20, 5) 
CUDNN version: 8902 
ROCR_VISIBLE_DEVICES: None 
HIP_VISIBLE_DEVICES: None 
CUDA_VISIBLE_DEVICES: 0,1 
Using device: cuda

Hostname: c1
IP Address: 172.29.0.6
Torch version: 2.3.1+cu121
CUDA available: True 
CUDA version: 12.1 
HIP version: None 
Current device: 0 
Device arch name: NVIDIA GeForce RTX 4090 
Device capability: (8, 9) 
CUDA Device count: 2 
BF16 support: True 
NCCL available: True 
NCCL version: (2, 20, 5) 
CUDNN version: 8902 
ROCR_VISIBLE_DEVICES: None 
HIP_VISIBLE_DEVICES: None 
CUDA_VISIBLE_DEVICES: 0,1 
Using device: cuda

(/data/conda) [root@slurmctld data]#
```
