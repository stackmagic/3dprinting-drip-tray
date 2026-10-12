OPENSCAD ?= openscad
SCAD     := drip_tray.scad
BUILD    := build

VIEWS := assembly exploded section tray grid grid_print
PNGS  := $(VIEWS:%=$(BUILD)/%.png)
STLS  := $(BUILD)/tray.stl $(BUILD)/grid.stl $(BUILD)/print_plate.stl

PNG_FLAGS := --render --imgsize=1600,1200 --colorscheme=Tomorrow --autocenter --viewall

# Camera rotation per view (rot_x,rot_y,rot_z); distance comes from --viewall.
CAM_assembly   := 55,0,25
CAM_exploded   := 65,0,25
CAM_section    := 70,0,-30
CAM_tray       := 55,0,25
CAM_grid       := 55,0,25
CAM_grid_print := 55,0,25

.DEFAULT_GOAL := help
.PHONY: help all images stl review clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-8s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: review stl ## Render screenshots, review page and STL files

images: $(PNGS) ## Render all screenshots into build/

stl: $(STLS) ## Export printable STL files: each part, and both side by side

review: $(BUILD)/review.html ## Build build/review.html showcasing the assembly and parts

clean: ## Remove build/
	rm -rf $(BUILD)

$(BUILD):
	mkdir -p $@

$(BUILD)/%.png: $(SCAD) | $(BUILD)
	$(OPENSCAD) $(PNG_FLAGS) --camera=0,0,0,$(CAM_$*),0 -D 'part="$*"' -o $@ $<

$(BUILD)/tray.stl: $(SCAD) | $(BUILD)
	$(OPENSCAD) -D 'part="tray"' -o $@ $<

$(BUILD)/grid.stl: $(SCAD) | $(BUILD)
	$(OPENSCAD) -D 'part="grid_print"' -o $@ $<

$(BUILD)/print_plate.stl: $(SCAD) | $(BUILD)
	$(OPENSCAD) -D 'part="print_plate"' -o $@ $<

$(BUILD)/dimensions.echo: $(SCAD) | $(BUILD)
	$(OPENSCAD) -o $@ $<

$(BUILD)/review.html: tools/review.py $(SCAD) $(BUILD)/dimensions.echo $(PNGS)
	python3 tools/review.py $(SCAD) $(BUILD)/dimensions.echo $@
