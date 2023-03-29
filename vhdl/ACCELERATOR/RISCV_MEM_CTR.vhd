library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.thesis_pkg.all;

entity RISCV_MEM_CTR is
    port (
        -- To/From RISC-V
        mem_ctr : in std_logic_vector (1 downto 0);
        en_rv   : in std_logic;
        we_rv   : in std_logic_vector(0 downto 0);
        addr_rv : in std_logic_vector(EXT_ADDRESSES - 1 downto 0);
        din_rv  : in std_logic_vector(EXT_WORDLENGTH - 1 downto 0);
        dout_rv : out std_logic_vector(EXT_WORDLENGTH - 1 downto 0);
        -- To/From WB_BRAM
        mem_ctr_wb : out std_logic;
        ena_wb     : out std_logic;
        wea_wb     : out std_logic_vector(0 downto 0);
        addra_wb   : out std_logic_vector(WB_ADDRESSES - 1 downto 0);
        dina_wb    : out std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
        douta_wb   : in std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
        -- To/From IFM_BRAM
        mem_ctr_ifm : out std_logic;
        ena_ifm     : out std_logic;
        wea_ifm     : out std_logic_vector(0 downto 0);
        addra_ifm   : out std_logic_vector(ACT_ADDRESSES - 1 downto 0);
        dina_ifm    : out std_logic_vector(MEM_WORDLENGTH - 1 downto 0);
        douta_ifm   : in std_logic_vector(MEM_WORDLENGTH - 1 downto 0)
    );
end RISCV_MEM_CTR;

architecture structural of RISCV_MEM_CTR is

begin

    -- dout
    with mem_ctr select dout_rv <=
	    douta_wb when "01",
	    douta_ifm when "10",
        (others => '0') when others;

    -- ena
    with mem_ctr select ena_wb <=
        en_rv when "01",
        '0' when others;

    with mem_ctr select ena_ifm <=
        en_rv when "10",
        '0' when others;

    -- wea
    with mem_ctr select wea_wb <=
        we_rv when "01",
        (others => '0') when others;

    with mem_ctr select wea_ifm <=
        we_rv when "10",
        (others => '0') when others;

    -- addr
    -- WB_ADDRESSES > ACT_ADDRESSES
    gen_addr_1 : if (WB_ADDRESSES > ACT_ADDRESSES) generate
        with mem_ctr select addra_wb <=
        addr_rv when "01",
        (others => '0') when others;

        with mem_ctr select addra_ifm <=
            addr_rv (ACT_ADDRESSES - 1 downto 0) when "10",
            (others => '0') when others;
    end generate;

    -- WB_ADDRESSES < ACT_ADDRESSES
    gen_addr_2 : if (WB_ADDRESSES < ACT_ADDRESSES) generate
        with mem_ctr select addra_wb <=
            addr_rv (WB_ADDRESSES - 1 downto 0) when "01",
            (others => '0') when others;

        with mem_ctr select addra_ifm <=
            addr_rv when "10",
           (others => '0') when others;
    end generate;

    -- WB_ADDRESSES = ACT_ADDRESSES
    gen_addr_3 : if (WB_ADDRESSES = ACT_ADDRESSES) generate
        with mem_ctr select addra_wb <=
            addr_rv when "01",
            (others => '0') when others;

        with mem_ctr select addra_ifm <=
            addr_rv when "10",
            (others => '0') when others;
    end generate;
    
    -- din
    with mem_ctr select dina_wb <=
        din_rv when "01",
        (others => '0') when others;

    with mem_ctr select dina_ifm <=
        din_rv when "10",
        (others => '0') when others;

    -- mem_ctr
    mem_ctr_wb  <= mem_ctr(0);
    mem_ctr_ifm <= mem_ctr(1);
        
end architecture;