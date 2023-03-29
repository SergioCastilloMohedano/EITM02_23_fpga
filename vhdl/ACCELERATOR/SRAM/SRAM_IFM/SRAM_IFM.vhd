library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity SRAM_IFM is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        -- To/From Front-End Read Interface
        h_p             : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        w_p             : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        HW              : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        RS              : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        IFM_NL_ready    : in std_logic;
        IFM_NL_finished : in std_logic;
        ifm_out         : out std_logic_vector (ACT_BITWIDTH - 1 downto 0);
        pad             : out natural range 0 to ((2 ** HYP_BITWIDTH) - 1); -- To MC_X
        -- To/From Front-End Write Interface
        is_pooling  : in std_logic;
        en_w_IFM    : in std_logic;
        pooling_ack : in std_logic;
        pooling_IFM : in std_logic_vector (ACT_BITWIDTH - 1 downto 0);
        rn_IFM      : in std_logic_vector (ACT_BITWIDTH - 1 downto 0);
        -- RISC-V Interface
        mem_ctr_ifm  : in std_logic;
        ena_ifm_rv   : in std_logic;
        wea_ifm_rv   : in std_logic_vector(0 downto 0);
        addra_ifm_rv : in std_logic_vector(ACT_ADDRESSES - 1 downto 0);
        dina_ifm_rv  : in std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
        douta_ifm_rv : out std_logic_vector(MEM_WORDLENGTH - 1 downto 0)
    );
end SRAM_IFM;

architecture structural of SRAM_IFM is

    -- SIGNAL DECLARATIONS
    signal h_p_tmp             : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
    signal w_p_tmp             : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
    signal HW_tmp              : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
    signal IFM_NL_ready_tmp    : std_logic;
    signal IFM_NL_finished_tmp : std_logic;
    signal ifm_out_tmp         : std_logic_vector (ACT_BITWIDTH - 1 downto 0);
    signal ifm_r_tmp           : std_logic_vector (ACT_BITWIDTH - 1 downto 0);
    signal RE_tmp              : std_logic;
    signal ifm_w_tmp           : std_logic_vector (ACT_BITWIDTH - 1 downto 0);
    signal en_w_tmp            : std_logic;
    signal WE_tmp              : std_logic;
    signal A_tmp               : std_logic_vector (ACT_ADDRESSES - 1 downto 0);
    signal CSN_tmp             : std_logic;
    signal D_tmp               : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
    signal Q_tmp               : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
    signal WEN_tmp             : std_logic_vector (0 downto 0);

    -- RISC-V Interface
    signal WEN_tmp_rv      : std_logic;
    signal CSN_tmp_rv      : std_logic;
    signal A_tmp_rv        : std_logic_vector(ACT_ADDRESSES - 1 downto 0);
    signal D_tmp_rv        : std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
    signal douta_ifm_rv_tmp : std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
    signal Q_tmp_rv        : std_logic_vector(MEM_WORDLENGTH - 1 downto 0);

    -- COMPONENT DECLARATIONS
    component SRAM_IFM_FRONT_END_READ is
        port (
            h_p             : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            w_p             : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            HW              : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            RS              : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            IFM_NL_ready    : in std_logic;
            IFM_NL_finished : in std_logic;
            ifm_out         : out std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            pad             : out natural range 0 to ((2 ** HYP_BITWIDTH) - 1); -- To MC_X
            -- Back-End (BE) Interface Ports
            ifm_BE_r : in std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            RE_BE    : out std_logic
        );
    end component;

    component SRAM_IFM_FRONT_END_WRITE is
        port (
            clk         : in std_logic;
            is_pooling  : in std_logic;
            en_w_IFM    : in std_logic;
            pooling_ack : in std_logic;
            pooling_IFM : in std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            rn_IFM      : in std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            -- Back-End (BE) Interface Ports
            ifm_BE_w : out std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            en_w     : out std_logic;
            WE_BE    : out std_logic
        );
    end component;

    component SRAM_IFM_BACK_END is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            -- Front-End Interface Ports (READ)
            ifm_FE_r : out std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            RE_FE    : in std_logic;
            -- Front-End Interface Ports (WRITE)
            ifm_FE_w : in std_logic_vector (ACT_BITWIDTH - 1 downto 0);
            en_w     : in std_logic;
            WE_FE    : in std_logic;
            -- SRAM Wrapper Ports
            A   : out std_logic_vector(ACT_ADDRESSES - 1 downto 0);
            CSN : out std_logic;
            D   : out std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            Q   : in std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            WEN : out std_logic
        );
    end component;

    component IFM_BRAM is
        port (
            clka      : in std_logic;
            rsta      : in std_logic;
            ena       : in std_logic;
            wea       : in std_logic_vector(0 downto 0);
            addra     : in std_logic_vector(ACT_ADDRESSES - 1 downto 0);
            dina      : in std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
            douta     : out std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
            rsta_busy : out std_logic
        );
    end component;

begin

    -- SRAM_IFM_FRONT_END_READ
    SRAM_IFM_FRONT_END_READ_inst : SRAM_IFM_FRONT_END_READ
    port map(
        h_p             => h_p_tmp,
        w_p             => w_p_tmp,
        HW              => HW_tmp,
        RS              => RS,
        IFM_NL_ready    => IFM_NL_ready_tmp,
        IFM_NL_finished => IFM_NL_finished_tmp,
        ifm_out         => ifm_out_tmp,
        pad             => pad,
        -- Back-End (BE) Interface Ports
        ifm_BE_r => ifm_r_tmp,
        RE_BE    => RE_tmp
    );

    -- SRAM_IFM_FRONT_END_WRITE
    SRAM_IFM_FRONT_END_WRITE_inst : SRAM_IFM_FRONT_END_WRITE
    port map(
        clk         => clk,
        is_pooling  => is_pooling,
        en_w_IFM    => en_w_IFM,
        pooling_ack => pooling_ack,
        pooling_IFM => pooling_IFM,
        rn_IFM      => rn_IFM,
        ifm_BE_w    => ifm_w_tmp,
        en_w        => en_w_tmp,
        WE_BE       => WE_tmp
    );

    -- SRAM_IFM_BACK_END
    SRAM_IFM_BACK_END_inst : SRAM_IFM_BACK_END
    port map(
        clk      => clk,
        reset    => reset,
        ifm_FE_r => ifm_r_tmp,
        RE_FE    => RE_tmp,
        ifm_FE_w => ifm_w_tmp,
        en_w     => en_w_tmp,
        WE_FE    => WE_tmp,
        A        => A_tmp,
        CSN      => CSN_tmp,
        D        => D_tmp,
        Q        => Q_tmp,
        WEN      => WEN_tmp(0)
    );

    -- IFM_BRAM
    IFM_BRAM_inst : IFM_BRAM
    port map(
        clka      => clk,
        rsta      => reset,
        ena       => not(CSN_tmp_rv),
        wea(0)    => not(WEN_tmp_rv),
        addra     => A_tmp_rv,
        dina      => D_tmp_rv,
        douta     => Q_tmp_rv,
        rsta_busy => open
    );

    -- ***************************
    -- RISC-V Controller Interface
    -- ***************************
    p_riscv : process (mem_ctr_ifm, wea_ifm_rv, ena_ifm_rv, addra_ifm_rv, dina_ifm_rv, Q_tmp_rv, WEN_tmp, CSN_tmp, A_tmp, D_tmp)
    begin
        if (mem_ctr_ifm = '1') then
            WEN_tmp_rv       <= not(wea_ifm_rv(0));
            CSN_tmp_rv       <= not(ena_ifm_rv);
            A_tmp_rv         <= addra_ifm_rv;
            D_tmp_rv         <= dina_ifm_rv;
            douta_ifm_rv_tmp <= Q_tmp_rv;
            Q_tmp            <= (others => '0');
        else
            WEN_tmp_rv       <= WEN_tmp(0);
            CSN_tmp_rv       <= CSN_tmp;
            A_tmp_rv         <= A_tmp;
            D_tmp_rv         <= D_tmp;
            douta_ifm_rv_tmp <= (others => '0');
            Q_tmp            <= Q_tmp_rv;
        end if;
    end process;
    -- ***************************

    -- PORT ASSIGNATIONS
    h_p_tmp             <= h_p;
    w_p_tmp             <= w_p;
    HW_tmp              <= HW;
    IFM_NL_ready_tmp    <= IFM_NL_ready;
    IFM_NL_finished_tmp <= IFM_NL_finished;
    ifm_out             <= ifm_out_tmp;
end architecture;