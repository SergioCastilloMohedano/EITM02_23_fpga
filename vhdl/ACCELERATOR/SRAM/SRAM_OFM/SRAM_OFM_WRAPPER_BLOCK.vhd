library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity SRAM_OFM_WRAPPER_BLOCK is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        -- Port 1 (write)
        A_2K_p1   : in std_logic_vector(OFMAP_ADDRESSES - 1 downto 0);
        CSN_2K_p1 : in std_logic;
        D_2K_p1   : in std_logic_vector (OFMAP_WORDLENGTH - 1 downto 0);
        WEN_2K_p1 : in std_logic;
        -- Port 2 (read)
        A_2K_p2   : in std_logic_vector(OFMAP_ADDRESSES - 1 downto 0);
        CSN_2K_p2 : in std_logic;
        Q_2K_p2   : out std_logic_vector (OFMAP_WORDLENGTH - 1 downto 0)
    );
end SRAM_OFM_WRAPPER_BLOCK;

architecture structural of SRAM_OFM_WRAPPER_BLOCK is

    -- SIGNALS DECLARATIONS
    signal Q_2K_p2_tmp   : std_logic_vector (OFMAP_WORDLENGTH - 1 downto 0);
    signal WEN_2K_p1_tmp : std_logic_vector (0 downto 0);

    component OFMAP_BRAM is
        port (
            clka      : in std_logic;
            ena       : in std_logic;
            wea       : in std_logic_vector(0 downto 0);
            addra     : in std_logic_vector(OFMAP_ADDRESSES - 1 downto 0);
            dina      : in std_logic_vector(OFMAP_WORDLENGTH - 1 downto 0);
            clkb      : in std_logic;
            rstb      : in std_logic;
            enb       : in std_logic;
            addrb     : in std_logic_vector(OFMAP_ADDRESSES - 1 downto 0);
            doutb     : out std_logic_vector(OFMAP_WORDLENGTH - 1 downto 0);
            rsta_busy : out std_logic;
            rstb_busy : out std_logic
        );
    end component;

begin

    -- SRAM_OFM_FRONT_END_OUT
    OFMAP_BRAM_inst : OFMAP_BRAM
    port map(
        clka      => clk,
        ena       => not(CSN_2K_p1),
        wea       => not(WEN_2K_p1_tmp),
        addra     => A_2K_p1,
        dina      => D_2K_p1,
        clkb      => clk,
        rstb      => reset,
        enb       => not(CSN_2K_p2),
        addrb     => A_2K_p2,
        doutb     => Q_2K_p2_tmp,
        rsta_busy => open,
        rstb_busy => open
    );

    -- PORT ASSIGNATIONS
    Q_2K_p2          <= Q_2K_p2_tmp;
    WEN_2K_p1_tmp(0) <= WEN_2K_p1;

end architecture;