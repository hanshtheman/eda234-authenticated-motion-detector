library ieee;
use ieee.std_logic_1164.all;

entity uart_button_demo is
    generic (
        CLK_FREQ_HZ    : positive := 100_000_000;
        BAUD_RATE      : positive := 9600;
        DEBOUNCE_CYCLES : positive := 1_000_000
    );
    port (
        clk_100mhz : in  std_logic;
        btn_center : in  std_logic;
        btn_left   : in  std_logic;
        btn_right  : in  std_logic;
        uart_tx    : out std_logic;
        led_busy   : out std_logic
    );
end entity uart_button_demo;

architecture rtl of uart_button_demo is
    signal reset_meta : std_logic := '1';
    signal reset_sync : std_logic := '1';
    signal send_a     : std_logic;
    signal send_b     : std_logic;

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of reset_meta, reset_sync : signal is "TRUE";
begin
    process (clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            reset_meta <= btn_center;
            reset_sync <= reset_meta;
        end if;
    end process;

    left_button : entity work.button_debounce
        generic map (STABLE_CYCLES => DEBOUNCE_CYCLES)
        port map (
            clk => clk_100mhz, rst => reset_sync,
            button => btn_left, pressed => send_a
        );

    right_button : entity work.button_debounce
        generic map (STABLE_CYCLES => DEBOUNCE_CYCLES)
        port map (
            clk => clk_100mhz, rst => reset_sync,
            button => btn_right, pressed => send_b
        );

    messages : entity work.uart_message_tx
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk => clk_100mhz, rst => reset_sync,
            send_a => send_a, send_b => send_b,
            tx => uart_tx, busy => led_busy
        );
end architecture rtl;
