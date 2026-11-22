library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_button_demo_case is
    generic (
        BAUD_RATE : positive := 9600;
        CLKS_PER_BIT : positive := 10417
    );
    port (done : out std_logic := '0');
end entity tb_uart_button_demo_case;

architecture sim of tb_uart_button_demo_case is
    constant CLK_PERIOD : time := 10 ns;
    constant MESSAGE_A : string(1 to 7) :=
        "HELLO" & character'val(13) & character'val(10);
    constant MESSAGE_B : string(1 to 7) :=
        "ALARM" & character'val(13) & character'val(10);

    signal clk : std_logic := '0';
    signal btn_center : std_logic := '1';
    signal btn_left, btn_right : std_logic := '0';
    signal serial_line, busy : std_logic;
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_valid, frame_error : std_logic;
    signal received_count : natural := 0;
    signal allowed_bytes : natural := 0;
    signal expect_alarm : boolean := false;
    signal finished : boolean := false;
begin
    clk <= not clk after CLK_PERIOD / 2 when not finished else '0';

    dut : entity work.uart_button_demo
        generic map (
            CLK_FREQ_HZ => 100_000_000, BAUD_RATE => BAUD_RATE,
            DEBOUNCE_CYCLES => 4
        )
        port map (
            clk_100mhz => clk, btn_center => btn_center,
            btn_left => btn_left, btn_right => btn_right,
            uart_tx => serial_line, led_busy => busy
        );

    decoder : entity work.uart_rx
        generic map (CLK_FREQ_HZ => 100_000_000, BAUD_RATE => BAUD_RATE)
        port map (
            clk => clk, rst => btn_center, rx => serial_line,
            rx_data => rx_data, rx_valid => rx_valid, frame_error => frame_error
        );

    monitor : process
        variable expected_character : character;
    begin
        wait until rising_edge(clk);
        wait for 2 ns;
        assert frame_error = '0' report "Unexpected UART framing error" severity failure;
        if btn_center = '0' and rx_valid = '1' then
            assert received_count < allowed_bytes
                report "Unexpected or repeated button message" severity failure;
            if expect_alarm then
                expected_character := MESSAGE_B(received_count mod 7 + 1);
            else
                expected_character := MESSAGE_A(received_count mod 7 + 1);
            end if;
            assert rx_data = std_logic_vector(to_unsigned(character'pos(expected_character), 8))
                report "Incorrect message byte at index " & integer'image(received_count)
                severity failure;
            received_count <= received_count + 1;
        end if;
    end process;

    stimulus : process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 3 ns;
        end procedure;

        procedure clocks(count : positive) is
        begin
            for cycle in 1 to count loop
                tick;
            end loop;
        end procedure;

        procedure wait_started is
        begin
            for cycle in 1 to 50 loop
                exit when busy = '1';
                tick;
            end loop;
            assert busy = '1' report "Button did not start a message" severity failure;
        end procedure;

        procedure wait_completed(expected_count : natural) is
        begin
            for cycle in 1 to 80 * CLKS_PER_BIT loop
                exit when busy = '0';
                tick;
            end loop;
            assert busy = '0' report "Message did not finish" severity failure;
            assert received_count = expected_count
                report "Missing message bytes" severity failure;
        end procedure;
    begin
        clocks(10);
        btn_center <= '0';
        clocks(20);
        assert busy = '0' and serial_line = '1'
            report "Demo did not reset to idle" severity failure;

        -- Short bounces must not start a message.
        allowed_bytes <= 7;
        for bounce in 1 to 3 loop
            btn_left <= '1';
            tick;
            btn_left <= '0';
            tick;
        end loop;
        clocks(10);
        assert busy = '0' and received_count = 0
            report "Button bounce started a message" severity failure;

        -- Hold the left button and try the right button while already busy.
        btn_left <= '1';
        wait_started;
        btn_right <= '1';
        clocks(20);
        btn_right <= '0';
        clocks(20);
        wait_completed(7);
        clocks(80 * CLKS_PER_BIT);
        assert busy = '0' and received_count = 7
            report "Held button repeated, or busy request was queued" severity failure;
        btn_left <= '0';
        clocks(20);
        report "PASS button demo baud " & integer'image(BAUD_RATE)
            & ": HELLO, debounce, hold and ignored busy request" severity note;

        expect_alarm <= true;
        allowed_bytes <= 14;
        btn_right <= '1';
        wait_started;
        clocks(20);
        btn_right <= '0';
        wait_completed(14);
        clocks(20);
        report "PASS button demo baud " & integer'image(BAUD_RATE)
            & ": ALARM message" severity note;

        -- Simultaneous requests have a documented left-button priority.
        expect_alarm <= false;
        allowed_bytes <= 21;
        btn_left <= '1';
        btn_right <= '1';
        wait_started;
        clocks(20);
        btn_left <= '0';
        btn_right <= '0';
        wait_completed(21);
        clocks(80 * CLKS_PER_BIT);
        assert busy = '0' and received_count = 21
            report "Unexpected message after simultaneous buttons" severity failure;

        report "CASE PASSED: button demo baud " & integer'image(BAUD_RATE)
            & ", received 21 correct bytes" severity note;
        done <= '1';
        finished <= true;
        wait;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_button_demo is
end entity tb_uart_button_demo;

architecture sim of tb_uart_button_demo is
    signal done_9600, done_115200 : std_logic := '0';
begin
    suite_9600 : entity work.tb_uart_button_demo_case
        generic map (BAUD_RATE => 9600, CLKS_PER_BIT => 10417)
        port map (done => done_9600);
    suite_115200 : entity work.tb_uart_button_demo_case
        generic map (BAUD_RATE => 115200, CLKS_PER_BIT => 868)
        port map (done => done_115200);

    completion : process
    begin
        wait until done_9600 = '1' and done_115200 = '1';
        report "ALL TESTS PASSED: two-button UART message demo" severity note;
        stop;
        wait;
    end process;

    watchdog : process
    begin
        wait for 50 ms;
        assert false report "Button demo test timeout" severity failure;
        stop;
        wait;
    end process;
end architecture sim;
