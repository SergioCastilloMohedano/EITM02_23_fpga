library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity EXT_BRAM_CTR is
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
        act_out_ctr : out std_logic_vector (1 downto 0) -- controls which act within same address to output
    );
end entity;

architecture behavioral of EXT_BRAM_CTR is

    signal mem_ctr_reg, mem_ctr_next : std_logic_vector (1 downto 0);
    signal mem_ctr_reg_2             : std_logic_vector (1 downto 0);
    signal addr_ifm_reg_2, addr_ifm_reg, addr_ifm_next : unsigned (EXT_ADDRESSES - 1 downto 0);
    signal addr_wb_reg_2, addr_wb_reg, addr_wb_next    : unsigned (EXT_ADDRESSES - 1 downto 0);
    signal en_cnn_reg, en_cnn_next                     : std_logic;
    signal en_cnn_reg_2                                : std_logic;
    signal we_cnn_reg, we_cnn_next                     : std_logic;

    signal addr_ext_reg, addr_ext_next            : unsigned (EXT_ADDRESSES - 1 downto 0);
    signal addr_ext_reg_1, addr_ext_reg_2         : unsigned (EXT_ADDRESSES - 1 downto 0);
    signal en_ext_tmp, en_ext_reg_1, en_ext_reg_2 : std_logic;
    signal we_ext_tmp, we_ext_reg_1, we_ext_reg_2 : std_logic;

    signal en_gold_tmp                   : std_logic;
    signal addr_gold_reg, addr_gold_next : unsigned (ACT_ADDRESSES - 1 downto 0);

    signal act_out_ctr_reg : std_logic_vector (1 downto 0);
    signal act_out_ctr_next : std_logic_vector (1 downto 0) := "00";

    -- Enumeration type for the states and state_type signals
    type state_type is (s_init, s_idle, s_loading, s_finished, s_writeback, s_comparing);
    signal state_next, state_reg : state_type;

begin
    -- control path : state register
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

    -- control path : next state logic
    asmd_ctrl : process (state_reg, trigger, addr_ext_reg, addr_ext_reg_2, finish_cnn, addr_gold_reg, act_out, act_out_ctr_reg)
    begin
        case state_reg is
            when s_init =>
                state_next <= s_idle;
            when s_idle =>
                if (trigger = '1') then
                    state_next <= s_loading;
                elsif (finish_cnn = '1') then
                    state_next <= s_writeback;
                elsif (act_out = '1') then
                    state_next <= s_comparing;
                else
                    state_next <= s_idle;
                end if;

            when s_loading =>
                if (addr_ext_reg = (WB_NUM_WORDS + 32 - 1)) then -- no of weights + no of activations OF INPUT IMAGE (1*8*8)
                    state_next <= s_finished;
                else
                    state_next <= s_loading;
                end if;

            when s_writeback =>
                if (addr_ext_reg_2 = (ACT_NUM_WORDS - 1)) then -- reg_2 cos of read latency of cnn bram
                    state_next <= s_finished;
                else
                    state_next <= s_writeback;
                end if;
                
            when s_comparing =>
                if ((addr_ext_reg = (ACT_NUM_WORDS - 1)) and (act_out_ctr_reg = "01")) then
                    state_next <= s_finished;
                else
                    state_next <= s_idle;
                end if;

            when s_finished =>
                state_next <= s_idle;

            when others =>
                state_next <= s_init;

        end case;
    end process;
    data_reg : process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                addr_ifm_reg   <= (others => '0');
                addr_ifm_reg_2 <= (others => '0');
                addr_wb_reg    <= (others => '0');
                addr_wb_reg_2  <= (others => '0');
                addr_ext_reg   <= (others => '0');
                addr_ext_reg_1 <= (others => '0');
                addr_ext_reg_2 <= (others => '0');

                en_ext_reg_1 <= '0';
                en_ext_reg_2 <= '0';
                we_ext_reg_1 <= '0';
                we_ext_reg_2 <= '0';

                en_cnn_reg    <= '0';
                en_cnn_reg_2  <= '0';
                we_cnn_reg    <= '0';
                mem_ctr_reg   <= "00";
                mem_ctr_reg_2 <= "00";

                addr_gold_reg <= (others => '0');

                act_out_ctr_reg <= "00";

            else
                addr_ifm_reg   <= addr_ifm_next;
                addr_ifm_reg_2 <= addr_ifm_reg;
                addr_wb_reg    <= addr_wb_next;
                addr_wb_reg_2  <= addr_wb_reg;
                addr_ext_reg   <= addr_ext_next;
                addr_ext_reg_1 <= addr_ext_reg;
                addr_ext_reg_2 <= addr_ext_reg_1;

                en_ext_reg_1 <= en_ext_tmp;
                en_ext_reg_2 <= en_ext_reg_1;
                we_ext_reg_1 <= we_ext_tmp;
                we_ext_reg_2 <= we_ext_reg_1;

                en_cnn_reg    <= en_cnn_next;
                en_cnn_reg_2  <= en_cnn_reg;
                we_cnn_reg    <= we_cnn_next;
                mem_ctr_reg   <= mem_ctr_next;
                mem_ctr_reg_2 <= mem_ctr_reg;

                addr_gold_reg <= addr_gold_next;

                act_out_ctr_reg <= act_out_ctr_next;

            end if;
        end if;
    end process;

    -- data path : functional units (perform necessary arithmetic operations)

    -- data path : status (inputs to control path to modify next state logic)

    -- data path : mux routing
    data_mux : process (state_reg, addr_ext_reg, addr_wb_reg, addr_ifm_reg, addr_gold_reg, act_out_ctr_reg, act_out)
    begin
        case state_reg is
            when s_init =>
                en_ext_tmp    <= '0';
                en_cnn_next   <= '0';
                we_ext_tmp    <= '0';
                we_cnn_next   <= '0';
                mem_ctr_next  <= "00";
                addr_ext_next <= (others => '0');
                addr_wb_next  <= (others => '0');
                addr_ifm_next <= (others => '0');

                addr_gold_next <= (others => '0');
                en_gold_tmp    <= '0';

                act_out_ctr_next <= "00";

            when s_idle =>
                -- en_ext_tmp    <= '0';
                we_ext_tmp    <= '0';
                -- addr_ext_next <= addr_ext_reg;
                
                en_cnn_next   <= '0';
                we_cnn_next   <= '0';
                mem_ctr_next  <= "00";
                addr_wb_next  <= (others => '0');
                addr_ifm_next <= (others => '0');

                -- en_gold_tmp    <= '0';
                -- addr_gold_next <= addr_gold_reg;
                if ((act_out_ctr_reg = "10") and (act_out = '1')) then
                    addr_gold_next <= addr_gold_reg + 1;
                    addr_ext_next <= addr_ext_reg + 1;
                else
                    addr_gold_next <= addr_gold_reg;
                    addr_ext_next <= addr_ext_reg;
                end if;
                
                if ((act_out_ctr_reg /= "00") and (act_out = '1')) then
                    en_ext_tmp <= '1';
                    en_gold_tmp <= '1';
                else
                    en_ext_tmp <= '0';
                    en_gold_tmp <= '0';
                end if;

                act_out_ctr_next <= act_out_ctr_reg;

            when s_loading =>
                en_ext_tmp  <= '1';
                en_cnn_next <= '1';
                we_ext_tmp  <= '0';
                we_cnn_next <= '1';

                addr_ext_next <= addr_ext_reg + 1;

                if (addr_ext_reg <= WB_NUM_WORDS - 1) then
                    mem_ctr_next     <= "01";
                    addr_wb_next     <= addr_wb_reg + 1;
                    addr_ifm_next    <= addr_ifm_reg;
                elsif (addr_ext_reg > WB_NUM_WORDS - 1) then
                    mem_ctr_next  <= "10";
                    addr_wb_next  <= addr_wb_reg;
                    addr_ifm_next <= addr_ifm_reg + 1;
                else
                    mem_ctr_next  <= "00";
                    addr_wb_next  <= addr_wb_reg;
                    addr_ifm_next <= addr_ifm_reg;
                end if;

                addr_gold_next <= (others => '0');
                en_gold_tmp    <= '0';

                act_out_ctr_next <= "00";

            when s_writeback =>
                en_ext_tmp <= '1';
                we_ext_tmp <= '1';
                addr_ext_next <= addr_ext_reg + 1;

                mem_ctr_next <= "10";
                en_cnn_next <= '1';
                we_cnn_next <= '0';
                addr_wb_next <= addr_wb_reg;
                addr_ifm_next <= addr_ifm_reg + 1;

                en_gold_tmp <= '0';
                addr_gold_next <= (others => '0');

                act_out_ctr_next <= "00";

            when s_comparing =>
                en_ext_tmp    <= '1';
                we_ext_tmp    <= '0';
                addr_ext_next <= addr_ext_reg;
                -- if (act_out_ctr_reg = "10") then
                --     addr_ext_next <= addr_ext_reg + 1;
                -- else
                --     addr_ext_next <= addr_ext_reg;
                -- end if;

                en_cnn_next   <= '0';
                we_cnn_next   <= '0';
                mem_ctr_next  <= "00";
                addr_wb_next  <= (others => '0');
                addr_ifm_next <= (others => '0');

                en_gold_tmp    <= '1';
                addr_gold_next <= addr_gold_reg;
                -- if (act_out_ctr_reg = "10") then
                --     addr_gold_next <= addr_gold_reg + 1;
                -- else
                --     addr_gold_next <= addr_gold_reg;
                -- end if;

                if (act_out_ctr_reg = "01") then
                    act_out_ctr_next <= "10";
                else
                    act_out_ctr_next <= "01";
                end if;

            when s_finished =>
                en_ext_tmp    <= '0';
                en_cnn_next   <= '0';
                we_ext_tmp    <= '0';
                we_cnn_next   <= '0';
                mem_ctr_next  <= "00";
                addr_ext_next <= (others => '0');
                addr_wb_next  <= (others => '0');
                addr_ifm_next <= (others => '0');

                addr_gold_next <= (others => '0');
                en_gold_tmp    <= '0';

                act_out_ctr_next <= "00";

            when others =>
                en_ext_tmp    <= '0';
                en_cnn_next   <= '0';
                we_ext_tmp    <= '0';
                we_cnn_next   <= '0';
                mem_ctr_next  <= "00";
                addr_ext_next <= (others => '0');
                addr_wb_next  <= (others => '0');
                addr_ifm_next <= (others => '0');

                addr_gold_next <= (others => '0');
                en_gold_tmp    <= '0';

                act_out_ctr_next <= "00";

        end case;
    end process;

    -- PORT ASSIGNATIONS
    -- EXT BRAM
    with state_reg select en_ext <=
        en_ext_reg_2 when s_writeback,
        en_ext_tmp   when others; -- when writeback, 2cc delay for synchronizing with CNN BRAM

    with state_reg select we_ext <=
        we_ext_reg_2 when s_writeback,
        we_ext_tmp   when others; -- when writeback, 2cc delay for synchronizing with CNN BRAM

    with state_reg select addr_ext <=
        std_logic_vector(addr_ext_reg_2) when s_writeback,
        std_logic_vector(addr_ext_reg)   when others; -- when writeback, 2cc delay for synchronizing with CNN BRAM

    -- GOLD BRAM
    en_gold   <= en_gold_tmp;
    addr_gold <= std_logic_vector(addr_gold_reg);

    -- CNN BRAM
    with state_reg select mem_ctr <=
        mem_ctr_reg                    when s_loading,
        (mem_ctr_reg or mem_ctr_reg_2) when others; -- when reading from internal memories we need an extra cc.

    with mem_ctr_reg select addr_cnn <=
        std_logic_vector(addr_wb_reg_2) when "01",
        std_logic_vector(addr_ifm_reg_2) when "10",
        (others => '0') when others;

    with state_reg select en_cnn <=
        en_cnn_reg when s_loading,
        (en_cnn_reg or en_cnn_reg_2) when others; -- when reading from internal memories we need an extra cc.

    we_cnn <= we_cnn_reg;

    act_out_ctr <= act_out_ctr_reg;

end architecture;