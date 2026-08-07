zig build-exe rp2.zig -O ReleaseSmall -target thumb-freestanding-eabi -mcpu=cortex_m0plus -T rp2link.ld --name blink -fstrip
zig objcopy -O binary blink blink.bin
python make_uf2.py 
udisksctl unmount -b /dev/disk/by-label/RPI-RP2
