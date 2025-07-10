# macOS Build Instructions

## macOS Sequoia ARM64 (Apple Silicon) Support

MiniDB has been enhanced to build and run natively on macOS Sequoia with ARM64 architecture (Apple Silicon M1/M2/M3 chips).

### Platform Detection

The build system automatically detects your platform:

```bash
# Check your platform
uname -s  # Should show: Darwin
uname -m  # Should show: arm64 (Apple Silicon) or x86_64 (Intel)
```

### Building on macOS

```bash
# Clean and build (automatic platform detection)
make clean && make all

# The Makefile will automatically:
# - Detect macOS (Darwin)
# - Detect ARM64 architecture
# - Add appropriate compiler flags:
#   -arch arm64 -DMACOS_ARM64 -DMACOS
```

### Platform-Specific Features

#### Compiler Flags Added:
- `-arch arm64` - Target ARM64 architecture
- `-DMACOS_ARM64` - ARM64-specific code paths
- `-DMACOS` - macOS-specific code paths

#### Code Adaptations:
- **Memory Alignment**: Proper 8-byte alignment for ARM64
- **Printf Formats**: Correct format specifiers for 64-bit types
- **System Includes**: macOS-specific headers

### Testing on macOS

```bash
# Run platform compatibility test
make platformtest

# Expected output:
# Platform: Darwin arm64
# Platform test completed!
```

### macOS-Specific Considerations

#### Memory Alignment
ARM64 requires proper memory alignment. WAL records use:
```c
__attribute__((packed, aligned(8)))
```

#### Format Specifiers
macOS uses different printf formats for 64-bit integers:
```c
#ifdef MACOS
    printf("LSN: %llu\n", (unsigned long long)lsn);
#else
    printf("LSN: %lu\n", (unsigned long)lsn);
#endif
```

### Troubleshooting

#### Build Issues
```bash
# If you get architecture errors:
file minidb_server
# Should show: Mach-O 64-bit executable arm64

# Force clean rebuild:
make clean && make all
```

#### Runtime Issues
```bash
# Check if binaries are ARM64:
lipo -info minidb_server minidb_client

# Should show: Non-fat file: minidb_server is architecture: arm64
```

### Performance on Apple Silicon

MiniDB runs natively on Apple Silicon with optimizations:
- Native ARM64 execution (no Rosetta translation)
- Optimized memory alignment
- Platform-specific system calls

### Compatibility Matrix

| Platform | Architecture | Status | Notes |
|----------|-------------|--------|-------|
| macOS Sequoia | ARM64 (M1/M2/M3) | ✅ Supported | Native build |
| macOS Sequoia | x86_64 (Intel) | ✅ Supported | Native build |
| macOS Monterey+ | ARM64 | ✅ Supported | Should work |
| macOS Monterey+ | x86_64 | ✅ Supported | Should work |
| Linux | x86_64 | ✅ Supported | Original target |
| Linux | ARM64 | ⚠️ Untested | Should work |

The build system automatically handles all platform differences, so the same `make all` command works across all supported platforms.