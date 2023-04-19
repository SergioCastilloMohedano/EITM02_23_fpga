------------------------------------------------------------------------------
-- Generic MUX
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity mux_work is
    generic (
        LEN : natural := HYP_BITWIDTH;
        NUM : natural); -- Number of inputs
    port (
        mux_in  : in hyp_array(0 to NUM - 1) := (others => (others => '0'));
        mux_sel : in natural range 0 to NUM - 1;
        mux_out : out std_logic_vector(LEN - 1 downto 0));
end entity;

architecture syn of mux_work is
begin
    mux_out <= mux_in(mux_sel);
end architecture;