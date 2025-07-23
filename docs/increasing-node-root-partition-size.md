# Increasing node root partition size
Increasing the size of the root EBS block, used for the root file-system, can
be done relatively quickly and without requiring a reboot.

1. Increase the `aws_root_block_size` (GB) for each node in `terraform/env/prod/main.tf`
2. Commit and push to `main` branch. This will trigger `terraform` to perform the disk expansion via the CI pipeline.
    - You could also manually run `terraform apply` on `terraform/env/prod/`; just be sure to commit and push afterwards.
3. On each node:
    - Expand the partition table. This can be done via:
      ```
      parted --list
      # When prompted to Fix/Ignore, choose fix
      Warning: Not all of the space available to /dev/nvme0n1 appears to be used, you
      can fix the GPT to use all of the space (an extra 402653184 blocks) or continue
      with the current setting?
      Fix/Ignore? fix
      ```
    - Expand the root partition (typically partition 1; see output of previous command):
      ```
      parted /dev/nvme0n1
      # Will take you to parted prompt
      (parted) resizepart
      Partition number? 1
      Warning: Partition /dev/nvme0n1p1 is being used. Are you sure you want to continue?
      Yes/No? yes
      End?  [68.7GB]? 100%
      (parted) quit
      ```
    - Expand the ext4 file-system to use 100% of the partition (default action for `resize2fs`):
      ```
      resize2fs /dev/nvme0n1p1
      ```

At this point the file-system should be expanded. Verify via `df -h`.
