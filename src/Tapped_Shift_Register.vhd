----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.07.2020 10:37:27
-- Design Name: 
-- Module Name: tapped_shift_register - tapped_shift_register
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

entity tapped_shift_register is
    generic (
        n : integer := 8
    );
    port (
        -- inputs
        clk,rst : in std_logic;
        x_in : in std_logic;
        enable : in std_logic;
        -- outputs
        y_out : out std_logic_vector(n-1 downto 0)
    );
end tapped_shift_register;

architecture tapped_shift_register of tapped_shift_register is

    signal delay_line : std_logic_vector(n downto 0);

begin

    -- connect input to delay line
    delay_line(0) <= x_in;
    -- connect output
    y_out <= delay_line(n downto 1);
    
    generate_flipflops : for i in 1 to n generate
        -- generate flipflop
        generate_flipflop : entity work.flipflop
        port map (
            clk => clk,
            rst => rst,
            enable => enable,
            x => delay_line(i-1),
            y => delay_line(i)
        );
    end generate;

end tapped_shift_register;
