----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.07.2020 22:04:58
-- Design Name: 
-- Module Name: two_way_s_block - two_way_s_block
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

entity two_way_s_block is
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
    port(
        -- inputs
        wires_0_in : in std_logic_vector(tracks_per_channel-1 downto 0);
        wires_1_in : in std_logic_vector(tracks_per_channel-1 downto 0);
        -- outputs
        wires_0_out : out std_logic_vector(tracks_per_channel-1 downto 0);
        wires_1_out : out std_logic_vector(tracks_per_channel-1 downto 0);
        -- bit stream
        bit_stream_in : in std_logic;
        bit_stream_clk : in std_logic;
        bit_stream_rst : in std_logic;
        bit_stream_enable : in std_logic;
        bit_stream_out : out std_logic
    );
end two_way_s_block;

architecture two_way_s_block of two_way_s_block is
    
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
        
    -- configuration bits
    signal two_way_s_block_multiplexer_configs : pack_inst.two_way_s_block_multiplexer_configs_t;
    constant bit_stream_length : integer := pack_inst.programming_bits_two_way_s_block;
    signal bit_stream : std_logic_vector(bit_stream_length-1 downto 0);
    
    -- inputs to switch-multiplexers
    signal two_way_s_block_multiplexer_inputs : pack_inst.two_way_s_block_multiplexer_inputs_t;
    
    -- inputs after twisting them
    signal wires_0_in_twisted : std_logic_vector(tracks_per_channel-1 downto 0);
    signal wires_1_in_twisted : std_logic_vector(tracks_per_channel-1 downto 0);
    
    -- outputs before twisting them
    signal wires_0_out_untwisted : std_logic_vector(tracks_per_channel-1 downto 0);
    signal wires_1_out_untwisted : std_logic_vector(tracks_per_channel-1 downto 0);

    -- temporary output signals (needed for simulation)
    signal wires_0_out_temp : std_logic_vector(tracks_per_channel-1 downto 0);
    signal wires_1_out_temp : std_logic_vector(tracks_per_channel-1 downto 0);
    
    -- switch wires off if not needed
    constant off : std_logic := '0';
    
begin
    
    -------------
    -- LATCHES --
    -------------
    -- outputs
    gen_latches : if simulation generate
        process (wires_0_out_temp,wires_1_out_temp,bit_stream_enable)
        begin
            if (bit_stream_enable='0') then
                wires_0_out <= wires_0_out_temp;
                wires_1_out <= wires_1_out_temp;
            end if;
        end process;
    end generate;
    do_not_gen_latches : if not simulation generate
        wires_0_out <= wires_0_out_temp;
        wires_1_out <= wires_1_out_temp;
    end generate;
    -- switch multiplexers
    create_multiplexers : for i in 0 to tracks_per_channel-1 generate
        gen_latches : if simulation generate
            process (two_way_s_block_multiplexer_inputs,two_way_s_block_multiplexer_configs,bit_stream_enable)
            begin
                if (bit_stream_enable='0') then
                    wires_0_out_untwisted(i) <= two_way_s_block_multiplexer_inputs(2*i+0)(to_integer(unsigned(two_way_s_block_multiplexer_configs(2*i+0))));
                    wires_1_out_untwisted(i) <= two_way_s_block_multiplexer_inputs(2*i+1)(to_integer(unsigned(two_way_s_block_multiplexer_configs(2*i+1))));
                end if;
            end process;
        end generate;
        do_not_gen_latches : if not simulation generate
            wires_0_out_untwisted(i) <= two_way_s_block_multiplexer_inputs(2*i+0)(to_integer(unsigned(two_way_s_block_multiplexer_configs(2*i+0))));
            wires_1_out_untwisted(i) <= two_way_s_block_multiplexer_inputs(2*i+1)(to_integer(unsigned(two_way_s_block_multiplexer_configs(2*i+1))));
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
    
    connect_programming_bits_to_bitstream : for i in 0 to tracks_per_channel-1 generate
        -- wire 0:
        two_way_s_block_multiplexer_configs(2*i+0) <= bit_stream(1*2*i+0 downto 1*2*i+0);
        -- wire 1:
        two_way_s_block_multiplexer_configs(2*i+1) <= bit_stream(1*2*i+1 downto 1*2*i+1);
    end generate;

    -----------------
    -- TWIST WIRES --
    -----------------
    twist_wires : for i in 0 to tracks_per_channel-1 generate
        -- inputs
        wires_0_in_twisted(i) <= wires_0_in((i+two_way_s_block_twisting_factor) mod tracks_per_channel);
        wires_1_in_twisted(i) <= wires_1_in(i);
        -- outputs
        wires_0_out_temp(i) <= wires_0_out_untwisted((i-two_way_s_block_twisting_factor) mod tracks_per_channel);
        wires_1_out_temp(i) <= wires_1_out_untwisted(i);
    end generate;
    
    -----------------------------------
    -- INPUTS TO SWITCH MULTIPLEXERS --
    -----------------------------------
    define_mux_inputs : for i in 0 to tracks_per_channel-1 generate
        -- wire 0: 
        two_way_s_block_multiplexer_inputs(2*i+0)(0) <= off;
        two_way_s_block_multiplexer_inputs(2*i+0)(1) <= wires_1_in_twisted(i);
        -- wire 1: 
        two_way_s_block_multiplexer_inputs(2*i+1)(0) <= off;
        two_way_s_block_multiplexer_inputs(2*i+1)(1) <= wires_0_in_twisted(i);
    end generate;

end two_way_s_block;
