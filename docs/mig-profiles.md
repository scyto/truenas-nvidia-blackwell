# MIG Profiles: RTX PRO 6000 Blackwell

Source: [NVIDIA MIG User Guide — Supported MIG Profiles](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/supported-mig-profiles.html)

Applies to: RTX PRO 6000 Blackwell Workstation Edition, Max-Q Workstation Edition, and Server Edition (96GB).

## GPU Instance Profiles

From `nvidia-smi mig -lgip` on the RTX PRO 6000 Blackwell:

| Profile Name | ID | Memory | SMs | DEC | ENC | JPEG | OFA | CE | Max Instances |
|---|---|---|---|---|---|---|---|---|---|
| MIG 1g.24gb | 14 | 23.62 GiB | 46 | 1 | 1 | 1 | 0 | 1 | 4 |
| MIG 1g.24gb+me | 21 | 23.62 GiB | 46 | 1 | 1 | 1 | 1 | 1 | 1 |
| MIG 1g.24gb+gfx | 47 | 23.62 GiB | 46 | 1 | 1 | 1 | 0 | 1 | 4 |
| MIG 1g.24gb+me.all | 65 | 23.62 GiB | 46 | 4 | 4 | 4 | 1 | 1 | 1 |
| MIG 1g.24gb-me | 67 | 23.62 GiB | 46 | 0 | 0 | 0 | 0 | 1 | 4 |
| MIG 2g.48gb | 5 | 47.38 GiB | 94 | 2 | 2 | 2 | 0 | 2 | 2 |
| MIG 2g.48gb+gfx | 35 | 47.38 GiB | 94 | 2 | 2 | 2 | 0 | 2 | 2 |
| MIG 2g.48gb+me.all | 64 | 47.38 GiB | 94 | 4 | 4 | 4 | 1 | 2 | 1 |
| MIG 2g.48gb-me | 66 | 47.38 GiB | 94 | 0 | 0 | 0 | 0 | 2 | 2 |
| MIG 4g.96gb | 0 | 95.00 GiB | 188 | 4 | 4 | 4 | 1 | 4 | 1 |
| MIG 4g.96gb+gfx | 32 | 95.00 GiB | 188 | 4 | 4 | 4 | 1 | 4 | 1 |

## Profile Suffix Reference

| Suffix | Meaning |
|--------|---------|
| *(none)* | Standard compute profile with media engines |
| `+gfx` | Adds graphics API support (OpenGL, Vulkan, DirectX). New in GB20X architecture |
| `+me` | Includes at least one media engine (NVDEC, NVENC, NVJPG, or OFA) |
| `+me.all` | Allocates **all** available media engines to this instance (no graphics support) |
| `-me` | Excludes all media engines — pure compute only |

## Profile IDs Used in Scripts

The `--mig=` flag and `mig.conf` use numeric profile IDs:

| ID | Profile | Slices | Use Case |
|----|---------|--------|----------|
| 0 | 4g.96gb | 4 | Full GPU compute + all media |
| 5 | 2g.48gb | 2 | Larger compute + media |
| 14 | 1g.24gb | 1 | General compute + media (NVDEC/NVENC) |
| 21 | 1g.24gb+me | 1 | Compute + media + OFA (1 instance only) |
| 32 | 4g.96gb+gfx | 4 | Full GPU compute + all media + graphics APIs |
| 35 | 2g.48gb+gfx | 2 | Larger compute + media + graphics APIs |
| 47 | 1g.24gb+gfx | 1 | Compute + media + graphics APIs |
| 64 | 2g.48gb+me.all | 2 | Larger compute + ALL media engines (1 instance only) |
| 65 | 1g.24gb+me.all | 1 | Compute + ALL media engines (1 instance only) |
| 66 | 2g.48gb-me | 2 | Larger pure compute (no media engines) |
| 67 | 1g.24gb-me | 1 | Pure compute (no media engines) |

## Allowed Slice Configurations

The GPU has 4 slices (each slice = 2 SM partitions). Valid configurations and their media engine distribution:

| Config | Slice #0 | Slice #1 | Slice #2 | Slice #3 | NVENC | NVDEC | NVJPEG | OFA | P2P | GPU Direct RDMA |
|--------|----------|----------|----------|----------|-------|-------|--------|-----|-----|-----------------|
| 1 | 4g (full) | | | | 4 | 4 | 4 | 1 | No | Supported, MemBW proportional to instance size |
| 2 | 2g | 2g | 2g | 2g | 2+2 | 2+2 | 2+2 | 0 | No | " |
| 3 | 2g | 2g | 1g | 1g | 2+1+1 | 2+1+1 | 2+1+1 | 0 | No | " |
| 4 | 1g | 1g | | 2g | 1+1+2 | 1+1+2 | 1+1+2 | 0 | No | " |
| 5 | 1g | 1g | 1g | 1g | 1+1+1+1 | 1+1+1+1 | 1+1+1+1 | 0 | No | " |
| 6 | | 2g | 1g | 1g | 4+0+0 | 4+0+0 | 4+0+0 | 1 | No | " |
| 7 | 1g | 1g | 1g | 1g | 4+0+0+0 | 4+0+0+0 | 4+0+0+0 | 1 | No | " |

Configs 6 and 7 use `+me.all` on the first instance (grabs all 4 media engines + OFA), leaving the remaining instances with no media engines (`-me`).

## Slot Budget (8 slices total)

Example configurations that use all 8 compute slices:

| Config | Instances | Total Memory |
|--------|-----------|-------------|
| `14,14,14,14` | 4x 1g.24gb | 96 GB |
| `47,47,14,14` | 2x 1g.24gb+gfx + 2x 1g.24gb | 96 GB |
| `5,5,14,14` | 2x 2g.48gb + 2x 1g.24gb | 144 GB |
| `35,14,14,14,14` | 1x 2g.48gb+gfx + 4x 1g.24gb | 144 GB |
| `0,0` | 2x 4g.96gb | 192 GB |
| `32,14,14,14,14` | 1x 4g.96gb+gfx + 4x 1g.24gb | 192 GB |

## Notes

- The GPU has 8 SM slices total. 1g profiles use 1 slice, 2g use 2, 4g use 4.
- `+me.all` profiles grab all media engines exclusively — only 1 instance allowed, and it conflicts with other instances that need media engines.
- `+gfx` profiles are unique to RTX PRO 6000 Blackwell (GB20X architecture). They support OpenGL, Vulkan, and DirectX within MIG instances.
- `-me` profiles are useful when you only need CUDA compute and want to leave media engines available for other instances.
- MIG instances are volatile — destroyed on every reboot. Use `nvidia-mig-setup.service` for persistence.
