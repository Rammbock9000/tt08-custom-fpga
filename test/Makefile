# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= questa
TOPLEVEL_LANG ?= vhdl
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v
PROJECT_SOURCES += project.vhd
PROJECT_SOURCES += Basic_Logic_Element.vhd
PROJECT_SOURCES += C_Block_IO.vhd
PROJECT_SOURCES += FPGA_Simulation.vhd
PROJECT_SOURCES += FPGA_Simulation_Package.vhd
PROJECT_SOURCES += Flipflop.vhd
PROJECT_SOURCES += Four_Way_S_Block.vhd
PROJECT_SOURCES += Input_C_Block.vhd
PROJECT_SOURCES += Input_C_Block_IO.vhd
PROJECT_SOURCES += Logic_Cluster.vhd
PROJECT_SOURCES += Output_C_Block.vhd
PROJECT_SOURCES += Output_C_Block_IO.vhd
PROJECT_SOURCES += Tapped_Shift_Register.vhd
PROJECT_SOURCES += Three_Way_S_Block.vhd
PROJECT_SOURCES += Two_Way_S_Block.vhd
PROJECT_SOURCES += fpga_top.vhd

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VHDL_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
COMPILE_ARGS 		+= -I$(SRC_DIR)

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
