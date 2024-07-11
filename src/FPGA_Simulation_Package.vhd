----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.06.2020 13:51:04
-- Design Name: 
-- Module Name: FPGA_Simulation_Package - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package fpga_helper_functions is 
    -- return minimum number of bits needed to represent X as unsigned number
    function get_word_size(X : integer) return integer;
end package fpga_helper_functions;

package body fpga_helper_functions is
    function get_word_size(X : integer) return integer is
        variable word_size : integer := 1;
    begin
        while (2**word_size < X+1) loop
            word_size := word_size + 1;
        end loop;
        return word_size;
    end function;
end package body fpga_helper_functions;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.fpga_helper_functions.all;

package fpga_simulation_package is
    
    generic (
        ----------------
        -- SIMULATION --
        ----------------
        -- when inserting the bitstream it is possible to configure signals in a way 
        -- that there are asynchronous cycles which make simulation impossible
        -- additionally, select inputs to multiplexers can be set such that a non-existing input is requested
        -- the simulation tool does not allow that :(
        -- if simulation=true: add latches to only evaluate outputs when bitstream is fully inserted
        -- i.e. when bit_stream_enable='0'
        -- for synthesis these latches are not needed so simulation can be set to false!
        simulation : boolean := true;
        
        ---------------------------
        -- CONSTANT DECLARATIONS --
        ---------------------------
        -- number of logic clusters in x direction
        fpga_width : integer := 2;
        -- number of logic clusters in y direction
        fpga_height : integer := 2;
        -- number of I/O pins to each connection block at the edges of the FPGA
        inputs_per_c_block : integer := 2;
        outputs_per_c_block : integer := 2;
        -- number of input bits to a LUT
        lut_size : integer := 2;
        -- number of BLEs per logic cluster
        num_bles_per_cluster : integer := 2;
        -- number of cluster inputs
        inputs_to_cluster : integer := 3;
        -- number of parallel wires in the routing network IN BOTH DIRECTIONS
        -- e.g. tracks_per_channel=4 means that there are 8 wires in total - 4 in each direction
        tracks_per_channel : integer := 3;
        -- enable twisting into S blocks
        -- new_track_number = (old_track_number + s_block_twisting_factor) modulo tracks_per_channel
        -- set s_block_twisting_factor=0 for no twisting
        four_way_s_block_twisting_factor : integer := 1;
        three_way_s_block_twisting_factor : integer := 0;
        two_way_s_block_twisting_factor : integer := 0
    );
    
    --------------------------------------------------
    -- DO NOT MODIFY ANYTHING BELOW THIS LINE!!!!!! --
    --------------------------------------------------
    
    
    --------------------------------------
    -- I REPEAT. NO MODIFICATIONS!!!!!! --
    --------------------------------------
    
    
    ----------------------
    -- TYPE DEFINITIONS --
    ----------------------
    -- configuration bits for all the LUTs inside the cluster
    type lut_configs_t is array (0 to num_bles_per_cluster-1) of std_logic_vector((2**lut_size)-1 downto 0);
    -- input signals to BLEs
    type ble_inputs_t is array (0 to num_bles_per_cluster-1) of std_logic_vector(lut_size downto 0);
    -- configuration bits for the routing MUXs inside the cluster
    -- there are lut_size+1 MUXs per BLE and there are num_bles_per_cluster BLEs
    -- the '+1' comes from the fact that BLEs have external reset inputs which can come from LUT outputs or from cluster inputs
    -- each MUX has (inputs_to_cluster)+(num_bles_per_cluster)+2 inputs
    -- the '+2' comes from the fact that a constant '0' or a constant '1' should be a possible as LUT input as well
    -- first term: cluster inputs; second term: feedback from BLE outputs
    type cluster_multiplexer_inputs_ble_t is array (0 to lut_size) of std_logic_vector((inputs_to_cluster+num_bles_per_cluster+2)-1 downto 0);
    type cluster_multiplexer_inputs_t is array (0 to num_bles_per_cluster-1) of cluster_multiplexer_inputs_ble_t;
    -- configuration bits for the luts inside the bles in the cluster
    type cluster_multiplexer_configs_ble_t is array (0 to lut_size) of std_logic_vector(get_word_size((inputs_to_cluster+num_bles_per_cluster+2)-1)-1 downto 0);
    type cluster_multiplexer_configs_t is array (0 to num_bles_per_cluster-1) of cluster_multiplexer_configs_ble_t;
    -- configuration bits for the routing MUXs inside switch blocks
    -- each side of the the N-way s block (N in total) has a MUX
    -- each MUX has N inputs (one to each side but not to itself and one additional '0'-input to disable that wire)
    type four_way_s_block_multiplexer_inputs_t is array (0 to (4*tracks_per_channel)-1) of std_logic_vector(3 downto 0);
    type four_way_s_block_multiplexer_configs_t is array (0 to (4*tracks_per_channel)-1) of std_logic_vector(1 downto 0);
    type three_way_s_block_multiplexer_inputs_t is array (0 to (3*tracks_per_channel)-1) of std_logic_vector(2 downto 0);
    type three_way_s_block_multiplexer_configs_t is array (0 to (3*tracks_per_channel)-1) of std_logic_vector(1 downto 0);
    type two_way_s_block_multiplexer_inputs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(1 downto 0);
    type two_way_s_block_multiplexer_configs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(0 downto 0);
    -- configuration bits for the routing MUXs inside output connection blocks
    -- output c blocks have channel connections to 2 sides
    -- and are getting cluster outputs from the left
    -- each channel wire has a MUX with (1+num_bles_per_cluster) inputs
    type output_c_block_multiplexer_inputs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(num_bles_per_cluster downto 0);
    type output_c_block_multiplexer_configs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(get_word_size(num_bles_per_cluster)-1 downto 0);
    -- configuration bits for the routing MUXs inside input connection blocks
    -- input c blocks have channel connections to 2 sides
    -- and should provide inputs to logic clusters
    -- each cluster input has a MUX with (2*tracks_per_channel) inputs
    type input_c_block_multiplexer_inputs_t is array (0 to inputs_to_cluster-1) of std_logic_vector((2*tracks_per_channel)-1 downto 0);
    type input_c_block_multiplexer_configs_t is array (0 to inputs_to_cluster-1) of std_logic_vector(get_word_size((2*tracks_per_channel)-1)-1 downto 0);
    -- configuration bits for the routing MUXs inside connection blocks without connections to logic clusters but with FPGA I/Os
    -- they have channel connections to 2 sides
    -- they have ios_per_c_block additional inputs and ios_per_c_block additional outputs
    type c_block_io_channel_multiplexer_inputs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(inputs_per_c_block downto 0);
    type c_block_io_channel_multiplexer_configs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(get_word_size(inputs_per_c_block)-1 downto 0);
    type c_block_io_output_multiplexer_inputs_t is array (0 to outputs_per_c_block-1) of std_logic_vector((2*tracks_per_channel)-1 downto 0);
    type c_block_io_output_multiplexer_configs_t is array (0 to outputs_per_c_block-1) of std_logic_vector(get_word_size((2*tracks_per_channel)-1)-1 downto 0);
    -- configuration bits for the routing MUXs inside connection blocks that should provide inputs to cluster and with FPGA I/Os
    -- they have channel connections to 2 sides
    -- they have ios_per_c_block additional inputs and ios_per_c_block additional outputs
    -- each cluster input can be connected to fpga i/o pins or to one of the tracks
    type input_c_block_io_channel_multiplexer_inputs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(inputs_per_c_block downto 0);
    type input_c_block_io_channel_multiplexer_configs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(get_word_size(inputs_per_c_block)-1 downto 0);
    type input_c_block_io_output_multiplexer_inputs_t is array (0 to outputs_per_c_block-1) of std_logic_vector((2*tracks_per_channel)-1 downto 0);
    type input_c_block_io_output_multiplexer_configs_t is array (0 to outputs_per_c_block-1) of std_logic_vector(get_word_size((2*tracks_per_channel)-1)-1 downto 0);
    type input_c_block_io_cluster_multiplexer_inputs_t is array (0 to inputs_to_cluster-1) of std_logic_vector((2*tracks_per_channel)+inputs_per_c_block-1 downto 0);
    type input_c_block_io_cluster_multiplexer_configs_t is array (0 to inputs_to_cluster-1) of std_logic_vector(get_word_size((2*tracks_per_channel)+inputs_per_c_block-1)-1 downto 0);
    -- configuration bits for the routing MUXs inside connection blocks with connections to logic cluster output and to FPGA I/Os
    -- they have channel connections to 2 sides
    -- they have ios_per_c_block additional inputs and ios_per_c_block additional outputs
    type output_c_block_io_channel_multiplexer_inputs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(inputs_per_c_block+num_bles_per_cluster downto 0);
    type output_c_block_io_channel_multiplexer_configs_t is array (0 to (2*tracks_per_channel)-1) of std_logic_vector(get_word_size(inputs_per_c_block+num_bles_per_cluster)-1 downto 0);
    type output_c_block_io_output_multiplexer_inputs_t is array (0 to outputs_per_c_block-1) of std_logic_vector((2*tracks_per_channel+num_bles_per_cluster)-1 downto 0);
    type output_c_block_io_output_multiplexer_configs_t is array (0 to outputs_per_c_block-1) of std_logic_vector(get_word_size((2*tracks_per_channel+num_bles_per_cluster)-1)-1 downto 0);
    
    
    ---------------------------------
    -- COUNT NUMBERS OF COMPONENTS --
    ---------------------------------
    -- logic clusters 
    -- => straight forward since fpga size is defined by this number
    constant num_clusters : integer;
    
    -- switch blocks
    -- in total we have one more than logic clusters in both dimensions
    constant num_switch_blocks_total : integer;
    -- two way switch blocks are in corners => always 4
    constant num_two_way_switch_blocks : integer;
    -- three way swtich blocks are on edges at not-corner positions
    constant num_three_way_switch_blocks : integer;
    -- all remaining switch blocks are four-way since they are not on edges
    -- this should be (fpga_width-1)*(fpga_height-1) in total since there is one switch block in each tile that doesn't touch an fpga edge
    constant num_four_way_switch_blocks : integer;
    
    -- connection blocks
    -- connection blocks only with fpga i/o ports are on the left and top edges of the fpga
    constant num_c_blocks_io : integer;
    -- connection blocks with fpga i/o ports and connections to cluster inputs are on the bottom edge of the fpga
    constant num_input_c_blocks_io : integer;
    -- connection blocks with fpga i/o ports and connections to cluster outputs are one the right edge of the fpga
    constant num_output_c_blocks_io : integer;
    -- connection blocks without fpga i/o ports and connections to clusters are in every tile that is not on an fpga edge
    -- input connection blocks are additionally on tiles on the right edge of the fpga
    constant num_input_c_blocks : integer;
    -- input connection blocks are additionally on tiles on the bottom edge of the fpga
    constant num_output_c_blocks : integer;
    -- total number of connection blocks is the sum of all
    -- this should be in total 2*fpga_width*fpga_height + fpga_width + fpga_height
    constant total_num_c_blocks : integer;
    
    -- there should be ((2*fpga_width)+1)*((2*fpga_height)+1) components in total
    constant x_max : integer;
    constant y_max : integer;
    constant total_num_components : integer;
    
    
    ------------------------------------------------
    -- CALCULATE TOTAL NUMBER OF PROGRAMMING BITS --
    ------------------------------------------------
    -- BLEs --
    constant programming_bits_lut : integer;
    constant programming_bits_ff : integer;
    constant programming_bits_ble : integer;
    
    -- CLUSTERS --
    constant programming_bits_per_routing_mux_per_cluster : integer;
    constant programming_bits_routing_muxs_per_cluster : integer;
    constant programming_bits_bles_per_cluster : integer;
    constant programming_bits_cluster : integer;
    
    -- SWITCH BLOCKS --
    -- four way
    constant programming_bits_four_way_s_block_per_mux : integer;
    constant programming_bits_four_way_s_block : integer;
    -- three way
    constant programming_bits_three_way_s_block_per_mux : integer;
    constant programming_bits_three_way_s_block : integer;
    -- two way
    constant programming_bits_two_way_s_block_per_mux : integer;
    constant programming_bits_two_way_s_block : integer;
    
    -- CONNECTION BLOCKS --
    -- io
    constant programming_bits_c_block_io_channel_per_mux : integer;
    constant programming_bits_c_block_io_channel : integer;
    constant programming_bits_c_block_io_fpga_outputs_per_mux : integer;
    constant programming_bits_c_block_io_fpga_outputs : integer;
    constant programming_bits_c_block_io : integer;
    -- output
    constant programming_bits_output_c_block_per_mux : integer;
    constant programming_bits_output_c_block : integer;
    -- output io
    constant programming_bits_output_c_block_io_channel_per_mux : integer;
    constant programming_bits_output_c_block_io_channel : integer;
    constant programming_bits_output_c_block_io_fpga_outputs_per_mux : integer;
    constant programming_bits_output_c_block_io_fpga_outputs : integer;
    constant programming_bits_output_c_block_io : integer;
    -- input
    constant programming_bits_input_c_block_per_mux : integer;
    constant programming_bits_input_c_block : integer;
    -- input io
    constant programming_bits_input_c_block_io_channel_per_mux : integer;
    constant programming_bits_input_c_block_io_channel : integer;
    constant programming_bits_input_c_block_io_fpga_outputs_per_mux : integer;
    constant programming_bits_input_c_block_io_fpga_outputs : integer;
    constant programming_bits_input_c_block_io_cluster_per_mux : integer;
    constant programming_bits_input_c_block_io_cluster : integer;
    constant programming_bits_input_c_block_io : integer;
    
    -- total number of programming bits
    constant programming_bits : integer;
    
end package;

package body fpga_simulation_package is
    
    ------------------------
    -- DEFERRED CONSTANTS --
    ------------------------
    constant num_clusters : integer := fpga_width*fpga_height;
    constant num_switch_blocks_total : integer := (fpga_width+1)*(fpga_height+1);
    constant num_two_way_switch_blocks : integer := 4;
    constant num_three_way_switch_blocks : integer := (2*(fpga_width-1))+(2*(fpga_height-1));
    constant num_four_way_switch_blocks : integer := num_switch_blocks_total - num_two_way_switch_blocks - num_three_way_switch_blocks;
    constant num_c_blocks_io : integer := fpga_width+fpga_height;
    constant num_input_c_blocks_io : integer := fpga_width;
    constant num_output_c_blocks_io : integer := fpga_height;
    constant num_input_c_blocks : integer := ((fpga_width-1)*(fpga_height-1)) + (fpga_height-1);
    constant num_output_c_blocks : integer := (fpga_width-1)*(fpga_height-1) + (fpga_width-1);
    constant total_num_c_blocks : integer := num_c_blocks_io+num_input_c_blocks_io+num_output_c_blocks_io+num_input_c_blocks+num_output_c_blocks;
    constant x_max : integer := ((2*fpga_width)+1)-1;
    constant y_max : integer := ((2*fpga_height)+1)-1;
    constant total_num_components : integer := (x_max+1)*(y_max+1);
    constant programming_bits_lut : integer := (2**lut_size);
    constant programming_bits_ff : integer := 1;
    constant programming_bits_ble : integer := programming_bits_lut+programming_bits_ff;
    constant programming_bits_per_routing_mux_per_cluster : integer := get_word_size((inputs_to_cluster+num_bles_per_cluster+2)-1);
    constant programming_bits_routing_muxs_per_cluster : integer := num_bles_per_cluster*(lut_size+1)*programming_bits_per_routing_mux_per_cluster;
    constant programming_bits_bles_per_cluster : integer := num_bles_per_cluster*programming_bits_ble;
    constant programming_bits_cluster : integer := programming_bits_bles_per_cluster + programming_bits_routing_muxs_per_cluster;
    constant programming_bits_four_way_s_block_per_mux : integer := 2;
    constant programming_bits_four_way_s_block : integer := (4*tracks_per_channel)*programming_bits_four_way_s_block_per_mux;
    constant programming_bits_three_way_s_block_per_mux : integer := 2;
    constant programming_bits_three_way_s_block : integer := (3*tracks_per_channel)*programming_bits_three_way_s_block_per_mux;
    constant programming_bits_two_way_s_block_per_mux : integer := 1;
    constant programming_bits_two_way_s_block : integer := (2*tracks_per_channel)*programming_bits_two_way_s_block_per_mux;
    constant programming_bits_c_block_io_channel_per_mux : integer := get_word_size(inputs_per_c_block);
    constant programming_bits_c_block_io_channel : integer := 2*tracks_per_channel*programming_bits_c_block_io_channel_per_mux;
    constant programming_bits_c_block_io_fpga_outputs_per_mux : integer := get_word_size((2*tracks_per_channel)-1);
    constant programming_bits_c_block_io_fpga_outputs : integer := outputs_per_c_block*programming_bits_c_block_io_fpga_outputs_per_mux;
    constant programming_bits_c_block_io : integer := programming_bits_c_block_io_channel + programming_bits_c_block_io_fpga_outputs;
    constant programming_bits_output_c_block_per_mux : integer := get_word_size(num_bles_per_cluster);
    constant programming_bits_output_c_block : integer := programming_bits_output_c_block_per_mux*(2*tracks_per_channel);
    constant programming_bits_output_c_block_io_channel_per_mux : integer := get_word_size(inputs_per_c_block+num_bles_per_cluster);
    constant programming_bits_output_c_block_io_channel : integer := (2*tracks_per_channel)*programming_bits_output_c_block_io_channel_per_mux;
    constant programming_bits_output_c_block_io_fpga_outputs_per_mux : integer := get_word_size((2*tracks_per_channel)+num_bles_per_cluster-1);
    constant programming_bits_output_c_block_io_fpga_outputs : integer := outputs_per_c_block*programming_bits_output_c_block_io_fpga_outputs_per_mux;
    constant programming_bits_output_c_block_io : integer := programming_bits_output_c_block_io_channel+programming_bits_output_c_block_io_fpga_outputs;
    constant programming_bits_input_c_block_per_mux : integer := get_word_size((2*tracks_per_channel)-1);
    constant programming_bits_input_c_block : integer := programming_bits_input_c_block_per_mux*inputs_to_cluster;
    constant programming_bits_input_c_block_io_channel_per_mux : integer := get_word_size(inputs_per_c_block);
    constant programming_bits_input_c_block_io_channel : integer := (2*tracks_per_channel)*programming_bits_input_c_block_io_channel_per_mux;
    constant programming_bits_input_c_block_io_fpga_outputs_per_mux : integer := get_word_size((2*tracks_per_channel)-1);
    constant programming_bits_input_c_block_io_fpga_outputs : integer := outputs_per_c_block*programming_bits_input_c_block_io_fpga_outputs_per_mux;
    constant programming_bits_input_c_block_io_cluster_per_mux : integer := get_word_size((2*tracks_per_channel)+inputs_per_c_block-1);
    constant programming_bits_input_c_block_io_cluster : integer := inputs_to_cluster*programming_bits_input_c_block_io_cluster_per_mux;
    constant programming_bits_input_c_block_io : integer := programming_bits_input_c_block_io_channel+programming_bits_input_c_block_io_fpga_outputs+programming_bits_input_c_block_io_cluster;
    constant programming_bits : integer := (programming_bits_cluster*num_clusters) + (programming_bits_two_way_s_block*num_two_way_switch_blocks) + (programming_bits_three_way_s_block*num_three_way_switch_blocks) + (programming_bits_four_way_s_block*num_four_way_switch_blocks) + (num_c_blocks_io*programming_bits_c_block_io) + (num_input_c_blocks*programming_bits_input_c_block) + (num_input_c_blocks_io*programming_bits_input_c_block_io) + (num_output_c_blocks*programming_bits_output_c_block) + (num_output_c_blocks_io*programming_bits_output_c_block_io);
    
end package body fpga_simulation_package;
