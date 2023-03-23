library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity RN_RELU is
    port (
        value_in  : in std_logic_vector (OFMAP_BITWIDTH - 1 downto 0);
        value_out : out std_logic_vector (ACT_BITWIDTH - 1 downto 0)
    );
end RN_RELU;

architecture dataflow of RN_RELU is

    -- signal declarations
    signal value_relu  : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal value_round : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal value_trunc : signed (ACT_BITWIDTH - 1 downto 0);
    signal rounding    : std_logic_vector (ACT_BITWIDTH - 1 downto 0);
    signal rounding_s  : signed (ACT_BITWIDTH - 1 downto 0);

begin

    -- ReLU:
    value_relu <= (others => '0') when (signed(value_in) < 0) else -- ReLU
        signed(value_in);

    -- Rounding:
    -- ofmap: 28<13.15>, act: 16<6.10>   (BW.<I.F>)
    -- ofmap:  IIII IIII IIII IFFF FFFF FFFF FFFF
    -- act:    ---- ---I IIII IFFF FFFF FFF- ----
    --                          (15 - 10): ↑
    rounding                  <= (others => '0');
    rounding(f_ofmap - f_act) <= '1';
    rounding_s                <= signed(rounding);
    value_round               <= (value_relu + rounding_s) when (value_relu > 0) else
        value_relu;

    -- Truncation:
    -- min_16b = -2^(16 - 1)    = -32768 = b01111...1111;
    -- max_16b = 2^(16 - 1) - 1 =  32767 = b10000...0000;
    p_truncation : process (value_round)
        variable min_act : integer := - 2 ** (ACT_BITWIDTH - 1);
        variable max_act : integer := 2 ** (ACT_BITWIDTH - 1);
    begin
        if (to_integer(value_round(trunc_high downto trunc_low)) >= max_act) then
            value_round(trunc_high downto trunc_low) <= to_signed(max_act, ACT_BITWIDTH);
        elsif (to_integer(value_round(trunc_high downto trunc_low)) <= min_act) then
            value_round(trunc_high downto trunc_low) <= to_signed(min_act, ACT_BITWIDTH);
        else
            value_round(trunc_high downto trunc_low) <= value_round(trunc_high downto trunc_low);
        end if;
    end process p_truncation;

    value_trunc <= value_round(trunc_high downto trunc_low);

    value_out <= std_logic_vector(value_trunc);

end architecture;