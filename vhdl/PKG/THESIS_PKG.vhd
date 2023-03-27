library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

package thesis_pkg is

    -- CNN Parameters (shall be changed if a different CNN is to be run)
    ---- This parameters configure the bitwidths along the datapath and
    ---- computation path of the whole accelerator.act_2D_array
    constant RS_max_PKG      : natural := 3;
    constant r_max_PKG       : natural := 1;
    constant C_max_PKG       : natural := 1;
    constant M_max_PKG       : natural := 8;
    constant EF_max_PKG      : natural := 8;
    constant EF_log2_max_PKG : natural := natural(log2(real(EF_max_PKG)));
    constant padding_PKG     : natural := (-1 + RS_max_PKG)/2;
    constant HW_p_max_PKG    : natural := EF_max_PKG + 2 * padding_PKG;
    constant p_PKG           : natural := 4;
    constant layers_PKG      : natural := 1; -- # no of (conv.) layers in the CNN

    -- HW Parameters, at synthesis time.
    constant X_PKG : natural := 8;
    constant Y_PKG : natural := 3;
    type integer_array is array(natural range <>) of integer; -- Array Definition
    constant hw_log2_r_PKG             : integer_array := (0, 1, 2);
    constant hw_log2_EF_PKG            : integer_array := (EF_log2_max_PKG, EF_log2_max_PKG - 1, EF_log2_max_PKG - 2);
    constant NUM_REGS_IFM_REG_FILE_PKG : natural       := HW_p_max_PKG;       -- W' max (conv0 and conv1)
    constant NUM_REGS_W_REG_FILE_PKG   : natural       := p_PKG * RS_max_PKG; -- p*S = 8*3 = 24
    constant NUM_OF_PARAMS_PKG         : natural       := 13;                 -- Number of parameters to set for each layer (M, C, EF, RS, r, p, ...)

    -- **** TYPE DECLARATIONS ****
    constant ACT_BITWIDTH     : natural := 16;
    constant WEIGHT_BITWIDTH  : natural := 10;
    constant BIAS_BITWIDTH    : natural := 16;
    constant PSUM_BITWIDTH    : natural := natural(ceil(log2(real(RS_max_PKG * RS_max_PKG * 2 ** (WEIGHT_BITWIDTH) * 2 ** (ACT_BITWIDTH)))));                         -- determines bitwidth of the psum considering worst case scenario accumulations
    constant OFMAP_P_BITWIDTH : natural := natural(ceil(log2(real(r_max_PKG * RS_max_PKG * RS_max_PKG * 2 ** (WEIGHT_BITWIDTH) * 2 ** (ACT_BITWIDTH)))));             -- Bitwidth of Adder Tree
    constant OFMAP_BITWIDTH   : natural := natural(ceil(log2(real(C_max_PKG * r_max_PKG * RS_max_PKG * RS_max_PKG * 2 ** (WEIGHT_BITWIDTH) * 2 ** (ACT_BITWIDTH))))); -- determines bitwidth of the ofmap, once all ofmap primitives have been accumulated, for worst case scenario
    constant HYP_BITWIDTH     : natural := 8;

    -- *** Fixed-Point Quantization Scheme: q<i.f> ***
    constant q_w        : natural := WEIGHT_BITWIDTH;
    constant f_w        : natural := 4;
    constant i_w        : natural := q_w - f_w;
    constant q_act      : natural := ACT_BITWIDTH;
    constant f_act      : natural := 10;
    constant i_act      : natural := q_act - f_act;
    constant q_ofmap    : natural := OFMAP_BITWIDTH;
    constant f_ofmap    : natural := f_w + f_act;
    constant i_ofmap    : natural := q_ofmap - f_ofmap;
    constant q_bias     : natural := BIAS_BITWIDTH;
    constant f_bias     : natural := 13;
    constant i_bias     : natural := q_bias - f_bias;
    constant align      : natural := abs(f_ofmap - f_bias); -- # of LSBs to be added to the bias prior to add it to the ofmap. Notice that f_ofmap MUST be greater than f_bias.
    constant trunc_high : integer := f_ofmap + i_act - 1;   -- For truncating ofmaps in RN_ReLU Block
    constant trunc_low  : integer := f_ofmap - f_act;       -- For truncating ofmaps in RN_ReLU Block
    -- ***********************************************

    -- *** Memories Interfaces ***
    constant OFMAP_WORDLENGTH : natural := OFMAP_BITWIDTH;
    constant OFMAP_ADDRESSES  : natural := natural(ceil(log2(real(M_max_PKG * EF_max_PKG * EF_max_PKG))));
    constant WB_WORDLENGTH    : natural := 32;
    constant WB_ADDRESSES     : natural := natural(ceil(log2(real((C_max_PKG * M_max_PKG * RS_max_PKG * RS_max_PKG)/natural(floor(real(WB_WORDLENGTH)/real(WEIGHT_BITWIDTH))) + (M_max_PKG)/(WB_WORDLENGTH/BIAS_BITWIDTH) + layers_PKG * ((NUM_OF_PARAMS_PKG - 1)/(WB_WORDLENGTH/HYP_BITWIDTH)) + 1)))); -- Depends on CNN, unless changed later if layer-by-layer basis, in which case I'd need space for largest layer.
    constant ACT_WORDLENGTH   : natural := 32;
    constant ACT_ADDRESSES    : natural := natural(ceil(log2(real((M_max_PKG * EF_max_PKG/2 * EF_max_PKG/2)/(ACT_WORDLENGTH/ACT_BITWIDTH))))); -- Output of Max. Pooling (8*4*4)
    constant ADDR_CFG_PKG     : natural := natural(ceil(real((C_max_PKG * M_max_PKG * RS_max_PKG * RS_max_PKG)/natural(floor(real(WB_WORDLENGTH)/real(WEIGHT_BITWIDTH))) + (M_max_PKG)/(WB_WORDLENGTH/BIAS_BITWIDTH)))); -- First Address of the reserved space for config. parameters.

    type weight_array is array (natural range <>) of std_logic_vector(WEIGHT_BITWIDTH - 1 downto 0);
    type weight_2D_array is array (natural range <>) of weight_array;
    type act_array is array (natural range <>) of std_logic_vector(ACT_BITWIDTH - 1 downto 0);
    type act_2D_array is array (natural range <>) of act_array;

    type hyp_array is array(natural range <>) of std_logic_vector(HYP_BITWIDTH - 1 downto 0);

    type std_logic_array is array(natural range <>) of std_logic;
    type std_logic_2D_array is array(natural range <>) of std_logic_array;
    type psum_array is array(natural range <>) of std_logic_vector(PSUM_BITWIDTH - 1 downto 0);
    type psum_2D_array is array(natural range <>) of psum_array;
    type ofmap_p_array is array (natural range <>) of std_logic_vector(OFMAP_P_BITWIDTH - 1 downto 0);
    type ofmap_array is array (natural range <>) of std_logic_vector(OFMAP_BITWIDTH - 1 downto 0);

    -- **** PROCEDURES DECLARATIONS ****

    -- **** FUNCTIONS DECLARATIONS ****

    --## Compute the total number of bits needed to represent a number in binary.
    --#
    --# Args:
    --#   n: Number to compute size from
    --# Returns:
    --#   Number of bits.
    --# [SOURCE: https://github.com/kevinpt/vhdl-extras]
    function bit_size(n : natural) return natural;

    --## Decoder with variable sized output (power of 2).
    --# Args:
    --#  Sel: Numeric value to decode (range 0 to 2**Sel'length-1)
    --# Returns:
    --#  Decoded (one-hot) representation of Sel.
    --# [SOURCE: https://github.com/kevinpt/vhdl-extras]
    function decode(Sel : unsigned) return std_logic_vector;

    --## Decoder with variable sized output (user specified).
    --# Args:
    --#  Sel:  Numeric value to decode (range 0 to Size-1)
    --#  Size: Number of bits in result (leftmost bits)
    --# Returns:
    --#  Decoded (one-hot) representation of Sel.
    --# [SOURCE: https://github.com/kevinpt/vhdl-extras]
    function decode(Sel : unsigned; Size : positive
    ) return std_logic_vector;

    -- ceil_log2div
    --------------------------------------------------------------------------------------
    -- Division of fixed-point integer by a log2 value, returns ceil of result.
    function ceil_log2div (x : std_logic_vector; y : integer) return std_logic_vector;
    -- Result subtype: std_logic_vector 
    -- Result: Performs a division of "x" over 2^y by
    -- right-shifting "x" by "y" positions. The result signal
    -- has same size has input "x" and is the ceil of the division's
    -- result.

    --------------------------------------------------------------------------------------
    -- **** COMPONENT DECLARATIONS ****

    -- Ceil of log2 div
    --------------------------------------------------------------------------------------
    -- Inputs "x", an integer number as std_logic_vector and divides it by 2^y. Being "y"
    -- the other input. Returns the ceil of the result "z" as std_logic_vector.
    -- For example:
    -- x = 5 = 0101
    -- y = 1
    -- z = ceil(5/2^1) = ceil(2.5) = 3 = 0011
    --------------------------------------------------------------------------------------
    component CEIL_LOG2_DIV is
        generic (
            y : integer range 0 to 8 := 1
        );
        port (
            x : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            z : out std_logic_vector ((HYP_BITWIDTH - 1) downto 0)
        );
    end component;

    component mux is
        generic (
            LEN : natural := HYP_BITWIDTH; -- Bits in each input (must be 8 due to data type definition being constrained to 8).
            NUM : natural                  -- Number of inputs
        );
        port (
            mux_in  : in hyp_array(0 to NUM - 1);
            mux_sel : in natural range 0 to NUM - 1;
            mux_out : out std_logic_vector(LEN - 1 downto 0));
    end component;

end thesis_pkg;

package body thesis_pkg is

    -- **** FUNCTIONS DEFINITIONS ****

    --## Compute the total number of bits needed to represent a number in binary.  [SOURCE: https://github.com/kevinpt/vhdl-extras]
    function bit_size(n          : natural) return natural is
        variable log, residual, base : natural;
    begin
        residual := n;
        base     := 2;
        log      := 0;

        while residual > (base - 1) loop
            residual := residual / base;
            log      := log + 1;
        end loop;

        if n = 0 then
            return 1;
        else
            return log + 1;
        end if;
    end function;

    -- ## Decoder with variable sized output (power of 2)  [SOURCE: https://github.com/kevinpt/vhdl-extras]
    function decode(Sel : unsigned) return std_logic_vector is

        variable result : std_logic_vector(0 to (2 ** Sel'length) - 1);
    begin

        -- generate the one-hot vector from binary encoded Sel
        result                  := (others => '0');
        result(to_integer(Sel)) := '1';
        return result;
    end function;

    --## Decoder with variable sized output (user specified)  [SOURCE: https://github.com/kevinpt/vhdl-extras]
    function decode(Sel : unsigned; Size : positive)
        return std_logic_vector is

        variable full_result : std_logic_vector(0 to (2 ** Sel'length) - 1);
    begin
        -- assert Size <= 2 ** Sel'length
        -- report "Decoder output size: " & integer'image(Size)
        --     & " is too big for the selection vector"
        --     severity failure;

        full_result := decode(Sel);
        return full_result(0 to Size - 1);
    end function;

    -- ceil_log2div
    function ceil_log2div (x : std_logic_vector; y : integer) return std_logic_vector is
        variable tmp        : std_logic_vector ((x'left + y) downto x'right);
        variable zeroes     : std_logic_vector (y - 1 downto 0) := (others => '0');
        variable IW         : std_logic_vector (x'left + y downto x'right + y);
        variable FW         : std_logic_vector (x'right + y - 1 downto x'right);
        variable result     : unsigned (x'left downto x'right);
        variable result_tmp : unsigned (x'left downto x'right);
    begin
        tmp := x & zeroes;
        tmp := std_logic_vector(shift_right(unsigned(tmp), y));
        IW  := zeroes & tmp (x'left downto x'right + y);
        FW  := tmp (x'right + y - 1 downto x'right);

        if to_integer(unsigned(FW)) > 0 then
            result_tmp := resize (unsigned(IW) + to_unsigned(1, IW'length), result'length);
        else
            result_tmp := resize (unsigned(IW), result'length);
        end if;

        if y = 0 then
            result := unsigned(x);
        else
            result := result_tmp;
        end if;

        return std_logic_vector(result);

    end function ceil_log2div;
end thesis_pkg;

------------------------------------------------------------------------------
-- Ceil of log 2 div
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity CEIL_LOG2_DIV is
    generic (
        y : integer range 0 to 8 := 1
    );
    port (
        x : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        z : out std_logic_vector ((HYP_BITWIDTH - 1) downto 0)
    );
end CEIL_LOG2_DIV;

architecture dataflow of CEIL_LOG2_DIV is

    signal tmp : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);

begin

    tmp <= ceil_log2div(x, y);
    z   <= tmp;

end architecture;

------------------------------------------------------------------------------
-- Generic MUX
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity mux is
    generic (
        LEN : natural := HYP_BITWIDTH;
        NUM : natural); -- Number of inputs
    port (
        mux_in  : in hyp_array(0 to NUM - 1) := (others => (others => '0'));
        mux_sel : in natural range 0 to NUM - 1;
        mux_out : out std_logic_vector(LEN - 1 downto 0));
end entity;

architecture syn of mux is
begin
    mux_out <= mux_in(mux_sel);
end architecture;