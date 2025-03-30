include ../Makefile.base

TESTFILE ?= TestMac.bsv
TOPMODULE ?= mkTestMacSimpleOnce

SCRIPT_DIR = ../scripts
DIR_BSV_GENERATED ?= $(BUILDDIR)

SIMSCRIPT_NAME = ./$(TOPMODULE).sh

MISCFLAGS += -D IS_DEBUG=True

compile:
	mkdir -p $(BUILDDIR)
	bsc -elab -sim -verbose $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -g $(TOPMODULE) $(TESTFILE)
	python3 $(SCRIPT_DIR)/genRam.py && cp bram_*.txt $(BUILDDIR)

link: compile
	bsc -sim $(BLUESIMFLAGS) $(DIRFLAGS) $(RECOMPILEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -e $(TOPMODULE) -o $(BUILDDIR)/$(SIMSCRIPT_NAME) $(BSV_C_EXT_FILES)

simulate: link
	cd $(BUILDDIR) && $(SIMSCRIPT_NAME)

clean:
	rm -rf $(BUILDDIR)

.PHONY: compile simulate clean
.DEFAULT_GOAL := simulate
