import torch
import os
import socket

def get_ip_address():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    return s.getsockname()[0]

def report_env():
    hostname = socket.gethostname()
    ip_address = get_ip_address()
    rocr_devices = os.getenv("ROCR_VISIBLE_DEVICES")
    hip_devices = os.getenv("HIP_VISIBLE_DEVICES")
    cuda_visible_devices = os.getenv("CUDA_VISIBLE_DEVICES")
    torch_version = torch.__version__
    cuda_available = torch.cuda.is_available()
    curr_device = torch.cuda.current_device()
    device_arch = str(torch.cuda.get_device_name(torch.cuda.current_device()))
    cuda_version = torch.version.cuda
    hip_version = torch.version.hip
    bf16_support = torch.cuda.is_bf16_supported()
    nccl_available = torch.distributed.is_nccl_available()
    nccl_version = torch.cuda.nccl.version()
    cuda_device_count = torch.cuda.device_count()
    print(f"Hostname: {hostname}")
    print(f"IP Address: {ip_address}")
    print(f"Torch version: {torch_version}")
    print(f"CUDA available: {cuda_available} ")
    print(f"CUDA version: {cuda_version} ")
    print(f"HIP version: {hip_version} ")
    print(f"Current device: {curr_device} ")
    print(f"Device arch name: {device_arch} ")
    print(f"CUDA Device count: {cuda_device_count} ")
    print(f"BF16 support: {bf16_support} ")
    print(f"NCCL available: {nccl_available} ")
    print(f"NCCL version: {nccl_version} ")
    print(f"ROCR_VISIBLE_DEVICES: {rocr_devices} ")
    print(f"HIP_VISIBLE_DEVICES: {hip_devices} ")
    print(f"CUDA_VISIBLE_DEVICES: {cuda_visible_devices} ")

report_env()
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f'Using device: {device}')
print()