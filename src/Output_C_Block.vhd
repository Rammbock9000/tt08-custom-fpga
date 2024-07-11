----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.07.2020 12:15:18
-- Design Name: 
-- Module Name: output_c_block - output_c_block
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

entity output_c_block is
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
        cluster_outputs_in : in std_logic_vector(num_bles_per_cluster-1 downto 0);
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
end output_c_block;

architecture output_c_block of output_c_block is

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
    constant configuration_mux_select_width : integer := pack_inst.programming_bits_output_c_block_per_mux;
    constant bit_stream_length : integer := pack_inst.programming_bits_output_c_block;
    signal bit_stream : std_logic_vector(bit_stream_length-1 downto 0);
    signal output_c_block_multiplexer_configs : pack_inst.output_c_block_multiplexer_configs_t;
    
    -- input to connection multiplexers
    -- for details on dimensions see package
    signal output_c_block_multiplexer_inputs : pack_inst.output_c_block_multiplexer_inputs_t;
    
begin
    
    ---------------------------
    -- GENERATE MULTIPLEXERS --
    ---------------------------
    generate_multiplexers : for i in 0 to (tracks_per_channel-1) generate
        gen_latches : if simulation generate
            process (output_c_block_multiplexer_inputs,output_c_block_multiplexer_configs,bit_stream_enable)
            begin
                if (bit_stream_enable='0') then
                    wires_0_out(i) <= output_c_block_multiplexer_inputs(i*2+0)(to_integer(unsigned(output_c_block_multiplexer_configs(i*2+0))));
                    wires_1_out(i) <= output_c_block_multiplexer_inputs(i*2+1)(to_integer(unsigned(output_c_block_multiplexer_configs(i*2+1))));
                end if;
            end process;
        end generate;
        do_not_gen_latches : if not simulation generate
            wires_0_out(i) <= output_c_block_multiplexer_inputs(i*2+0)(to_integer(unsigned(output_c_block_multiplexer_configs(i*2+0))));
            wires_1_out(i) <= output_c_block_multiplexer_inputs(i*2+1)(to_integer(unsigned(output_c_block_multiplexer_configs(i*2+1))));
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
    
    connect_channel_programming_bits_to_bitstream : for i in 0 to (tracks_per_channel-1) generate
        output_c_block_multiplexer_configs((2*i)+0) <= bit_stream((((2*i)+1)*configuration_mux_select_width)-1 downto (((2*i)+0)*configuration_mux_select_width));
        output_c_block_multiplexer_configs((2*i)+1) <= bit_stream((((2*i)+2)*configuration_mux_select_width)-1 downto (((2*i)+1)*configuration_mux_select_width));
    end generate;
    
    
    ----------------
    -- MUX INPUTS --
    ----------------
    define_mux_inputs : for i in 0 to (tracks_per_channel-1) generate
        -- MSB is always the input from the other side 
        output_c_block_multiplexer_inputs(i*2+0)(num_bles_per_cluster) <= wires_1_in(i);
        output_c_block_multiplexer_inputs(i*2+1)(num_bles_per_cluster) <= wires_0_in(i);
        -- and the other inputs are the cluster outputs
        set_remaining_mux_inputs : for j in 0 to (num_bles_per_cluster-1) generate
            output_c_block_multiplexer_inputs(i*2+0)(j) <= cluster_outputs_in(j);
            output_c_block_multiplexer_inputs(i*2+1)(j) <= cluster_outputs_in(j);
        end generate;
    end generate;

end output_c_block;
