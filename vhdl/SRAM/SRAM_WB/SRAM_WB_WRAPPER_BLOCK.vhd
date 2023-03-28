library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity SRAM_WB_WRAPPER_BLOCK is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        A     : in std_logic_vector(WB_ADDRESSES - 1 downto 0);
        CSN   : in std_logic;
        D     : in std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
        Q     : out std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
        WEN   : in std_logic
    );
end SRAM_WB_WRAPPER_BLOCK;

architecture structural of SRAM_WB_WRAPPER_BLOCK is
    signal WEN_tmp : std_logic_vector (0 downto 0);

    component WB_BRAM is
        port (
            clka      : in std_logic;
            rsta      : in std_logic;
            ena       : in std_logic;
            wea       : in std_logic_vector(0 downto 0);
            addra     : in std_logic_vector(WB_ADDRESSES - 1 downto 0);
            dina      : in std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
            douta     : out std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
            rsta_busy : out std_logic
        );
    end component;

begin

    -- WB_BRAM
    WB_BRAM_inst : WB_BRAM
    port map(
        clka      => clk,
        rsta      => reset,
        ena       => not(CSN),
        wea       => not(WEN_tmp),
        addra     => A,
        dina      => D,
        douta     => Q,
        rsta_busy => open
    );

    -- PORT Assignations
    WEN_tmp(0) <= WEN;

end architecture;