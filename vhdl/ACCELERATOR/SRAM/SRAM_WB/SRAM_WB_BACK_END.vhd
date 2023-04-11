library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity SRAM_WB_BACK_END is
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
        D   : out std_logic_vector ((MEM_WORDLENGTH - 1) downto 0);
        Q   : in std_logic_vector ((MEM_WORDLENGTH - 1) downto 0);
        WEN : out std_logic
    );
end SRAM_WB_BACK_END;

architecture behavioral of SRAM_WB_BACK_END is

    -- Enumeration type for the states and state_type signals
    type state_type is (s_init, s_idle, s_read_b, s_read_w, s_read_cfg);
    signal state_next, state_reg : state_type;

    ------------ CONTROL PATH SIGNALS ------------
    -------- INPUTS --------
    ---- Internal Status Signals from the Data Path
    -- ..

    ---- External Command Signals to the FSMD
    signal en_w_read_reg   : std_logic;
    signal en_w_read_tmp   : std_logic;
    signal en_b_read_tmp   : std_logic;
    signal en_cfg_read_tmp : std_logic;

    -------- OUTPUTS --------
    ---- Internal Control Signals used to control Data Path Operation
    -- ..

    ---- External Status Signals to indicate status of the FSMD
    -- ..

    ------------ DATA PATH SIGNALS ------------
    ---- Data Registers Signals
    -- signal addr_w_ctrl_reg, addr_w_ctrl_next     : natural range 0 to 3;
    signal addr_w_ctrl_reg, addr_w_ctrl_next     : natural range 0 to 2;
    signal addr_w_reg, addr_w_next               : unsigned (WB_ADDRESSES - 1 downto 0);
    signal addr_b_ctrl_reg, addr_b_ctrl_next     : std_logic;
    signal addr_b_reg, addr_b_next               : unsigned (WB_ADDRESSES - 1 downto 0);
    signal NoC_pm_next, NoC_pm_reg               : natural;
    signal addr_cfg_ctrl_reg, addr_cfg_ctrl_next : natural range 0 to 3;
    signal addr_cfg_reg, addr_cfg_next           : unsigned (WB_ADDRESSES - 1 downto 0);

    ---- External Control Signals used to control Data Path Operation (they do NOT modify next state outcome)
    -- ..

    ---- Functional Units Intermediate Signals
    signal addr_w_out   : unsigned (WB_ADDRESSES - 1 downto 0);
    signal addr_b_out   : unsigned (WB_ADDRESSES - 1 downto 0);
    signal addr_cfg_out : unsigned (WB_ADDRESSES - 1 downto 0);

    ---- Data Outputs
    signal A_tmp      : std_logic_vector(WB_ADDRESSES - 1 downto 0);
    signal CSN_tmp    : std_logic;
    signal D_tmp      : std_logic_vector ((MEM_WORDLENGTH - 1) downto 0);
    signal WEN_tmp    : std_logic;
    signal wb_FE_tmp  : std_logic_vector (BIAS_BITWIDTH - 1 downto 0);
    signal cfg_FE_tmp : std_logic_vector ((HYP_BITWIDTH - 1) downto 0);

    -- SRAM_WB_BACK_END Intermediate Signals
    signal weight_tmp : std_logic_vector (BIAS_BITWIDTH - 1 downto 0); -- MSBs zeroes disregarded in front-end read interface
    signal zeroes     : std_logic_vector ((MEM_WORDLENGTH - 1) - BIAS_BITWIDTH - WEIGHT_BITWIDTH downto 0);
    signal Q_w_tmp    : std_logic_vector ((MEM_WORDLENGTH - 1) downto 0);
    signal Q_b_tmp    : std_logic_vector ((MEM_WORDLENGTH - 1) downto 0);
    signal Q_cfg_tmp  : std_logic_vector ((MEM_WORDLENGTH - 1) downto 0);
    signal bias_tmp   : std_logic_vector (BIAS_BITWIDTH - 1 downto 0);

begin

    ------------ CONTROL PATH ------------
    -- Control Path : State Register
    asmd_reg : process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state_reg <= s_init;
            else
                state_reg <= state_next;
            end if;
        end if;
    end process;

    -- Control Path : Next State Logic
    asmd_ctrl : process (state_reg, en_w_read_tmp, en_b_read_tmp, en_cfg_read_tmp)
    begin
        case state_reg is
            when s_init =>
                state_next <= s_idle;
            when s_idle =>
                if (en_w_read_tmp = '1') then
                    state_next <= s_read_w;
                else
                    if (en_b_read_tmp = '1') then
                        state_next <= s_read_b;
                    else
                        if (en_cfg_read_tmp = '1') then
                            state_next <= s_read_cfg;
                        else
                            state_next <= s_idle;
                        end if;
                    end if;
                end if;
            when s_read_w =>
                if (en_w_read_tmp = '1') then
                    state_next <= s_read_w;
                else
                    state_next <= s_idle;
                end if;
            when s_read_b =>
                if (en_b_read_tmp = '1') then
                    state_next <= s_read_b;
                else
                    state_next <= s_idle;
                end if;
            when s_read_cfg =>
                if (en_cfg_read_tmp = '1') then
                    state_next <= s_read_cfg;
                else
                    state_next <= s_idle;
                end if;
            when others =>
                state_next <= s_init;
        end case;
    end process;

    -- Control Path : Input Logic
    -- ..

    -- Control Path : Output Logic

    --------------------------------------

    ------------- DATA PATH --------------
    -- Data Path : Data Registers
    data_reg : process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                en_w_read_reg   <= '0';
                addr_w_ctrl_reg <= 0;
                addr_w_reg      <= (others => '0');

                addr_b_ctrl_reg <= '0';
                addr_b_reg      <= to_unsigned((ADDR_CFG_PKG - 1), WB_ADDRESSES);

                addr_cfg_ctrl_reg <= 0;
                addr_cfg_reg      <= to_unsigned((ADDR_CFG_PKG), WB_ADDRESSES);

            else
                en_w_read_reg   <= en_w_read_tmp;
                addr_w_ctrl_reg <= addr_w_ctrl_next;
                addr_w_reg      <= addr_w_next;

                addr_b_ctrl_reg <= addr_b_ctrl_next;
                addr_b_reg      <= addr_b_next;

                addr_cfg_ctrl_reg <= addr_cfg_ctrl_next;
                addr_cfg_reg      <= addr_cfg_next;

            end if;
        end if;
    end process;

    -- data path : functional units (perform necessary arithmetic operations)
    -- addr_w_out <= (addr_w_reg + 1) when (addr_w_ctrl_reg = 3) else addr_w_reg;
    addr_w_out <= (addr_w_reg + 1) when (addr_w_ctrl_reg = 2) else addr_w_reg;

    -- Bias addresses start at the last memory position (before reserved space), and decreases as pm increases from 0 to M - 1.
    -- Address decreases with changes in NoC_pm value.
    pm_reg : process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                NoC_pm_reg <= 0;
            else
                NoC_pm_reg <= NoC_pm_next;
            end if;
        end if;
    end process;

    addr_b_out <= (addr_b_reg - 1) when (addr_b_ctrl_reg = '1') and ((NoC_pm_next /= NoC_pm_reg) and (en_b_read_tmp = '1')) else addr_b_reg;

    addr_cfg_out <= (addr_cfg_reg + 1) when (addr_cfg_ctrl_reg = 3) else addr_cfg_reg;

    -- data path : status (inputs to control path to modify next state logic)
    -- ..

    -- data path : Output Logic
    A_tmp <= std_logic_vector(addr_b_next)   when (state_reg = s_read_b) else  -- biases
             std_logic_vector(addr_cfg_next) when (en_cfg_read_tmp = '1') else -- cfg
             std_logic_vector(addr_w_next);                                    -- weights

    CSN_tmp <= not(en_b_read_tmp)   when (state_reg = s_read_b) else  -- biases
               not(en_cfg_read_tmp) when (en_cfg_read_tmp = '1') else -- cfg
               not(en_w_read_tmp);                                    -- weights

    WEN_tmp <= '1'; --tbd when write, by the moment, always to 1

    zeroes                                 <= (others => '0');
    -- with addr_w_ctrl_reg select weight_tmp <=
    --    Q_w_tmp((WEIGHT_BITWIDTH * 4 - 1) downto (WEIGHT_BITWIDTH * 3)) & zeroes when 0,
    --    Q_w_tmp((WEIGHT_BITWIDTH * 3 - 1) downto (WEIGHT_BITWIDTH * 2)) & zeroes when 1,
    --    Q_w_tmp((WEIGHT_BITWIDTH * 2 - 1) downto (WEIGHT_BITWIDTH)) & zeroes when 2,
    --    Q_w_tmp((WEIGHT_BITWIDTH - 1) downto 0) & zeroes when 3,
    --    (others => '0') when others;

    with addr_w_ctrl_reg select weight_tmp <=
        Q_w_tmp((WEIGHT_BITWIDTH * 3 - 1) downto (WEIGHT_BITWIDTH * 2)) & zeroes when 0,
        Q_w_tmp((WEIGHT_BITWIDTH * 2 - 1) downto (WEIGHT_BITWIDTH * 1)) & zeroes when 1,
        Q_w_tmp((WEIGHT_BITWIDTH * 1 - 1) downto (0)) & zeroes when 2,
        (others => '0') when others;

    Q_w_tmp <= Q when (state_reg = s_read_w) else
        (others => '0');
    Q_b_tmp <= Q when (state_reg = s_read_b) else
        (others => '0');
    Q_cfg_tmp <= Q when (state_reg = s_read_cfg) else
        (others => '0');

    with addr_b_ctrl_reg select bias_tmp <=
        Q_b_tmp((BIAS_BITWIDTH * 2 - 1) downto BIAS_BITWIDTH) when '0',
        Q_b_tmp((BIAS_BITWIDTH - 1) downto 0) when '1',
        (others => '0') when others;

    with addr_cfg_ctrl_reg select cfg_FE_tmp <=
        Q_cfg_tmp((HYP_BITWIDTH * 4 - 1) downto (HYP_BITWIDTH * 3)) when 0,
        Q_cfg_tmp((HYP_BITWIDTH * 3 - 1) downto (HYP_BITWIDTH * 2)) when 1,
        Q_cfg_tmp((HYP_BITWIDTH * 2 - 1) downto (HYP_BITWIDTH)) when 2,
        Q_cfg_tmp((HYP_BITWIDTH - 1) downto 0) when 3,
        (others => '0') when others;

    wb_FE_tmp <= weight_tmp when (state_reg = s_read_w) else
        bias_tmp when (state_reg = s_read_b) else
        (others => '0');
    -- data path : mux routing
    data_mux : process (state_reg, addr_w_ctrl_reg, addr_w_reg, addr_b_reg, addr_w_out, addr_b_out, addr_b_ctrl_reg, NoC_pm_reg, NoC_pm_next, en_b_read_tmp, addr_cfg_ctrl_reg, addr_cfg_reg, addr_cfg_out, en_w_read_reg, en_w_read_tmp)
    begin
        case state_reg is
            when s_init =>
                addr_w_ctrl_next <= addr_w_ctrl_reg;
                addr_w_next      <= addr_w_reg;

                addr_b_ctrl_next <= addr_b_ctrl_reg;
                addr_b_next      <= addr_b_reg;

                addr_cfg_ctrl_next <= addr_cfg_ctrl_reg;
                addr_cfg_next      <= addr_cfg_reg;

            when s_idle =>
                addr_w_ctrl_next <= addr_w_ctrl_reg;
                addr_w_next      <= addr_w_reg;

                addr_b_ctrl_next <= addr_b_ctrl_reg;
                addr_b_next      <= addr_b_reg;

                addr_cfg_ctrl_next <= addr_cfg_ctrl_reg;
                addr_cfg_next      <= addr_cfg_reg;

            when s_read_w =>
                if ((en_w_read_reg and en_w_read_tmp) = '1') then
                    if (addr_w_ctrl_reg = 2) then
                        addr_w_ctrl_next <= 0;
                    else
                        addr_w_ctrl_next <= addr_w_ctrl_reg + 1;
                    end if;
                else
                    addr_w_ctrl_next <= addr_w_ctrl_reg;
                end if;

                addr_w_next <= addr_w_out;

                addr_b_ctrl_next <= addr_b_ctrl_reg;
                addr_b_next      <= addr_b_reg;

                addr_cfg_ctrl_next <= addr_cfg_ctrl_reg;
                addr_cfg_next      <= addr_cfg_reg;

            when s_read_b =>
                addr_w_ctrl_next <= addr_w_ctrl_reg;
                addr_w_next      <= addr_w_reg;

                if ((NoC_pm_next /= NoC_pm_reg) and (en_b_read_tmp = '1')) then
                    addr_b_ctrl_next <= not(addr_b_ctrl_reg);
                else
                    addr_b_ctrl_next <= addr_b_ctrl_reg;
                end if;
                addr_b_next <= addr_b_out;

                addr_cfg_ctrl_next <= addr_cfg_ctrl_reg;
                addr_cfg_next      <= addr_cfg_reg;

            when s_read_cfg =>
                addr_w_ctrl_next <= addr_w_ctrl_reg;
                addr_w_next      <= addr_w_reg;

                addr_b_ctrl_next <= addr_b_ctrl_reg;
                addr_b_next      <= addr_b_reg;

                if (addr_cfg_ctrl_reg = 3) then
                    addr_cfg_ctrl_next <= 0;
                else
                    addr_cfg_ctrl_next <= addr_cfg_ctrl_reg + 1;
                end if;
                addr_cfg_next <= addr_cfg_out;

            when others =>
                addr_w_ctrl_next <= addr_w_ctrl_reg;
                addr_w_next      <= addr_w_reg;

                addr_b_ctrl_next <= addr_b_ctrl_reg;
                addr_b_next      <= addr_b_reg;

                addr_cfg_ctrl_next <= addr_cfg_ctrl_reg;
                addr_cfg_next      <= addr_cfg_reg;

        end case;
    end process;
    --------------------------------------

    -- PORT Assignations
    en_w_read_tmp   <= en_w_read;
    en_b_read_tmp   <= en_b_read;
    en_cfg_read_tmp <= en_cfg_read;
    NoC_pm_next     <= to_integer(unsigned(NoC_pm_FE));
    wb_FE           <= wb_FE_tmp;
    cfg_FE          <= cfg_FE_tmp;

    A   <= A_tmp;
    CSN <= CSN_tmp;
    D   <= D_tmp;
    WEN <= WEN_tmp;

end architecture;