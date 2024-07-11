----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.06.2020 12:39:17
-- Design Name: 
-- Module Name: FPGA_Simulation - FPGA_Simulation
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
use work.fpga_helper_functions.all;

entity fpga_simulation is
    generic (
        simulation : boolean := false;
        fpga_width : integer := 3; -- 2
        fpga_height : integer := 3; -- 2
        inputs_per_c_block : integer := 2; -- 2
        outputs_per_c_block : integer := 2; -- 2
        lut_size : integer := 4; -- 2
        num_bles_per_cluster : integer := 2; -- 2
        inputs_to_cluster : integer := 6; -- 3
        tracks_per_channel : integer := 3; -- 3
        four_way_s_block_twisting_factor : integer := 1; -- 1
        three_way_s_block_twisting_factor : integer := 1; -- 0
        two_way_s_block_twisting_factor : integer := 1 -- 0
    );
    port (
        -- clock/reset
        clk,rst : in std_logic;
        -- data inputs
        -- numbering scheme: start at leftmost pin in top row and increase index in clockwise direction
        --   top edge: indices 0 to inputs_per_c_block*fpga_width-1 from left to right
        --   right edge: indices inputs_per_c_block*fpga_width to inputs_per_c_block*(fpga_width+fpga_height)-1 from top to bottom
        --   bottom edge: indices inputs_per_c_block*(fpga_width+fpga_height) to inputs_per_c_block*(fpga_width+fpga_height+fpga_width)-1 from right to left
        --   left edge: indices inputs_per_c_block*(fpga_width+fpga_height+fpga_width) to inputs_per_c_block*(fpga_width+fpga_height+fpga_width+fpga_height)-1 from bottom to top
        data_in : in std_logic_vector(0 to (2*inputs_per_c_block*(fpga_width+fpga_height))-1);
        -- data outputs
        -- numbering scheme: same as inputs but with outputs_per_c_block instead of inputs_per_c_block
        data_out : out std_logic_vector(0 to (2*outputs_per_c_block*(fpga_width+fpga_height))-1);
        -- programming bits input
        bit_stream_in : in std_logic;
        bit_stream_enable : in std_logic;
        bit_stream_clk : in std_logic;
        bit_stream_rst : in std_logic;
        -- programming bits output
        bit_stream_out : out std_logic
    );
end fpga_simulation;

architecture fpga_simulation of fpga_simulation is

    package pack_inst is new work.fpga_simulation_package
        generic map (
            simulation => simulation,
            fpga_width => fpga_width,
            fpga_height => fpga_height,
            inputs_per_c_block => inputs_per_c_block,
            outputs_per_c_block => outputs_per_c_block,
            lut_size => lut_size,
            num_bles_per_cluster => num_bles_per_cluster,
            inputs_to_cluster => inputs_to_cluster,
            tracks_per_channel => tracks_per_channel,
            four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
            three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
            two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
        );
        
    --------------------------------
    -- NUMBER OF PROGRAMMING BITS --
    --------------------------------
    -- there are four different tile types:
    -- 1) inner tiles (not touching any edge)
    -- 2) tiles touching right edge (but not bottom edge)
    -- 3) tiles touching bottom edge (but not right edge)
    -- 4) tile in the bottom/right corner
    -- and there is the line of switch and connect blocks on the left and top edges 
    -- BIT STREAM ORDER:
    -- in order of instantiation:
    -- 1) switch/connect line starting at the bottom left corner
    -- 2) then starting at the top left and go tile-wise and row by row from left to right and top to bottom
    constant programming_bits_s_c_line : integer := (3*pack_inst.programming_bits_two_way_s_block) + ((fpga_width-1+fpga_height-1)*pack_inst.programming_bits_three_way_s_block) + ((fpga_width+fpga_height)*pack_inst.programming_bits_c_block_io);
    constant programming_bits_case_1_tile : integer := pack_inst.programming_bits_cluster + pack_inst.programming_bits_output_c_block + pack_inst.programming_bits_input_c_block + pack_inst.programming_bits_four_way_s_block;
    constant programming_bits_case_2_tile : integer := pack_inst.programming_bits_cluster + pack_inst.programming_bits_output_c_block_io + pack_inst.programming_bits_input_c_block + pack_inst.programming_bits_three_way_s_block;
    constant programming_bits_case_3_tile : integer := pack_inst.programming_bits_cluster + pack_inst.programming_bits_output_c_block + pack_inst.programming_bits_input_c_block_io + pack_inst.programming_bits_three_way_s_block;
    constant programming_bits_case_4_tile : integer := pack_inst.programming_bits_cluster + pack_inst.programming_bits_output_c_block_io + pack_inst.programming_bits_input_c_block_io + pack_inst.programming_bits_two_way_s_block;
    
    
    ----------------
    -- BIT STREAM --
    ----------------
    -- connect bit stream outputs to inputs in s/c line
    signal bit_stream_s_c_line_connections : std_logic_vector((2*fpga_height)+(2*fpga_width)+1 downto 0);
    -- connect bit stream outputs to inputs in tiles
    signal bit_stream_tiles_connections : std_logic_vector(4*fpga_width*fpga_height downto 0);
    -- see total bit stream length in simulation
    constant total_bit_stream_length : integer := pack_inst.programming_bits;
    
    --------------------------------
    -- CONNECTIONS BETWEEN BLOCKS --
    --------------------------------
    -- SWITCH BLOCK <-> CONNECTION BLOCK
    -- one vertical line of connections between switch and connection blocks
    type s_c_connection_vertical_line_t is array (0 to (2*fpga_height)-1) of std_logic_vector(tracks_per_channel-1 downto 0);
    -- all vertical lines of connections between switch and connection blocks
    type s_c_connection_vertical_lines_t is array (0 to fpga_width) of s_c_connection_vertical_line_t;
    -- one horizontal line of connections between switch and connection blocks
    type s_c_connection_horizontal_line_t is array (0 to (2*fpga_width)-1) of std_logic_vector(tracks_per_channel-1 downto 0);
    -- all horizontal lines of connections between switch and connection blocks
    type s_c_connection_horizontal_lines_t is array (0 to fpga_height) of s_c_connection_horizontal_line_t;
    -- signal declarations
    signal s_c_connection_vertical_lines : s_c_connection_vertical_lines_t; -- dimensions: (fpga_width)(2*fpga_height-1)
    signal s_c_connection_horizontal_lines : s_c_connection_horizontal_lines_t; -- dimensions: (fpga_height)(2*fpga_width-1)
    signal c_s_connection_vertical_lines : s_c_connection_vertical_lines_t; -- dimensions: (fpga_width)(2*fpga_height-1)
    signal c_s_connection_horizontal_lines : s_c_connection_horizontal_lines_t; -- dimensions: (fpga_height)(2*fpga_width-1)
    
    -- CONNECTION BLOCK -> LOGIC CLUSTER
    type c_l_connection_t is array (0 to (fpga_width*fpga_height)-1) of std_logic_vector(inputs_to_cluster-1 downto 0);
    signal c_l_connection : c_l_connection_t; -- dimensions: (fpga_width*fpga_height)
    
    -- LOGIC CLUSTER -> CONNECTION BLOCK
    type l_c_connection_t is array (0 to (fpga_width*fpga_height)-1) of std_logic_vector(num_bles_per_cluster-1 downto 0);
    signal l_c_connection : l_c_connection_t; -- dimensions: (fpga_width*fpga_height)
    
begin
    -- debug outputs
        --simulation : boolean := false;
        --fpga_width : integer := 3; -- 2
        --fpga_height : integer := 3; -- 2
        --inputs_per_c_block : integer := 2; -- 2
        --outputs_per_c_block : integer := 2; -- 2
        --lut_size : integer := 4; -- 2
        --num_bles_per_cluster : integer := 2; -- 2
        --inputs_to_cluster : integer := 6; -- 3
        --tracks_per_channel : integer := 3; -- 3
        --four_way_s_block_twisting_factor : integer := 1; -- 1
        --three_way_s_block_twisting_factor : integer := 1; -- 0
        --two_way_s_block_twisting_factor : integer := 1 -- 0
    assert FALSE report "DEBUGGING entity 'fpga_simulation' bit stream length = " & integer'image(pack_inst.programming_bits) severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'simulation' is '" & boolean'image(simulation) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'fpga_width' is '" & integer'image(fpga_width) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'fpga_height' is '" & integer'image(fpga_height) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'inputs_per_c_block' is '" & integer'image(inputs_per_c_block) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'outputs_per_c_block' is '" & integer'image(outputs_per_c_block) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'lut_size' is '" & integer'image(lut_size) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'num_bles_per_cluster' is '" & integer'image(num_bles_per_cluster) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'inputs_to_cluster' is '" & integer'image(inputs_to_cluster) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'tracks_per_channel' is '" & integer'image(tracks_per_channel) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'four_way_s_block_twisting_factor' is '" & integer'image(four_way_s_block_twisting_factor) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'three_way_s_block_twisting_factor' is '" & integer'image(three_way_s_block_twisting_factor) & "'" severity NOTE;
    assert FALSE report "DEBUGGING entity 'fpga_simulation' generic 'two_way_s_block_twisting_factor' is '" & integer'image(two_way_s_block_twisting_factor) & "'" severity NOTE;
    
    -- report bitsream size
    -- process
    -- begin
    --     report "bitstream size = " & integer'image(pack_inst.programming_bits) severity ERROR;
    --     wait;
    -- end process;
    --assert FALSE report "bitstream size = " & integer'image(pack_inst.programming_bits) severity ERROR;  -- enable "-assert" option in synthesis settings
    -- connect bit stream lines together
    bit_stream_tiles_connections(0) <= bit_stream_s_c_line_connections(bit_stream_s_c_line_connections'length-1);
    bit_stream_s_c_line_connections(0) <= bit_stream_in;
    bit_stream_out <= bit_stream_tiles_connections(bit_stream_tiles_connections'length-1);
    
    -------------------------------------
    -- LEGEND FOR COMPONENT GENERATION --
    -------------------------------------
    -- LEGEND FOR COORDINATES
    -- top/left corner : coordinate y/x = 0/0
    -- bottom/left corner : coordinate y/x = 2*fpga_height/0
    -- top/right corner : coordinate y/x = 0/2*fpga_width
    -- bottom/right corner : coordinate y/x = 2*fpga_height/2*fpga_width
    
    -- LEGEND FOR WIRE NUMBERING
    -- start at the top of the block and rotate clockwise when assigning indices to wires
    -- e.g. top/left switch block has connections to the right and to the bottom
    -- => right connection is wire_0 and bottom connection is wire_1
    
    
    --------------------
    -- GENERATE TILES --
    --------------------
    generate_tiles_y : for y in 0 to fpga_height-1 generate
        generate_tiles_x : for x in 0 to fpga_width-1 generate
            -- four different tile types:
            -- 1) inner tiles (not touching any edge)
            -- 2) tiles touching right edge (but not bottom edge)
            -- 3) tiles touching bottom edge (but not right edge)
            -- 4) tile in the bottom/right corner
            
            -- LOGIC CLUSTER
            -- logic cluster doesn't care about the tile type 
            generate_logic_cluster : entity work.logic_cluster
            generic map (
                simulation => simulation,
                x => 1+(2*x), 
                y => 1+(2*y),
                fpga_width => fpga_width,
                fpga_height => fpga_height,
                inputs_per_c_block => inputs_per_c_block,
                outputs_per_c_block => outputs_per_c_block,
                lut_size => lut_size,
                num_bles_per_cluster => num_bles_per_cluster,
                inputs_to_cluster => inputs_to_cluster,
                tracks_per_channel => tracks_per_channel,
                four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
            )
            port map (
                clk => clk,
                rst => rst,
                logic_cluster_in => c_l_connection((y*fpga_width)+x),
                logic_cluster_out => l_c_connection((y*fpga_width)+x),
                bit_stream_clk => bit_stream_clk,
                bit_stream_rst => bit_stream_rst,
                bit_stream_enable => bit_stream_enable,
                bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+0),
                bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+1)
            );
            
            -- OUTPUT CONNECTION BLOCK
            output_c_case_1_3 : if x<fpga_width-1 generate
                -- output connection block without i/o
                generate_output_c_block : entity work.output_c_block
                generic map (
                    simulation => simulation,
                    x => 2+(2*x), 
                    y => 1+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => s_c_connection_vertical_lines(x+1)(2*y),
                    wires_1_in => s_c_connection_vertical_lines(x+1)(2*y+1),
                    wires_0_out => c_s_connection_vertical_lines(x+1)(2*y),
                    wires_1_out => c_s_connection_vertical_lines(x+1)(2*y+1),
                    cluster_outputs_in => l_c_connection((y*fpga_width)+x),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+1),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+2)
                );
            end generate;
            output_c_case_2_4 : if x=fpga_width-1 generate
                -- output connection block with i/o
                generate_output_c_block_io : entity work.output_c_block_io
                generic map (
                    simulation => simulation,
                    x => 2+(2*x), 
                    y => 1+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => s_c_connection_vertical_lines(x+1)(2*y),
                    wires_1_in => s_c_connection_vertical_lines(x+1)(2*y+1),
                    wires_0_out => c_s_connection_vertical_lines(x+1)(2*y),
                    wires_1_out => c_s_connection_vertical_lines(x+1)(2*y+1),
                    cluster_outputs_in => l_c_connection((y*fpga_width)+x),
                    fpga_inputs_in => data_in(inputs_per_c_block*(fpga_width+y) to inputs_per_c_block*(fpga_width+y+1)-1),
                    fpga_outputs_out => data_out(outputs_per_c_block*(fpga_width+y) to outputs_per_c_block*(fpga_width+y+1)-1),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+1),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+2)
                );
            end generate;
            
            -- INPUT CONNECTION BLOCK
            input_c_case_1_2 : if y<fpga_height-1 generate
                -- input connection block without i/o
                generate_input_c_block : entity work.input_c_block
                generic map (
                    simulation => simulation,
                    x => 1+(2*x), 
                    y => 2+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => s_c_connection_horizontal_lines(y+1)(2*x+1),
                    wires_1_in => s_c_connection_horizontal_lines(y+1)(2*x),
                    wires_0_out => c_s_connection_horizontal_lines(y+1)(2*x+1),
                    wires_1_out => c_s_connection_horizontal_lines(y+1)(2*x),
                    cluster_inputs_out => c_l_connection((y*fpga_width)+x),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+2),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+3)
                );
            end generate;
            input_c_case_3_4 : if y=fpga_height-1 generate
                -- input connection block with i/o
                generate_input_c_block_io : entity work.input_c_block_io
                generic map (
                    simulation => simulation,
                    x => 1+(2*x), 
                    y => 2+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => s_c_connection_horizontal_lines(y+1)(2*x+1),
                    wires_1_in => s_c_connection_horizontal_lines(y+1)(2*x),
                    wires_0_out => c_s_connection_horizontal_lines(y+1)(2*x+1),
                    wires_1_out => c_s_connection_horizontal_lines(y+1)(2*x),
                    cluster_inputs_out => c_l_connection((y*fpga_width)+x),
                    fpga_inputs_in => data_in(inputs_per_c_block*(fpga_width+fpga_height+fpga_width-1-x) to inputs_per_c_block*(fpga_width+fpga_height+fpga_width-x)-1),
                    fpga_outputs_out => data_out(outputs_per_c_block*(fpga_width+fpga_height+fpga_width-1-x) to outputs_per_c_block*(fpga_width+fpga_height+fpga_width-x)-1),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+2),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+3)
                );
            end generate;
            
            -- SWITCH BLOCK
            s_case_1 : if x<fpga_width-1 and y<fpga_height-1 generate
                -- 4 way switch block
                generate_four_way_s_block : entity work.four_way_s_block
                generic map (
                    simulation => simulation,
                    x => 2+(2*x), 
                    y => 2+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => c_s_connection_vertical_lines(x+1)(2*y+1),
                    wires_1_in => c_s_connection_horizontal_lines(y+1)(2*x+2),
                    wires_2_in => c_s_connection_vertical_lines(x+1)(2*y+2),
                    wires_3_in => c_s_connection_horizontal_lines(y+1)(2*x+1),
                    wires_0_out => s_c_connection_vertical_lines(x+1)(2*y+1),
                    wires_1_out => s_c_connection_horizontal_lines(y+1)(2*x+2),
                    wires_2_out => s_c_connection_vertical_lines(x+1)(2*y+2),
                    wires_3_out => s_c_connection_horizontal_lines(y+1)(2*x+1),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+3),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+4)
                );
            end generate;
            s_case_2 : if x=fpga_width-1 and y<fpga_height-1 generate
                -- 3 way switch block
                generate_three_way_s_block : entity work.three_way_s_block
                generic map (
                    simulation => simulation,
                    x => 2+(2*x), 
                    y => 2+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => c_s_connection_vertical_lines(x+1)(2*y+1),
                    wires_1_in => c_s_connection_vertical_lines(x+1)(2*y+2),
                    wires_2_in => c_s_connection_horizontal_lines(y+1)(2*x+1),
                    wires_0_out => s_c_connection_vertical_lines(x+1)(2*y+1),
                    wires_1_out => s_c_connection_vertical_lines(x+1)(2*y+2),
                    wires_2_out => s_c_connection_horizontal_lines(y+1)(2*x+1),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+3),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+4)
                );
            end generate;
            s_case_3 : if x<fpga_width-1 and y=fpga_height-1 generate
                -- 3 way switch block
                generate_three_way_s_block : entity work.three_way_s_block
                generic map (
                    simulation => simulation,
                    x => 2+(2*x), 
                    y => 2+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => c_s_connection_vertical_lines(x+1)(2*y+1),
                    wires_1_in => c_s_connection_horizontal_lines(y+1)(2*x+2),
                    wires_2_in => c_s_connection_horizontal_lines(y+1)(2*x+1),
                    wires_0_out => s_c_connection_vertical_lines(x+1)(2*y+1),
                    wires_1_out => s_c_connection_horizontal_lines(y+1)(2*x+2),
                    wires_2_out => s_c_connection_horizontal_lines(y+1)(2*x+1),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+3),
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+4)
                );
            end generate;
            s_case_4 : if x=fpga_width-1 and y=fpga_height-1 generate
                -- 2 way switch block
                generate_two_way_switch : entity work.two_way_s_block
                generic map (
                    simulation => simulation,
                    x => 2+(2*x), 
                    y => 2+(2*y),
                    fpga_width => fpga_width,
                    fpga_height => fpga_height,
                    inputs_per_c_block => inputs_per_c_block,
                    outputs_per_c_block => outputs_per_c_block,
                    lut_size => lut_size,
                    num_bles_per_cluster => num_bles_per_cluster,
                    inputs_to_cluster => inputs_to_cluster,
                    tracks_per_channel => tracks_per_channel,
                    four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
                    three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
                    two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
                )
                port map (
                    wires_0_in => c_s_connection_vertical_lines(fpga_width)(2*fpga_height-1),
                    wires_1_in => s_c_connection_horizontal_lines(fpga_height)(2*fpga_width-1),
                    wires_0_out => s_c_connection_vertical_lines(fpga_width)(2*fpga_height-1),
                    wires_1_out => s_c_connection_horizontal_lines(fpga_height)(2*fpga_width-1),
                    bit_stream_in => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+3),
                    bit_stream_clk => bit_stream_clk,
                    bit_stream_rst => bit_stream_rst,
                    bit_stream_enable => bit_stream_enable,
                    bit_stream_out => bit_stream_tiles_connections((4*(x+(y*fpga_width)))+4)
                );
            end generate;
        end generate;
    end generate;
    
    
    ---------------------------------
    -- GENERATE TOP AND LEFT EDGES --
    ---------------------------------
    -- (only switch and connection blocks)
    -- bottom left corner switch
    bottom_left_corner_two_way_switch : entity work.two_way_s_block
    generic map (
        simulation => simulation,
        x => 0, 
        y => pack_inst.y_max,
        fpga_width => fpga_width,
        fpga_height => fpga_height,
        inputs_per_c_block => inputs_per_c_block,
        outputs_per_c_block => outputs_per_c_block,
        lut_size => lut_size,
        num_bles_per_cluster => num_bles_per_cluster,
        inputs_to_cluster => inputs_to_cluster,
        tracks_per_channel => tracks_per_channel,
        four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
        three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
        two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
    )
    port map (
        wires_0_in => c_s_connection_vertical_lines(0)(2*fpga_height-1),
        wires_1_in => c_s_connection_horizontal_lines(fpga_height)(0),
        wires_0_out => s_c_connection_vertical_lines(0)(2*fpga_height-1),
        wires_1_out => s_c_connection_horizontal_lines(fpga_height)(0),
        bit_stream_in => bit_stream_s_c_line_connections(0),
        bit_stream_clk => bit_stream_clk,
        bit_stream_rst => bit_stream_rst,
        bit_stream_enable => bit_stream_enable,
        bit_stream_out => bit_stream_s_c_line_connections(1)
    );
    
    -- top left corner switch
    top_left_corner_two_way_switch : entity work.two_way_s_block
    generic map (
        simulation => simulation,
        x => 0, 
        y => 0,
        fpga_width => fpga_width,
        fpga_height => fpga_height,
        inputs_per_c_block => inputs_per_c_block,
        outputs_per_c_block => outputs_per_c_block,
        lut_size => lut_size,
        num_bles_per_cluster => num_bles_per_cluster,
        inputs_to_cluster => inputs_to_cluster,
        tracks_per_channel => tracks_per_channel,
        four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
        three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
        two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
    )
    port map (
        wires_0_in => c_s_connection_horizontal_lines(0)(0),
        wires_1_in => c_s_connection_vertical_lines(0)(0),
        wires_0_out => s_c_connection_horizontal_lines(0)(0),
        wires_1_out => s_c_connection_vertical_lines(0)(0),
        bit_stream_in => bit_stream_s_c_line_connections(2*fpga_height),
        bit_stream_clk => bit_stream_clk,
        bit_stream_rst => bit_stream_rst,
        bit_stream_enable => bit_stream_enable,
        bit_stream_out => bit_stream_s_c_line_connections((2*fpga_height)+1)
    );
    
    -- top right corner switch
    top_right_corner_two_way_switch : entity work.two_way_s_block
    generic map (
        simulation => simulation,
        x => pack_inst.x_max, 
        y => 0,
        fpga_width => fpga_width,
        fpga_height => fpga_height,
        inputs_per_c_block => inputs_per_c_block,
        outputs_per_c_block => outputs_per_c_block,
        lut_size => lut_size,
        num_bles_per_cluster => num_bles_per_cluster,
        inputs_to_cluster => inputs_to_cluster,
        tracks_per_channel => tracks_per_channel,
        four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
        three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
        two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
    )
    port map (
        wires_0_in => c_s_connection_vertical_lines(fpga_width)(0),
        wires_1_in => c_s_connection_horizontal_lines(0)(2*fpga_width-1),
        wires_0_out => s_c_connection_vertical_lines(fpga_width)(0),
        wires_1_out => s_c_connection_horizontal_lines(0)(2*fpga_width-1),
        bit_stream_in => bit_stream_s_c_line_connections(2*(fpga_height+fpga_width)),
        bit_stream_clk => bit_stream_clk,
        bit_stream_rst => bit_stream_rst,
        bit_stream_enable => bit_stream_enable,
        bit_stream_out => bit_stream_s_c_line_connections((2*(fpga_height+fpga_width))+1)
    );
    
    -- remaining left edge
    generate_left_edge_c_blocks : for y in 0 to fpga_height-1 generate
        generate_c_block_io : entity work.c_block_io
        generic map (
            simulation => simulation,
            x => 0, 
            y => 1+(2*y),
            fpga_width => fpga_width,
            fpga_height => fpga_height,
            inputs_per_c_block => inputs_per_c_block,
            outputs_per_c_block => outputs_per_c_block,
            lut_size => lut_size,
            num_bles_per_cluster => num_bles_per_cluster,
            inputs_to_cluster => inputs_to_cluster,
            tracks_per_channel => tracks_per_channel,
            four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
            three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
            two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
        )
        port map(
            wires_0_in => s_c_connection_vertical_lines(0)(0+(2*y)),
            wires_1_in => s_c_connection_vertical_lines(0)(1+(2*y)),
            wires_0_out => c_s_connection_vertical_lines(0)(0+(2*y)),
            wires_1_out => c_s_connection_vertical_lines(0)(1+(2*y)),
            fpga_inputs_in => data_in(inputs_per_c_block*(fpga_width+fpga_height+fpga_width+fpga_height-1-y) to inputs_per_c_block*(fpga_width+fpga_height+fpga_width+fpga_height-y)-1),
            fpga_outputs_out => data_out(outputs_per_c_block*(fpga_width+fpga_height+fpga_width+fpga_height-1-y) to outputs_per_c_block*(fpga_width+fpga_height+fpga_width+fpga_height-y)-1),
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_enable => bit_stream_enable,
            bit_stream_in => bit_stream_s_c_line_connections((2*(fpga_height-y))-1),
            bit_stream_out => bit_stream_s_c_line_connections((2*(fpga_height-y))-0)
            -- OLD/WRONG: bit_stream_in => bit_stream_s_c_line_connections((2*y)+1),
            -- OLD/WRONG: bit_stream_out => bit_stream_s_c_line_connections((2*y)+2)
        );
    end generate;
    generate_left_edge_s_blocks : for y in 0 to fpga_height-2 generate
        generate_three_way_s_block : entity work.three_way_s_block
        generic map (
            simulation => simulation,
            x => 0, 
            y => 2+(2*y),
            fpga_width => fpga_width,
            fpga_height => fpga_height,
            inputs_per_c_block => inputs_per_c_block,
            outputs_per_c_block => outputs_per_c_block,
            lut_size => lut_size,
            num_bles_per_cluster => num_bles_per_cluster,
            inputs_to_cluster => inputs_to_cluster,
            tracks_per_channel => tracks_per_channel,
            four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
            three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
            two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
        )
        port map (
            wires_0_in => c_s_connection_vertical_lines(0)(1+(2*y)),
            wires_1_in => c_s_connection_horizontal_lines(1+y)(0),
            wires_2_in => c_s_connection_vertical_lines(0)(2+(2*y)),
            wires_0_out => s_c_connection_vertical_lines(0)(1+(2*y)),
            wires_1_out => s_c_connection_horizontal_lines(1+y)(0),
            wires_2_out => s_c_connection_vertical_lines(0)(2+(2*y)),
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_enable => bit_stream_enable,
            bit_stream_in => bit_stream_s_c_line_connections((2*(fpga_height-y))-2),
            bit_stream_out => bit_stream_s_c_line_connections((2*(fpga_height-y))-1)
            -- OLD/WRONG: bit_stream_in => bit_stream_s_c_line_connections((2*y)+2),
            -- OLD/WRONG: bit_stream_out => bit_stream_s_c_line_connections((2*y)+3)
        );
    end generate;
    
    -- remaining top edge
    generate_top_edge_c_blocks : for x in 0 to fpga_width-1 generate
        generate_c_block_io : entity work.c_block_io
        generic map (
            simulation => simulation,
            x => 1+(2*x), 
            y => 0,
            fpga_width => fpga_width,
            fpga_height => fpga_height,
            inputs_per_c_block => inputs_per_c_block,
            outputs_per_c_block => outputs_per_c_block,
            lut_size => lut_size,
            num_bles_per_cluster => num_bles_per_cluster,
            inputs_to_cluster => inputs_to_cluster,
            tracks_per_channel => tracks_per_channel,
            four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
            three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
            two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
        )
        port map(
            wires_0_in => s_c_connection_horizontal_lines(0)(1+(2*x)),
            wires_1_in => s_c_connection_horizontal_lines(0)(0+(2*x)),
            wires_0_out => c_s_connection_horizontal_lines(0)(1+(2*x)),
            wires_1_out => c_s_connection_horizontal_lines(0)(0+(2*x)),
            fpga_inputs_in => data_in(inputs_per_c_block*(x) to inputs_per_c_block*(x+1)-1),
            fpga_outputs_out => data_out(outputs_per_c_block*(x) to outputs_per_c_block*(x+1)-1),
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_enable => bit_stream_enable,
            bit_stream_in => bit_stream_s_c_line_connections((2*fpga_height)+(2*x)+1),
            bit_stream_out => bit_stream_s_c_line_connections((2*fpga_height)+(2*x)+2)
        );
    end generate;
    generate_top_edge_s_blocks : for x in 0 to fpga_width-2 generate
        generate_three_way_s_block : entity work.three_way_s_block
        generic map (
            simulation => simulation,
            x => 2+(2*x), 
            y => 0,
            fpga_width => fpga_width,
            fpga_height => fpga_height,
            inputs_per_c_block => inputs_per_c_block,
            outputs_per_c_block => outputs_per_c_block,
            lut_size => lut_size,
            num_bles_per_cluster => num_bles_per_cluster,
            inputs_to_cluster => inputs_to_cluster,
            tracks_per_channel => tracks_per_channel,
            four_way_s_block_twisting_factor => four_way_s_block_twisting_factor,
            three_way_s_block_twisting_factor => three_way_s_block_twisting_factor,
            two_way_s_block_twisting_factor => two_way_s_block_twisting_factor
        )
        port map (
            wires_0_in => c_s_connection_horizontal_lines(0)(2+(2*x)),
            wires_1_in => c_s_connection_vertical_lines(1+x)(0),
            wires_2_in => c_s_connection_horizontal_lines(0)(1+(2*x)),
            wires_0_out => s_c_connection_horizontal_lines(0)(2+(2*x)),
            wires_1_out => s_c_connection_vertical_lines(1+x)(0),
            wires_2_out => s_c_connection_horizontal_lines(0)(1+(2*x)),
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_enable => bit_stream_enable,
            bit_stream_in => bit_stream_s_c_line_connections((2*fpga_height)+(2*x)+2),
            bit_stream_out => bit_stream_s_c_line_connections((2*fpga_height)+(2*x)+3)
        );
    end generate;

end fpga_simulation;
