import struct
import os
import sys

MAGIC_START_0 = 0x0A324655
MAGIC_START_1 = 0x9E5D5157
MAGIC_END     = 0x0AB16F30
RP2040_FAMILY = 0xe48bff56  
BASE_RAM_ADDR = 0x20000000  

def create_uf2(bin_path, uf2_path):
    if not os.path.exists(bin_path):
        print(f"Error: {bin_path} not found.")
        sys.exit(1)
        
    with open(bin_path, "rb") as f:
        data = f.read()

    # Split the raw binary into clean 256-byte data chunks
    chunks = []
    for i in range(0, len(data), 256):
        chunk = data[i:i+256]
        if len(chunk) < 256:
            chunk = chunk.ljust(256, b'\x00')
        chunks.append(chunk)
        
    num_blocks = len(chunks)
    print(f"Custom Packing: {len(data)} bytes into {num_blocks} perfect sectors...")

    # The 216-byte padding that guarantees a standard 512-byte hardware sector layout grid
    datapadding = b'\x00' * (512 - 256 - 32 - 4)

    with open(uf2_path, "wb") as out:
        for block_no, chunk in enumerate(chunks):
            flags = 0x00002000 
            addr = BASE_RAM_ADDR + (block_no * 256)

            # Pack 32-byte header block
            header = struct.pack(
                "<IIIIIIII",
                MAGIC_START_0, MAGIC_START_1, flags, addr,
                256, block_no, num_blocks, RP2040_FAMILY
            )
            
            # Form complete 512-byte block structure: Header + Data + Padding + Footer
            block = header + chunk + datapadding + struct.pack("<I", MAGIC_END)
            assert len(block) == 512
            out.write(block)

if __name__ == "__main__":
    # CRITICAL TRACKING: Read and write directly from the root directory
    create_uf2("zig-out/blink.bin", "zig-out/blink.uf2")
    print("Standalone creation successful!")
