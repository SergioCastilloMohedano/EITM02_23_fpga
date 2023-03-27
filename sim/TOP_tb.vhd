library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;

entity TOP_tb is
end TOP_tb;

architecture sim of TOP_tb is

--    constant clk_hz     : integer := 200e6; -- 200 MHz
--    constant clk_hz     : integer := 125e6; -- 125 MHz
--    constant clk_hz     : integer := 1e6; -- 1 MHz
    constant clk_hz     : integer := 50e6; -- 50 MHz
    constant clk_period : time    := 1 sec / clk_hz;


    signal clk                     : std_logic     := '1';
    signal reset                   : std_logic     := '1';

    signal NL_start_tb    : std_logic := '0';
    signal NL_ready_tb    : std_logic;
    signal NL_finished_tb : std_logic;

    component TOP is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        NL_start    : in std_logic;
        NL_ready    : out std_logic;
        NL_finished : out std_logic
    );
    end component;

begin

    clk <= not clk after clk_period / 2;

    inst_TOP_UUT : TOP
    port map(
        clk         => clk,
        reset       => reset,
        NL_start    => NL_start_tb,
        NL_ready    => NL_ready_tb,
        NL_finished => NL_finished_tb
    );

    SEQUENCER_PROC : process
    begin
        wait for clk_period * 2 + clk_period/2;

        reset <= '0';

        wait for clk_period * 9;
        NL_start_tb <= '1';
        wait for clk_period;
        NL_start_tb <= '0';
        wait;
    end process;

end architecture;
