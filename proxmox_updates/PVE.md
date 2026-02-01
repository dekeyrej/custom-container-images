# PVE/LXC perl updates to support AmazonLinux

AmazonLinux 2023 containers are not supported by default. Provisioning an AmazonLinux 2023 container will fail. Until official support lands, you can (if you dare) patch:
- `/usr/share/perl5/PVE/LXC/Config.pm` -- one word to add (search for amazon in the local file to see where)
- `/usr/share/perl5/PVE/LXC/Setup.pm`  -- 5 new lines to add (search for amazon in the local file to see where)
- `/usr/share/perl5/PVE/LXC/Setup/Amazon.pm` -- new file

Using the files in this repository. This enables amazonlinux-2023 recognition and generates a NetworkManager-compliant config.

⚠️ This patch only affects command-line provisioning via `pct`.