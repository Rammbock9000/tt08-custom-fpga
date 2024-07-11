library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity tt_um_Rammbock9000_custom_fpga_vhd is
    port (
        ui_in: in std_logic_vector(7 downto 0);
        uo_out: out std_logic_vector(7 downto 0);
        uio_in: in std_logic_vector(7 downto 0);
        uio_out: out std_logic_vector(7 downto 0);
        uio_oe: out std_logic_vector(7 downto 0);
        ena: in std_logic;
        clk: in std_logic;
        rst_n: in std_logic
    );
end tt_um_Rammbock9000_custom_fpga_vhd;

architecture tt_um_Rammbock9000_custom_fpga_vhd of tt_um_Rammbock9000_custom_fpga_vhd is

    signal rst: std_logic;
    signal data_in: std_logic_vector(0 to 7);
    signal data_out: std_logic_vector(0 to 7);
    signal bit_stream_in: std_logic;
    signal bit_stream_enable: std_logic;
    signal bit_stream_rst: std_logic;
    signal bit_stream_out: std_logic;
    
begin
    -- for some reason I thought it was a good idea to use ascending indices for data_in/data_out...
    connect_inputs: for i in 0 to 7 generate
        data_in(i) <= ui_in(i);
        uo_out(i) <= data_out(i);
    end generate;

    -- use configurable i/os for the bitstream
    bit_stream_in <= uio_in(0);
    bit_stream_enable <= uio_in(1);
    bit_stream_rst <= uio_in(2);
    uio_out(3) <= bit_stream_rst;
    uio_oe(7 downto 4) <= "0000"; -- configure the unused ones as inputs
    uio_oe(3 downto 0) <= "1000"; -- #3 is an output and the remaining ones are inputs

    -- instantiate the fpga
    fpga_inst : entity work.fpga_top
    generic map (
        simulation => false,
        fpga_width => 2,
        fpga_height => 2,
        inputs_per_c_block => 1,
        outputs_per_c_block => 1,
        lut_size => 3,
        num_bles_per_cluster => 2,
        inputs_to_cluster => 1,
        tracks_per_channel => 3,
        four_way_s_block_twisting_factor => 1,
        three_way_s_block_twisting_factor => 1,
        two_way_s_block_twisting_factor => 0
    )
    port map (
        clk => clk,
        rst => rst,
        data_in => data_in,
        data_out => data_out,
        bit_stream_in => bit_stream_in,
        bit_stream_enable => bit_stream_enable,
        bit_stream_clk => clk,
        bit_stream_rst => bit_stream_rst,
        bit_stream_out => bit_stream_out
    );

    -- invert reset polarity because we use active-high resets internally
    rst <= not rst_n;

end tt_um_Rammbock9000_custom_fpga_vhd;
