import struct
import sys
import os

# UF2 Architectural Magic Constants
MAGIC_START_0 = 0x0A324655
MAGIC_START_1 = 0x9E5D5157
MAGIC_END     = 0x0AB16F30
RP2040_FAMILY = 0xe48bff56  # The ID that tells the chip this is an RP2040 binary
TARGET_ADDR = 0x20040000  # Map directly to Scratchpad RAM Bank 4!

def create_uf2(bin_path, uf2_path):
    if not os.path.exists(bin_path):
        print(f"Error: {bin_path} not found. Did you compile your project?")
        sys.exit(1)
        
    with open(bin_path, "rb") as f:
        data = f.read()

    # Split the raw binary into sequential 256-byte data payloads
    chunks = [data[i:i+256] for i in range(0, len(data), 256)]
    num_blocks = len(chunks)

    print(f"Packaging {len(data)} bytes into {num_blocks} UF2 blocks...")

    with open(uf2_path, "wb") as out:
        for block_no, chunk in enumerate(chunks):
            # Pad the final block with null bytes if it's shorter than 256 bytes
            chunk = chunk.ljust(256, b'\x00')
            
            # Flags: 0x00002000 dictates that the structural 'Family ID' field is present
            flags = 0x00002000 
            addr = TARGET_ADDR + (block_no * 256)

            # Pack the 32-byte header according to the hardware specification layout
            header = struct.pack(
                "<IIIIIIII",
                MAGIC_START_0, MAGIC_START_1, flags, addr,
                256, block_no, num_blocks, RP2040_FAMILY
            )
            
            # Construct the complete 512-byte structural UF2 record block
            block = header + chunk
            block += b'\x00' * (476 - len(block))  # Pad interior out to the tail marker
            block += struct.pack("<I", MAGIC_END)  # Affix final closing magic tag
            
            out.write(block)

if __name__ == "__main__":
    create_uf2("blink.bin", "blink.uf2")
    print("Successfully created blink.uf2! Ready to flash.")

