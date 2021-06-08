DC_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Output directory
DC_PREFIX ?= $(shell pwd)

# Set to true to disable fancy / colored output
DC_NO_FANCY ?=

FROM_IMAGE ?= "registry.local/dubodubonduponey/debian:bullseye-2021-06-01"
TARGET_PLATFORM ?= linux/amd64,linux/arm/v7,linux/s390x,linux/arm64
TARGET_TAGS ?=

# Fancy output if interactive
ifndef DC_NO_FANCY
    NC := \033[0m
    GREEN := \033[1;32m
    ORANGE := \033[1;33m
    BLUE := \033[1;34m
    RED := \033[1;31m
endif

# Helper to put out nice title
define title
	@printf "$(GREEN)----------------------------------------------------------------------------------------------------\n"
	@printf "$(GREEN)%*s\n" $$(( ( $(shell echo "☆ $(1) ☆" | wc -c ) + 100 ) / 2 )) "☆ $(1) ☆"
	@printf "$(GREEN)----------------------------------------------------------------------------------------------------\n$(ORANGE)"
endef

define footer
	@printf "$(GREEN)> %s: done!\n" "$(1)"
	@printf "$(GREEN)____________________________________________________________________________________________________\n$(NC)"
endef


downloader:
	$(call title, $@)
	$(shell command -v cue > /dev/null || { echo "You need cue installed"; exit 1; })
	cue --inject from_image=$(FROM_IMAGE) \
		${EXTRAS} \
		downloader $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	$(call footer, $@)

overlay:
	$(call title, $@)
	$(shell command -v cue > /dev/null || { echo "You need cue installed"; exit 1; })
	cue --inject from_image=$(FROM_IMAGE) \
		${EXTRAS} \
		overlay $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	$(call footer, $@)

builder:
	$(call title, $@)
	$(shell command -v cue > /dev/null || { echo "You need cue installed"; exit 1; })
	cue --inject from_image=$(FROM_IMAGE) \
		${EXTRAS} \
		--inject platforms=$(TARGET_PLATFORM) \
		--inject tags=${TARGET_TAGS} \
		builder $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	$(call footer, $@)

runtime:
	$(call title, $@)
	$(shell command -v cue > /dev/null || { echo "You need cue installed"; exit 1; })
	cue --inject from_image=$(FROM_IMAGE) \
		${EXTRAS} \
		--inject platforms=$(TARGET_PLATFORM) \
		--inject tags=${TARGET_TAGS} \
		runtime $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	$(call footer, $@)

lint:
	$(call title, $@)
	$(DC_MAKEFILE_DIR)/hack/lint.sh
	$(call footer, $@)

test:
	$(call title, $@)
	$(DC_MAKEFILE_DIR)/hack/test.sh
	$(call footer, $@)
