----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.07.2020 12:15:18
-- Design Name: 
-- Module Name: input_c_block - input_c_block
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
use work.fpga_helper_functions.all;

entity input_c_block is
    generic (
        x : integer := 0;
        y : integer := 0;
        -- PACKAGE GENERICS BELOW
        simulation : boolean := false;
        fpga_width : integer := 2;
        fpga_height : integer := 2;
        inputs_per_c_block : integer := 2;
        outputs_per_c_block : integer := 2;
        lut_size : integer := 2;
        num_bles_per_cluster : integer := 2;
        inputs_to_cluster : integer := 3;
        tracks_per_channel : integer := 3;
        four_way_s_block_twisting_factor : integer := 1;
        three_way_s_block_twisting_factor : integer := 0;
        two_way_s_block_twisting_factor : integer := 0
    );
    port (
        -- inputs
        wires_0_in : in std_logic_vector(tracks_per_channel-1 downto 0);
        wires_1_in : in std_logic_vector(tracks_per_channel-1 downto 0);
        -- outputs
        wires_0_out : out std_logic_vector(tracks_per_channel-1 downto 0);
        wires_1_out : out std_logic_vector(tracks_per_channel-1 downto 0);
        cluster_inputs_out : out std_logic_vector(inputs_to_cluster-1 downto 0);
        -- bit stream
        bit_stream_in : in std_logic;
        bit_stream_clk : in std_logic;
        bit_stream_rst : in std_logic;
        bit_stream_enable : in std_logic;
        bit_stream_out : out std_logic
    );
end input_c_block;

architecture input_c_block of input_c_block is

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
        
    constant configuration_mux_select_width : integer := pack_inst.programming_bits_input_c_block_per_mux;
    constant bit_stream_length : integer := pack_inst.programming_bits_input_c_block;
    signal bit_stream : std_logic_vector(bit_stream_length-1 downto 0);

    -- input to connection multiplexers
    -- for details on dimensions see package
    signal input_c_block_multiplexer_inputs : pack_inst.input_c_block_multiplexer_inputs_t;
    -- configuration bits
    signal input_c_block_multiplexer_configs : pack_inst.input_c_block_multiplexer_configs_t;

begin
    
    ---------------------------
    -- GENERATE MULTIPLEXERS --
    ---------------------------
    generate_multiplexers : for i in 0 to (inputs_to_cluster-1) generate
        gen_latches : if simulation generate
            process (input_c_block_multiplexer_inputs,input_c_block_multiplexer_configs,bit_stream_enable)
            begin
                if (bit_stream_enable='0') then
                    cluster_inputs_out(i) <= input_c_block_multiplexer_inputs(i)(to_integer(unsigned(input_c_block_multiplexer_configs(i))));
                end if;
            end process;
        end generate;
        do_not_gen_latches : if not simulation generate
            cluster_inputs_out(i) <= input_c_block_multiplexer_inputs(i)(to_integer(unsigned(input_c_block_multiplexer_configs(i))));
        end generate;
    end generate;
    
    
    ----------------
    -- BIT STREAM --
    ----------------
    generate_bit_stream : entity work.tapped_shift_register
    generic map (n => bit_stream_length)
    port map (
        clk => bit_stream_clk,
        rst => bit_stream_rst,
        enable => bit_stream_enable,
        x_in => bit_stream_in,
        y_out => bit_stream
    );
    bit_stream_out <= bit_stream(bit_stream_length-1);
    
    connect_channel_programming_bits_to_bitstream : for i in 0 to inputs_to_cluster-1 generate
        input_c_block_multiplexer_configs(i) <= bit_stream(((i+1)*configuration_mux_select_width)-1 downto i*(configuration_mux_select_width));
    end generate;
    
    
    -------------------
    -- TRACK OUTPUTS --
    -------------------
    -- this is trivial since this block does not get any inputs from cluster
    -- just connect inputs to outputs
    wires_0_out <= wires_1_in;
    wires_1_out <= wires_0_in;
    
    ----------------
    -- MUX INPUTS --
    ----------------
    define_mux_inputs_outer_loop : for i in 0 to (inputs_to_cluster-1) generate
        define_mux_inputs_inner_loop : for j in 0 to (tracks_per_channel-1) generate
            -- offset 0 :
            input_c_block_multiplexer_inputs(i)(2*j+0) <= wires_0_in(j);
            -- offset 1 :
            input_c_block_multiplexer_inputs(i)(2*j+1) <= wires_1_in(j);
        end generate;
    end generate;

end input_c_block;
