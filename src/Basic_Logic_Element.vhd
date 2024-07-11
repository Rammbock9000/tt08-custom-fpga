----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.06.2020 13:50:25
-- Design Name: 
-- Module Name: Basic_Logic_Element - Basic_Logic_Element
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

entity basic_logic_element is
    generic (
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
        clk, rst : in std_logic;
        -- MSB of ble_in is used as an external flip flop reset!
        ble_in : in std_logic_vector(lut_size downto 0);
        -- outputs
        ble_out : out std_logic;
        -- bit stream
        bit_stream_in : in std_logic;
        bit_stream_clk : in std_logic;
        bit_stream_rst : in std_logic;
        bit_stream_enable : in std_logic;
        bit_stream_out : out std_logic
    );
end basic_logic_element;

architecture basic_logic_element of basic_logic_element is

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
        
    signal lut_output : std_logic;
    signal ff_output : std_logic;
    -- configuration bits
    constant bit_stream_length : integer := pack_inst.programming_bits_ble;
    signal bit_stream : std_logic_vector(bit_stream_length-1 downto 0);
    signal lut_config : std_logic_vector((2**lut_size)-1 downto 0);
    signal use_flipflop : std_logic;
    -- temporary output signal (needed for simulation to avoid async cycles)
    signal ble_out_temp : std_logic;
    -- reset input for flip flop
    signal ff_rst : std_logic;
    -- lut input
    signal lut_input : std_logic_vector(lut_size-1 downto 0);
    
begin
    lut_input <= ble_in(lut_size-1 downto 0);
    
    -------------
    -- OUTPUTS --
    -------------
    gen_latch : if simulation generate
        process (ble_out_temp,bit_stream_enable,lut_config,lut_input)
        begin
            if (bit_stream_enable='0') then
                lut_output <= lut_config(to_integer(unsigned(lut_input)));
                ble_out <= ble_out_temp;
            end if;
        end process;
    end generate;
    do_not_gen_latch : if not simulation generate
        lut_output <= lut_config(to_integer(unsigned(lut_input)));
        ble_out <= ble_out_temp;
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
    lut_config <= bit_stream((2**lut_size)-1 downto 0);
    use_flipflop <= bit_stream(2**lut_size);
    
    
    --------------
    -- FLIPFLOP --
    --------------
    ff_rst <= rst or ble_in(lut_size);
    process(ff_rst,clk)
    begin
        if (ff_rst='1') then
            ff_output <= '0';
        elsif (rising_edge(clk)) then
            ff_output <= lut_output;
        end if;
    end process;
    
    
    ------------------------
    -- OUTPUT MULTIPLEXER --
    ------------------------
    with use_flipflop select ble_out_temp <=
        ff_output when '1',
        lut_output when others;

end basic_logic_element;
