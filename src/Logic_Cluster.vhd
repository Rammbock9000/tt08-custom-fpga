----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.06.2020 13:50:25
-- Design Name: 
-- Module Name: Logic_Cluster - Logic_Cluster
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

entity logic_cluster is
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
        clk, rst : in std_logic;
        logic_cluster_in : in std_logic_vector(inputs_to_cluster-1 downto 0);
        -- outputs
        logic_cluster_out : out std_logic_vector(num_bles_per_cluster-1 downto 0);
        -- bit stream
        bit_stream_in : in std_logic;
        bit_stream_clk : in std_logic;
        bit_stream_rst : in std_logic;
        bit_stream_enable : in std_logic;
        bit_stream_out : out std_logic
    );
end logic_cluster;

architecture logic_cluster of logic_cluster is

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
        
    -- configuration bits for routing multiplexers
    constant bit_stream_length : integer := pack_inst.programming_bits_routing_muxs_per_cluster;
    signal multiplexer_bit_stream : std_logic_vector(bit_stream_length-1 downto 0);
    signal multiplexer_configs : pack_inst.cluster_multiplexer_configs_t;
    
    -- connect ble bitstreams together and connect it to bitstream for routing multiplexers
    signal ble_bitstream_io : std_logic_vector(num_bles_per_cluster downto 0);
    
    -- data inputs coming from outputs of routing multiplexers
    signal ble_inputs : pack_inst.ble_inputs_t;
    
    -- inputs to the input multiplexers for the BLEs
    -- look into package for details on dimensionality of its inputs
    signal multiplexer_inputs : pack_inst.cluster_multiplexer_inputs_t;
    
    -- temporary BLE outputs (used for feedback to BLE inputs and as cluster output)
    signal ble_outputs : std_logic_vector(num_bles_per_cluster-1 downto 0);
    
begin
    -- debug outputs
    assert FALSE report "entity 'logic_cluster' generic 'simulation' is '" & boolean'image(simulation) & "'" severity NOTE;

    -------------------------
    -- MULTIPLEXER OUTPUTS --
    -------------------------
    set_mux_outputs_outer_loop : for i in 0 to num_bles_per_cluster-1 generate
        set_mux_outputs_inner_loop : for j in 0 to lut_size generate
            gen_latch : if simulation generate
                process (bit_stream_enable,multiplexer_inputs,multiplexer_configs)
                begin
                    if (bit_stream_enable = '0') then
                        ble_inputs(i)(j) <= multiplexer_inputs(i)(j)(to_integer(unsigned(multiplexer_configs(i)(j))));
                    end if;
                end process;
            end generate;
            
            do_not_gen_latch : if not simulation generate
                set_mux_outputs_outer_loop : for i in 0 to num_bles_per_cluster-1 generate
                    set_mux_outputs_inner_loop : for j in 0 to lut_size generate
                        ble_inputs(i)(j) <= multiplexer_inputs(i)(j)(to_integer(unsigned(multiplexer_configs(i)(j))));
                    end generate;
                end generate;
            end generate;
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
        x_in => ble_bitstream_io(num_bles_per_cluster),
        y_out => multiplexer_bit_stream
    );
    bit_stream_out <= multiplexer_bit_stream(multiplexer_bit_stream'length-1);
    
    
    ----------------------------
    -- LUT MULTIPLEXER INPUTS --
    ----------------------------
    gen_input_muxs_outer_loop : for i in 0 to num_bles_per_cluster-1 generate
        -- generate one MUX for each input to the BLE
        gen_input_muxs_inner_loop : for j in 0 to lut_size generate
            -- connect programming input to bitsream
            connect_programming_bits_to_bitstream : for k in 0 to pack_inst.programming_bits_per_routing_mux_per_cluster-1 generate
                multiplexer_configs(i)(j)(k) <= multiplexer_bit_stream((i*(lut_size+1)*pack_inst.programming_bits_per_routing_mux_per_cluster)+(j*pack_inst.programming_bits_per_routing_mux_per_cluster)+(k));
            end generate;
            -- define MUX inputs
            multiplexer_inputs(i)(j) <= logic_cluster_in & ble_outputs & "10";
        end generate;
    end generate;
    
    
    -------------------
    -- GENERATE BLES --
    -------------------
    gen_bles : for i in 0 to num_bles_per_cluster-1 generate
        inst_ble : entity work.basic_logic_element
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
            ble_in => ble_inputs(i),
            ble_out => ble_outputs(i),
            bit_stream_clk => bit_stream_clk,
            bit_stream_rst => bit_stream_rst,
            bit_stream_enable => bit_stream_enable,
            bit_stream_in => ble_bitstream_io(i),
            bit_stream_out => ble_bitstream_io(i+1)
        );
    end generate;
    ble_bitstream_io(0) <= bit_stream_in;
    
    
    --------------------
    -- CLUSTER OUTPUT --
    --------------------
    logic_cluster_out <= ble_outputs;
    
end logic_cluster;
