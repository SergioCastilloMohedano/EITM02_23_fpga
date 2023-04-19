library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity TOP_sys is
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
end TOP_sys;

architecture structural of TOP_sys is

    signal mem_ctr_tmp  : std_logic_vector (1 downto 0);
    signal en_ext_tmp   : std_logic;
    signal en_cnn_tmp   : std_logic;
    signal we_ext_tmp   : std_logic;
    signal we_cnn_tmp   : std_logic;
    signal addra_tmp    : std_logic_vector (EXT_ADDRESSES - 1 downto 0);
    signal data_tmp     : std_logic_vector (EXT_WORDLENGTH - 1 downto 0);
    signal addr_cnn_tmp : std_logic_vector (EXT_ADDRESSES - 1 downto 0);

    signal p_CNN_finished_sys_tmp : std_logic;
    signal en_gold_tmp            : std_logic;
    signal addr_gold_tmp          : std_logic_vector (ACT_ADDRESSES - 1 downto 0);
    signal dout_gold_tmp          : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
    signal act_gold_tmp           : std_logic_vector (ACT_BITWIDTH - 1 downto 0);

    signal act_ok_tmp      : std_logic;
    signal act_out_tmp     : std_logic_vector (ACT_BITWIDTH - 1 downto 0);
    signal act_out_ctr_tmp : std_logic_vector (1 downto 0);
    signal data_writeback  : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
    signal data_out_tmp    : std_logic_vector (MEM_WORDLENGTH - 1 downto 0);

    signal act_out       : std_logic;
    signal CNN_start_sys : std_logic;
    signal trigger_sys   : std_logic;

    -- COMPONENT DECLARATIONS
    -- ACCELERATOR
    component CNN_TOP is
        generic (
            -- HW Parameters, at synthesis time.
            X                     : natural       := X_PKG; -- Emax of network (conv0 and conv1)
            Y                     : natural       := Y_PKG;
            hw_log2_r             : integer_array := hw_log2_r_PKG;
            hw_log2_EF            : integer_array := hw_log2_EF_PKG;
            NUM_REGS_IFM_REG_FILE : natural       := NUM_REGS_IFM_REG_FILE_PKG; -- W' max (conv0 and conv1)
            NUM_REGS_W_REG_FILE   : natural       := NUM_REGS_W_REG_FILE_PKG;   -- p*S = 8*3 = 24
            ADDR_CFG              : natural       := ADDR_CFG_PKG               -- First Address of the reserved space for config. parameters.
        );
        port (
            p_clk          : in std_logic;
            p_reset        : in std_logic;
            p_CNN_start    : in std_logic;
            p_CNN_ready    : out std_logic;
            p_CNN_finished : out std_logic;
            -- RISC-V INTERFACE
            p_mem_ctr : in std_logic_vector (1 downto 0);
            p_en_rv   : in std_logic;
            p_we_rv   : in std_logic;
            p_addr_rv : in std_logic_vector (maximum(WB_ADDRESSES, ACT_ADDRESSES) - 1 downto 0);
            p_din_rv  : in std_logic_vector (MEM_WORDLENGTH - 1 downto 0);
            p_dout_rv : out std_logic_vector (MEM_WORDLENGTH - 1 downto 0)
        );
    end component;

    -- EXTERNAL BRAM CONTROLLER
    component EXT_BRAM_CTR is
        port (
            clk         : in std_logic;
            reset       : in std_logic;
            trigger     : in std_logic;
            en_ext      : out std_logic;
            en_cnn      : out std_logic;
            we_ext      : out std_logic;
            we_cnn      : out std_logic;
            addr_ext    : out std_logic_vector (EXT_ADDRESSES - 1 downto 0);
            addr_cnn    : out std_logic_vector (EXT_ADDRESSES - 1 downto 0);
            mem_ctr     : out std_logic_vector (1 downto 0);
            finish_cnn  : in std_logic;
            en_gold     : out std_logic;
            addr_gold   : out std_logic_vector (ACT_ADDRESSES - 1 downto 0);
            act_out     : in std_logic;
            act_out_ctr : out std_logic_vector (1 downto 0)
        );
    end component;

    -- EXTERNAL BRAM
    component blk_mem_gen_0 is
        port (
            clka      : in std_logic;
            rsta      : in std_logic;
            ena       : in std_logic;
            wea       : in std_logic_vector(0 downto 0);
            addra     : in std_logic_vector(5 downto 0);
            dina      : in std_logic_vector(31 downto 0);
            douta     : out std_logic_vector(31 downto 0);
            rsta_busy : out std_logic
        );
    end component;

    -- EXTERNAL GOLDEN BRAM
    component EXT_GOLD_BRAM is
        port (
            clka      : in std_logic;
            rsta      : in std_logic;
            ena       : in std_logic;
            wea       : in std_logic_vector(0 downto 0);
            addra     : in std_logic_vector(5 downto 0);
            dina      : in std_logic_vector(31 downto 0);
            douta     : out std_logic_vector(31 downto 0);
            rsta_busy : out std_logic
        );
    end component;

    -- DEBOUNCER
    component DeBounce is
        port (
            Clock     : in std_logic;
            Reset     : in std_logic;
            button_in : in std_logic;
            pulse_out : out std_logic
        );
    end component;

begin

    -- CNN_TOP
    CNN_TOP_inst : CNN_TOP
    generic map(
        X                     => X_PKG,
        Y                     => Y_PKG,
        hw_log2_r             => hw_log2_r_PKG,
        hw_log2_EF            => hw_log2_EF_PKG,
        NUM_REGS_IFM_REG_FILE => NUM_REGS_IFM_REG_FILE_PKG,
        NUM_REGS_W_REG_FILE   => NUM_REGS_W_REG_FILE_PKG,
        ADDR_CFG              => ADDR_CFG_PKG
    )
    port map(
        p_clk          => p_clk_sys,
        p_reset        => p_reset_sys,
        p_CNN_start    => CNN_start_sys,
        p_CNN_ready    => p_CNN_ready_sys,
        p_CNN_finished => p_CNN_finished_sys_tmp,
        p_mem_ctr      => mem_ctr_tmp,
        p_en_rv        => en_cnn_tmp,
        p_we_rv        => we_cnn_tmp,
        p_addr_rv      => addr_cnn_tmp,
        p_din_rv       => data_tmp,
        p_dout_rv      => data_writeback
    );

    -- External BRAM
    EXT_BRAM_inst : blk_mem_gen_0
    port map(
        clka      => p_clk_sys,
        rsta      => p_reset_sys,
        ena       => en_ext_tmp,
        wea(0)    => we_ext_tmp,
        addra     => addra_tmp,
        dina      => data_writeback,
        douta     => data_tmp,
        rsta_busy => open
    );

    -- External GOLDEN BRAM
    EXT_GOLD_BRAM_inst : EXT_GOLD_BRAM
    port map(
        clka      => p_clk_sys,
        rsta      => p_reset_sys,
        ena       => en_gold_tmp,
        wea(0)    => '0',
        addra     => addr_gold_tmp,
        dina => (others => '0'),
        douta     => dout_gold_tmp,
        rsta_busy => open
    );

    -- EXTERNAL BRAM CONTROLLER
    EXT_BRAM_CTR_inst : EXT_BRAM_CTR
    port map(
        clk         => p_clk_sys,
        reset       => p_reset_sys,
        trigger     => trigger_sys,
        en_ext      => en_ext_tmp,
        en_cnn      => en_cnn_tmp,
        we_ext      => we_ext_tmp,
        we_cnn      => we_cnn_tmp,
        addr_ext    => addra_tmp,
        addr_cnn    => addr_cnn_tmp,
        mem_ctr     => mem_ctr_tmp,
        finish_cnn  => p_CNN_finished_sys_tmp,
        en_gold     => en_gold_tmp,
        addr_gold   => addr_gold_tmp,
        act_out     => act_out,
        act_out_ctr => act_out_ctr_tmp
    );

    -- DEBOUNCERS
    DeBounce_start_inst : DeBounce
    port map(
        Clock     => p_clk_sys,
        Reset     => p_reset_sys,
        button_in => p_CNN_start_sys,
        pulse_out => CNN_start_sys
    );

    DeBounce_trigger_inst : DeBounce
    port map(
        Clock     => p_clk_sys,
        Reset     => p_reset_sys,
        button_in => p_trigger_sys,
        pulse_out => trigger_sys
    );

    DeBounce_act_out_inst : DeBounce
    port map(
        Clock     => p_clk_sys,
        Reset     => p_reset_sys,
        button_in => p_act_out,
        pulse_out => act_out
    );

    -- PORT Assignations
    p_CNN_finished_sys <= p_CNN_finished_sys_tmp;

    data_out_tmp <= data_tmp when ((act_out_ctr_tmp = "10") or (act_out_ctr_tmp = "01")) else
        (others => '0');
    p_act <= data_out_tmp(31 downto 16) when (act_out_ctr_tmp = "01") else
        data_out_tmp(15 downto 0) when (act_out_ctr_tmp = "10") else
        (others => '0');

    act_gold_tmp <= dout_gold_tmp(31 downto 16) when (act_out_ctr_tmp = "01") else
        dout_gold_tmp(15 downto 0) when (act_out_ctr_tmp = "10") else
        (others => '0');

    act_ok_tmp <= '1' when ((act_gold_tmp = p_act) and ((act_out_ctr_tmp = "10") or (act_out_ctr_tmp = "01"))) else '0';
    p_act_ok   <= act_ok_tmp;

end architecture;