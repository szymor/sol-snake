AS := ca65
LD := ld65

BUILD := build
ROM := $(BUILD)/sol-snake.nes

.PHONY: all check clean

all: $(ROM)

check: $(ROM)
	python3 scripts/check_rom.py $(ROM) $(BUILD)/graphics.chr

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/main.o: src/main.s $(BUILD)/graphics.chr | $(BUILD)
	$(AS) -g -o $@ $<

$(BUILD)/graphics.chr: assets/generate_chr.py | $(BUILD)
	python3 $< $@

$(ROM): $(BUILD)/main.o cfg/nrom.cfg
	$(LD) -C cfg/nrom.cfg -m $(BUILD)/sol-snake.map -o $@ $(BUILD)/main.o

clean:
	rm -rf $(BUILD)
