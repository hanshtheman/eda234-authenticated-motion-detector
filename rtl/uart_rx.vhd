library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
    generic (
        CLK_FREQ_HZ : positive := 100_000_000;
        BAUD_RATE   : positive := 9600
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        rx          : in  std_logic;

        rx_data     : out std_logic_vector(7 downto 0);
        rx_valid    : out std_logic;
        frame_error : out std_logic
    );
end entity uart_rx;

architecture rtl of uart_rx is
    signal rx_meta : std_logic;
    signal rx_sync : std_logic;
begin

    input_sync : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_meta <= '1';
                rx_sync <= '1';
            else
                rx_meta <= rx;
                rx_sync <= rx_meta;
            end if;
        end if;
    end process;

    -- Placeholder outputs until the receive logic is implemented.
    rx_data     <= (others => '0');
    rx_valid    <= '0';
    frame_error <= '0';

end architecture rtl;