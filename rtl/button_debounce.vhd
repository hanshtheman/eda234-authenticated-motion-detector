library ieee;
use ieee.std_logic_1164.all;

entity button_debounce is
    generic (
        STABLE_CYCLES : positive := 1_000_000
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        button  : in  std_logic;
        pressed : out std_logic
    );
end entity button_debounce;

architecture rtl of button_debounce is
    signal button_meta : std_logic;
    signal button_sync : std_logic;
    signal stable      : std_logic;
    signal count       : integer range 0 to STABLE_CYCLES - 1;

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of button_meta, button_sync : signal is "TRUE";
begin
    process (clk)
    begin
        if rising_edge(clk) then
            pressed <= '0';
            if rst = '1' then
                button_meta <= '0';
                button_sync <= '0';
                stable      <= '0';
                count       <= 0;
            else
                button_meta <= button;
                button_sync <= button_meta;

                if button_sync = stable then
                    count <= 0;
                elsif count = STABLE_CYCLES - 1 then
                    stable <= button_sync;
                    count  <= 0;
                    if button_sync = '1' then
                        pressed <= '1';
                    end if;
                else
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
