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

    signal act_out_tb : std_logic := '0';
    signal act_tb     : std_logic_vector (ACT_BITWIDTH - 1 downto 0);
    signal act_ok_tb  : std_logic;

    component TOP_sys is
    port (
        p_clk_sys          : in std_logic;
        p_reset_sys        : in std_logic;
        p_CNN_start_sys    : in std_logic;
        p_CNN_ready_sys    : out std_logic;
        p_CNN_finished_sys : out std_logic;
        p_trigger_sys      : in std_logic;
        p_act_out          : in std_logic;
        p_act              : out std_logic_vector (ACT_BITWIDTH - 1 downto 0);
        p_act_ok           : out std_logic
    );
    end component;

begin

    clk <= not clk after clk_period / 2;

    inst_TOP_sys_UUT : TOP_sys
    port map(
        p_clk_sys          => clk,
        p_reset_sys        => reset,
        p_CNN_start_sys    => start_tb,
        p_CNN_ready_sys    => ready_tb,
        p_CNN_finished_sys => finished_tb,
        p_trigger_sys      => trigger_tb,
        p_act_out          => act_out_tb,
        p_act              => act_tb,
        p_act_ok           => act_ok_tb
    );

    SEQUENCER_PROC : process
    begin
        wait for clk_period * 2 + clk_period/2;

        reset <= '0';
        wait for clk_period * 9;

        -- First we load the input image, weights, biases and cfg. parameters
        -- into the internal memories of the accelerator.
        trigger_tb <= '1';
        wait for clk_period;
        trigger_tb <= '0';

        wait for clk_period * (WB_NUM_WORDS + ACT_NUM_WORDS);

        -- Second the accelerator starts computation, we wait until computation
        -- is finished (CNN_finished = '1')
        start_tb <= '1';
        wait for clk_period;
        start_tb <= '0';

        -- Third we write back the activations resulting from CNN computation back
        -- to the external BRAM.
        wait on finished_tb; -- finished is asserted
        wait for clk_period * ACT_NUM_WORDS; -- activations are being written back to EXT BRAM
        wait for clk_period * 5;

        -- Lastly we output one activation at a time from EXT BRAM
        for i in 0 to ((ACT_NUM_WORDS * (MEM_WORDLENGTH/ACT_BITWIDTH)) - 1) loop
            act_out_tb <= '1';
            wait for clk_period;
            act_out_tb <= '0';
            wait for clk_period;
        end loop; -- comparing

        wait;

    end process;

end architecture;
