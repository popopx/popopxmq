# POPOPXMQ Release v7.0.1.0

## Build Information

- **Version**: 7.0.1.0
- **Platform**: Linux x86_64
- **Build Date**: 2026-10-06
- **GHC Version**: 9.6.6
- **Cabal Version**: 3.16.1.0

## Binaries

| File | Size | Description |
|------|------|-------------|
| `smp-server-v7.0.1.0-linux-x86_64` | 73 MB | SMP messaging server |
| `ntf-server-v7.0.1.0-linux-x86_64` | 75 MB | Notification server (PostgreSQL) |
| `xftp-server-v7.0.1.0-linux-x86_64` | 76 MB | XFTP file transfer server |
| `xftp-v7.0.1.0-linux-x86_64` | 53 MB | XFTP client |

## Installation

```bash
# Copy binaries to /usr/local/bin
sudo cp smp-server-v7.0.1.0-linux-x86_64 /usr/local/bin/smp-server
sudo cp ntf-server-v7.0.1.0-linux-x86_64 /usr/local/bin/ntf-server
sudo cp xftp-server-v7.0.1.0-linux-x86_64 /usr/local/bin/xftp-server
sudo cp xftp-v7.0.1.0-linux-x86_64 /usr/local/bin/xftp

# Make executable
sudo chmod +x /usr/local/bin/smp-server
sudo chmod +x /usr/local/bin/ntf-server
sudo chmod +x /usr/local/bin/xftp-server
sudo chmod +x /usr/local/bin/xftp
```

## System Requirements

- Linux x86_64 (64-bit)
- glibc 2.17+ (for dynamic linking)
- libgmp (for cryptographic operations)
- libssl (for TLS support)
- libpq (PostgreSQL client library, required for ntf-server)

## Verification

```bash
# Check binary integrity
sha256sum *-v7.0.1.0-linux-x86_64

# Verify executables
./smp-server-v7.0.1.0-linux-x86_64 --version
./ntf-server-v7.0.1.0-linux-x86_64 --version
./xftp-server-v7.0.1.0-linux-x86_64 --version
./xftp-v7.0.1.0-linux-x86_64 --version
```

## Source Code

Full source code available at: https://github.com/popopx/popopxmq

This is a fork of simplexmq v7.0.1.0 with POPOPX branding.

## License

AGPL-3.0
