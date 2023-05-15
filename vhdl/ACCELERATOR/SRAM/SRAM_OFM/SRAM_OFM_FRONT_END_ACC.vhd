library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity SRAM_OFM_FRONT_END_ACC is
    port (
        -- From Sys. Controller
        OFM_NL_Write : in std_logic;
        NoC_c        : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        -- From PISO Buffer
        shift_PISO : in std_logic;
        ofm_in     : in std_logic_vector (OFMAP_P_BITWIDTH - 1 downto 0);
        -- From/To Back-End Interface
        en_ofm_in  : out std_logic;
        en_ofm_sum : out std_logic;
        WE         : out std_logic;
        ofm_sum    : in std_logic_vector (OFMAP_BITWIDTH - 1 downto 0);
        ofm_BE     : out std_logic_vector (OFMAP_BITWIDTH - 1 downto 0);
        -- From WB SRAM
        bias : in std_logic_vector (BIAS_BITWIDTH - 1 downto 0)
    );
end SRAM_OFM_FRONT_END_ACC;

architecture dataflow of SRAM_OFM_FRONT_END_ACC is

    signal ofm_BE_tmp     : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal ofm_BE_tmp_2   : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal ofm_BE_tmp_3   : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal sign_extension : signed (OFMAP_BITWIDTH - OFMAP_P_BITWIDTH - 1 downto 0);
    signal acc_addition   : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal ofm_in_tmp     : signed (OFMAP_P_BITWIDTH - 1 downto 0);
    signal ofm_sum_tmp    : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal NoC_c_tmp      : natural;
    signal en_ofm_in_tmp  : std_logic;
    signal en_ofm_sum_tmp : std_logic;
    signal WE_tmp         : std_logic;
    signal NoC_c_nez      : std_logic;
    signal bias_tmp       : signed (BIAS_BITWIDTH - 1 downto 0);

    signal acc_bias        : signed (OFMAP_BITWIDTH - 1 downto 0);
    signal acc_bias_case_2 : signed (OFMAP_BITWIDTH + align - 1 downto 0); -- when f_ofmap < f_bias the resulting value is OFMAP_BITWIDTH + align
    signal bias_extension  : signed (align - 1 downto 0);

begin

    NoC_c_nez <= '0' when (NoC_c_tmp = 0) else '1'; --nez: not equal to zero

    ---- Case 1: r_max = 1 -> OFMAP_P_BITWIDTH = PSUM_BITWIDTH
    ---- There is no need to use sign extension.
    s_case_1 : if (OFMAP_P_BITWIDTH = PSUM_BITWIDTH) generate
        acc_addition   <= (ofm_in_tmp + ofm_sum_tmp);
        ofm_BE_tmp_3   <= (ofm_in_tmp) when (NoC_c_nez = '0') else acc_addition; -- acc.
    end generate;

    ---- Case 2: r_max > 1 -> OFMAP_P_BITWIDTH > PSUM_BITWIDTH
    ---- We use sign extension.
    s_case_2 : if (OFMAP_P_BITWIDTH > PSUM_BITWIDTH) generate
        sign_extension <= (others => ofm_in_tmp(ofm_in_tmp'length - 1));
        acc_addition   <= (ofm_in_tmp + ofm_sum_tmp);
        ofm_BE_tmp_3   <= (sign_extension & ofm_in_tmp) when (NoC_c_nez = '0') else acc_addition; -- acc.
    end generate;

    -- **** Alignment of bias and ofmap ****
    ---- Case 1: f_ofmap > f_bias -> align bits are added to LSBs part of bias.
    ---- The result has the same bitwidth as the ofmap.
    p_case_1 : if (f_ofmap > f_bias) generate
        bias_extension <= (others => '0');
        acc_bias       <= ofm_BE_tmp_3 + (bias_tmp & bias_extension);
    end generate;

    ---- Case 2: f_bias > f_ofmap -> align bits are added to LSBs part of ofmap
    ---- In this special case I should evaluate the impact in accuracy when trimming "align" MSBs bits of acc_bias_case_2
    p_case_2 : if (f_bias > f_ofmap) generate
        bias_extension  <= (others => '0');
        acc_bias_case_2 <= (ofm_BE_tmp_3 & bias_extension) + bias_tmp;
        acc_bias        <= acc_bias_case_2((acc_bias_case_2'left - align) downto 0);
    end generate;

    ---- Case 3: f_bias = f_ofmap -> no alignment needed: align = 0
    p_case_3 : if (f_bias = f_ofmap) generate
        acc_bias <= ofm_BE_tmp_3 + bias_tmp;
    end generate;
    -- *************************************

    ofm_BE_tmp_2 <= ofm_BE_tmp_3 when (NoC_c_nez = '1') else (acc_bias); -- bias
    ofm_BE_tmp   <= ofm_BE_tmp_2;                                        -- There is no need of truncation since wordlenght of memory is OFMAP_BITWIDTH

    -- PORT Assignations
    ofm_BE         <= std_logic_vector(ofm_BE_tmp);
    ofm_in_tmp     <= signed(ofm_in);
    ofm_sum_tmp    <= signed(ofm_sum);
    NoC_c_tmp      <= to_integer(unsigned(NoC_c));
    en_ofm_in      <= en_ofm_in_tmp;
    en_ofm_sum     <= en_ofm_sum_tmp;
    WE             <= WE_tmp;
    en_ofm_in_tmp  <= OFM_NL_Write;
    en_ofm_sum_tmp <= NoC_c_nez;
    WE_tmp         <= shift_PISO;
    bias_tmp       <= signed(bias);

end architecture;