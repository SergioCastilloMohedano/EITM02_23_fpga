library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity SRAM_WB is
    generic (
        -- HW Parameters, at synthesis time.
        ADDR_CFG : natural := ADDR_CFG_PKG -- First Address of the reserved space for config. parameters.
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        -- Sys. Ctr. Signals
        WB_NL_busy     : in std_logic;
        NoC_c          : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        NoC_pm_bias    : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        OFM_NL_Write   : in std_logic;
        READ_CFG       : in std_logic;
        -- Front-End Read Interface
        w_out   : out std_logic_vector (WEIGHT_BITWIDTH - 1 downto 0);
        b_out   : out std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
        cfg_out : out std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
        -- Front-End Write Interface
        -- ..
        -- RISC-V Interface
        mem_ctr_wb  : in std_logic;
        ena_wb_rv   : in std_logic;
        wea_wb_rv   : in std_logic_vector(0 downto 0);
        addra_wb_rv : in std_logic_vector(WB_ADDRESSES - 1 downto 0);
        dina_wb_rv  : in std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
        douta_wb_rv : out std_logic_vector(MEM_WORDLENGTH - 1 downto 0)
    );
end SRAM_WB;

architecture structural of SRAM_WB is

    -- SIGNAL DECLARATIONS
    signal WB_NL_busy_tmp     : std_logic;
    signal w_out_tmp          : std_logic_vector (WEIGHT_BITWIDTH - 1 downto 0);
    signal b_out_tmp          : std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
    signal cfg_out_tmp        : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
    signal wb_tmp             : std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
    signal cfg_tmp            : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
    signal en_w_read_tmp      : std_logic;
    signal en_b_read_tmp      : std_logic;
    signal en_cfg_read_tmp    : std_logic;
    signal NoC_pm_tmp         : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);

    signal A_tmp   : std_logic_vector(WB_ADDRESSES - 1 downto 0);
    signal CSN_tmp : std_logic;
    signal D_tmp   : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
    signal Q_tmp   : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
    signal WEN_tmp : std_logic;

    -- RISC-V Interface
    signal WEN_tmp_rv      : std_logic;
    signal CSN_tmp_rv      : std_logic;
    signal A_tmp_rv        : std_logic_vector(WB_ADDRESSES - 1 downto 0);
    signal D_tmp_rv        : std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
    signal douta_wb_rv_tmp : std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
    signal Q_tmp_rv        : std_logic_vector(MEM_WORDLENGTH - 1 downto 0);

    -- COMPONENT DECLARATIONS
    component SRAM_WB_FRONT_END_READ is
        port (
            clk            : in std_logic;
            reset          : in std_logic;
            WB_NL_busy     : in std_logic;
            NoC_c          : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            NoC_pm_bias    : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            OFM_NL_Write   : in std_logic;
            READ_CFG       : in std_logic;
            w_out          : out std_logic_vector (WEIGHT_BITWIDTH - 1 downto 0);
            b_out          : out std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
            cfg_out        : out std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            -- Back-End (BE) Interface Ports
            wb_BE       : in std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
            cfg_BE      : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            en_w_read   : out std_logic;
            en_b_read   : out std_logic;
            en_cfg_read : out std_logic;
            NoC_pm_BE   : out std_logic_vector ((HYP_BITWIDTH - 1) downto 0)
        );
    end component;

    component SRAM_WB_BACK_END is
        generic (
            -- HW Parameters, at synthesis time.
            ADDR_CFG : natural := ADDR_CFG_PKG -- First Address of the reserved space for config. parameters.
        );
        port (
            clk   : in std_logic;
            reset : in std_logic;
            -- Front-End Interface Ports
            wb_FE       : out std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
            cfg_FE      : out std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            en_w_read   : in std_logic;
            en_b_read   : in std_logic;
            en_cfg_read : in std_logic;
            NoC_pm_FE   : in std_logic_vector ((HYP_BITWIDTH - 1) downto 0);
            -- SRAM Block Wrapper Ports (ASIC)
            A   : out std_logic_vector(WB_ADDRESSES - 1 downto 0);
            CSN : out std_logic;
            D   : out std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            Q   : in std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            WEN : out std_logic
        );
    end component;

    component SRAM_WB_WRAPPER_BLOCK is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            A     : in std_logic_vector(WB_ADDRESSES - 1 downto 0);
            CSN   : in std_logic;
            D     : in std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            Q     : out std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            WEN   : in std_logic
        );
    end component;

begin

    -- SRAM_WB_FRONT_END_READ
    SRAM_WB_FRONT_END_READ_inst : SRAM_WB_FRONT_END_READ
    port map(
        clk            => clk,
        reset          => reset,
        WB_NL_busy     => WB_NL_busy_tmp,
        NoC_c          => NoC_c,
        NoC_pm_bias    => NoC_pm_bias,
        OFM_NL_Write   => OFM_NL_Write,
        READ_CFG       => READ_CFG,
        w_out          => w_out_tmp,
        b_out          => b_out_tmp,
        cfg_out        => cfg_out_tmp,
        -- Back-End (BE) Interface Ports
        wb_BE       => wb_tmp,
        cfg_BE      => cfg_tmp,
        en_w_read   => en_w_read_tmp,
        en_b_read   => en_b_read_tmp,
        en_cfg_read => en_cfg_read_tmp,
        NoC_pm_BE   => NoC_pm_tmp
    );

    -- SRAM_WB_BACK_END
    SRAM_WB_BACK_END_inst : SRAM_WB_BACK_END
    generic map(
        ADDR_CFG => ADDR_CFG_PKG
    )
    port map(
        clk         => clk,
        reset       => reset,
        wb_FE       => wb_tmp,
        cfg_FE      => cfg_tmp,
        en_w_read   => en_w_read_tmp,
        en_b_read   => en_b_read_tmp,
        en_cfg_read => en_cfg_read_tmp,
        NoC_pm_FE   => NoC_pm_tmp,
        A           => A_tmp,
        CSN         => CSN_tmp,
        D           => open,
        Q           => Q_tmp,
        WEN         => open
    );

    -- SRAM_WB_WRAPPER_BLOCK
    SRAM_WB_WRAPPER_BLOCK_inst : SRAM_WB_WRAPPER_BLOCK
    port map(
        clk   => clk,
        reset => reset,
        A     => A_tmp,
        CSN   => CSN_tmp_rv,
        D     => D_tmp,
        Q     => Q_tmp_rv,
        WEN   => WEN_tmp_rv
    );

    -- ***************************
    -- RISC-V Controller Interface
    -- ***************************
    p_riscv : process (mem_ctr_wb)
    begin
        if (mem_ctr_wb = '1') then
            WEN_tmp_rv      <= not(wea_wb_rv(0));
            CSN_tmp_rv      <= not(ena_wb_rv);
            A_tmp_rv        <= addra_wb_rv;
            D_tmp_rv        <= dina_wb_rv;
            douta_wb_rv_tmp <= Q_tmp_rv;
            Q_tmp           <= (others => '0');
        else
            WEN_tmp_rv      <= '1';
            CSN_tmp_rv      <= CSN_tmp;
            A_tmp_rv        <= A_tmp;
            D_tmp_rv        <= (others => '0');
            douta_wb_rv_tmp <= (others => '0');
            Q_tmp           <= Q_tmp_rv;
        end if;
    end process;
    -- ***************************

    -- PORT ASSIGNATIONS
    WB_NL_busy_tmp     <= WB_NL_busy;
    w_out              <= w_out_tmp;
    b_out              <= b_out_tmp;
    cfg_out            <= cfg_out_tmp;

end architecture;