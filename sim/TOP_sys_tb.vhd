library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use work.thesis_pkg.all;

entity TOP_sys_tb is
end TOP_sys_tb;

architecture sim of TOP_sys_tb is

    constant clk_hz     : integer := 200e6; -- 200 MHz
--    constant clk_hz     : integer := 125e6; -- 125 MHz
--    constant clk_hz     : integer := 1e6; -- 1 MHz
--    constant clk_hz     : integer := 50e6; -- 50 MHz
    constant clk_period : time    := 1 sec / clk_hz;


    signal clk                     : std_logic     := '1';
    signal reset                   : std_logic     := '1';

    signal start_tb    : std_logic := '0';
    signal ready_tb    : std_logic;
    signal finished_tb : std_logic;
    signal trigger_tb  : std_logic;

    component TOP_sys is
    port (
        p_clk_sys : in std_logic;
        p_reset_sys : in std_logic;
        p_CNN_start_sys : in std_logic;
        p_CNN_ready_sys : out std_logic;
        p_CNN_finished_sys : out std_logic;
        p_trigger_sys : in std_logic
    );
    end component;

begin

    clk <= not clk after clk_period / 2;

    inst_TOP_sys_UUT : TOP_sys
    port map(
        p_clk_sys => clk,
        p_reset_sys => reset,
        p_CNN_start_sys => start_tb,
        p_CNN_ready_sys => ready_tb,
        p_CNN_finished_sys => finished_tb,
        p_trigger_sys => trigger_tb
    );

    SEQUENCER_PROC : process
    begin
        wait for clk_period * 2 + clk_period/2;

        reset <= '0';
        wait for clk_period * 9;

        trigger_tb <= '1';
        wait for clk_period;

        trigger_tb <= '0';
        wait for clk_period * (WB_NUM_WORDS + ACT_NUM_WORDS);

        start_tb <= '1';
        wait for clk_period;

        start_tb <= '0';
        wait;
    end process;

end architecture;
