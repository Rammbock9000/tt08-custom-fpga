----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.07.2020 12:37:50
-- Design Name: 
-- Module Name: flipflop - flipflop
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

entity flipflop is
    port (
        clk : in std_logic;
        rst : in std_logic;
        enable : in std_logic;
        x : in std_logic;
        y : out std_logic
    );
end flipflop;

architecture flipflop of flipflop is

begin

    process (clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                y <= '0';
            elsif (enable = '1') then
                y <= x;
            end if;
        end if;
    end process;

end flipflop;
