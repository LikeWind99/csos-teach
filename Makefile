BUILD = ./build
SRC = ./src
TEST = ./test
INFO = ./info
INC = $(SRC)/inc
CFLAGS = -gdwarf-2 -O0 -c -m32 -I$(INC) -fno-pie -fno-stack-protector -nostdlib -nostdinc

$(BUILD)/test/%.bin: $(TEST)/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -g -f bin $< -o $@

$(BUILD)/%.o: $(SRC)/%.asm
	$(shell mkdir -p $(dir $@))
	nasm -g -f elf32 $< -o $@

$(BUILD)/%.o: $(SRC)/%.c
	$(shell mkdir -p $(dir $@))
	x86_64-elf-gcc $(CFLAGS) $< -o $@

$(BUILD)/%.o: $(SRC)/%.S
	$(shell mkdir -p $(dir $@))
	x86_64-elf-gcc $(CFLAGS) $< -o $@

$(BUILD)/boot.bin: $(BUILD)/boot/boot.o
	$(shell mkdir -p $(dir $@))
	x86_64-elf-ld -m elf_i386 -Ttext=0x7c00 $^ -o $(BUILD)/boot.elf
	x86_64-elf-objcopy -O binary $(BUILD)/boot.elf $(BUILD)/boot.bin

$(BUILD)/kernel.bin: $(BUILD)/kernel/start.o \
	$(BUILD)/kernel/kernel.o \
	$(BUILD)/kernel/tty.o \
	$(BUILD)/kernel/memory.o \
	$(BUILD)/kernel/gdt.o \
	$(BUILD)/kernel/kernel32.o
	$(shell mkdir -p $(dir $@))
	x86_64-elf-ld -m elf_i386 -Ttext=0x7e00 $^ -o $(BUILD)/kernel.elf
	x86_64-elf-objcopy -O binary $(BUILD)/kernel.elf $(BUILD)/kernel.bin

$(BUILD)/kernel32.elf: $(BUILD)/kernel32/start.o \
	$(BUILD)/kernel32/kernel.o
	$(shell mkdir -p $(dir $@))
	x86_64-elf-ld -m elf_i386 -T $(SRC)/kernel32.lds $^ -o $@

.PHONY: master
master: $(BUILD)/boot.bin \
	$(BUILD)/kernel.bin \
	$(BUILD)/kernel32.elf
	dd if=$(BUILD)/boot.bin of=master.img bs=512 count=1 conv=notrunc
	dd if=$(BUILD)/kernel.bin of=master.img bs=512 count=9 seek=1 conv=notrunc
	dd if=$(BUILD)/kernel32.elf of=master.img bs=512 count=500 seek=10 conv=notrunc
	${TOOL_PREFIX}readelf -a $(BUILD)/kernel32.elf > $(INFO)/kernel32.txt

.PHONY: clean
clean:
	@rm -rf $(BUILD)/*
	@rm -rf $(INFO)/*

.PHONY: bochs
bochs: clean master
	bochsdbg -q -f bochsrc.bxrc

.PHONY: qemu
qemu: clean master
	qemu-system-i386w -s -S -m 32M -drive file=master.img,index=0,media=disk,format=raw

.PHONY: test_chs
test_chs: $(BUILD)/test/read_disk_chs.bin
	dd if=$(BUILD)/test/read_disk_chs.bin of=master.img bs=512 count=1 conv=notrunc
	bochsdbg -q -f bochsrc.bxrc

.PHONY: test_lba
test_lba: $(BUILD)/test/read_disk_lba.bin
	dd if=$(BUILD)/test/read_disk_lba.bin of=master.img bs=512 count=1 conv=notrunc
	bochsdbg -q -f bochsrc.bxrc