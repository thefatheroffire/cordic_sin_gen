# Makefile
SIM ?= icarus  # 你可以改为 modelsim, vcs 或 questasim
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/sin_gen.sv

TOPLEVEL = sin_gen
MODULE = test_sin_gen

include $(shell cocotb-config --makefiles)/Makefile.sim