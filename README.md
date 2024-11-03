# action-download-unpack-debs

An action that will create an unpacked but not yet configured Debian root filesystem.

## Environment Variables

| Name            | Default Value                | Description |
|-----------------|------------------------------|-------------|
| ARCH            | amd64                        | Target architecture |
| RELEASE         | bookworm                     | Debian release |
| EXTRA_PACKAGES  | ""                           | Space-separated list of additional packages to download |
| OMIT_REQUIRED   | false                        | If set to true, then priority required packages will not be automatically downloaded |
| MIRROR          | http://deb.debian.org/debian | URL of the primary Debian mirror to use |
| EXTRA_MIRRORS   | ""                           | Space-separated list of additional mirrors to include |
| COMPONENTS      | "main"                       | Space-separated list of components (e.g., "main contrib non-free") |

