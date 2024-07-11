----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/01/2024 09:32:25 AM
-- Design Name: 
-- Module Name: fpga_top - fpga_top
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

entity fpga_top is
    generic (
        simulation : boolean := true;
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
end fpga_top;

architecture fpga_top of fpga_top is
    -- prohibit optimization and allow combinatorial loops
    -- => also execute the following two tcl commands in the tcl console:
    -- set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
    -- set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
    --attribute DONT_TOUCH: string;
    --attribute DONT_TOUCH of fpga_inst : label is "yes";
    --attribute ALLOW_COMBINATORIAL_LOOPS : string;
    --attribute ALLOW_COMBINATORIAL_LOOPS of fpga_inst : label is "yes";
    
    -- detect rising edges on the bitstream enable signal
    signal bit_stream_enable_delay, bit_stream_enable_edge: std_logic;

begin    
    -- debug outputs
    assert FALSE report "DEBUGGING entity 'fpga_top' generic 'simulation' is '" & boolean'image(simulation) & "'" severity NOTE;

    -- instantiate fpga
    gen_simulation: if simulation generate
        fpga_inst : entity work.fpga_simulation
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
        )
        port map (
            clk => clk,
            rst => rst,
            data_in => data_in,
            data_out => data_out,
            bit_stream_in => bit_stream_in,
            bit_stream_enable => bit_stream_enable,
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_out => bit_stream_out
        );
    end generate;

    gen_synthesis: if not simulation generate
        fpga_inst : entity work.fpga_simulation
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
        )
        port map (
            clk => clk,
            rst => rst,
            data_in => data_in,
            data_out => data_out,
            bit_stream_in => bit_stream_in,
            bit_stream_enable => bit_stream_enable_edge,
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_out => bit_stream_out
        );
    end generate;
    
    -- only do the bit stream enable stuff on a rising edge
    process (bit_stream_clk, bit_stream_rst)
    begin
        if rising_edge(bit_stream_clk) then
            if bit_stream_rst = '1' then
                bit_stream_enable_delay <= '0';
            else
                bit_stream_enable_delay <= bit_stream_enable;
            end if;
        end if;
    end process;

    bit_stream_enable_edge <= bit_stream_enable and (not bit_stream_enable_delay);


end fpga_top;
