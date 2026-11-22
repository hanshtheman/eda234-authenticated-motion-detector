library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_loopback_case is
    generic (
        BAUD_RATE             : positive := 9600;
        EXPECTED_CLKS_PER_BIT : positive := 10417
    );
    port (
        done : out std_logic := '0'
    );
end entity tb_uart_loopback_case;

architecture sim of tb_uart_loopback_case is
    constant CLK_PERIOD : time := 10 ns;
    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
    constant PATTERNS : byte_array_t := (
        x"00", x"FF", x"55", x"AA", x"53", x"80", x"01", x"7F"
    );

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal tx_start     : std_logic := '0';
    signal tx_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_busy      : std_logic;
    signal serial_line  : std_logic;
    signal rx_data      : std_logic_vector(7 downto 0);
    signal rx_valid     : std_logic;
    signal frame_error  : std_logic;
    signal expected_data : std_logic_vector(7 downto 0) := (others => '0');
    signal sent_count   : natural := 0;
    signal received_count : natural := 0;
    signal finished     : boolean := false;
begin
    clk <= not clk after CLK_PERIOD / 2 when not finished else '0';

    tx_dut : entity work.uart_tx
        generic map (
            CLK_FREQ_HZ => 100_000_000,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk      => clk,
            rst      => rst,
            tx_start => tx_start,
            tx_data  => tx_data,
            tx       => serial_line,
            tx_busy  => tx_busy
        );

    rx_dut : entity work.uart_rx
        generic map (
            CLK_FREQ_HZ => 100_000_000,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk         => clk,
            rst         => rst,
            rx          => serial_line,
            rx_data     => rx_data,
            rx_valid    => rx_valid,
            frame_error => frame_error
        );

    monitor : process
        variable previous_valid : std_logic := '0';
        variable previous_data  : std_logic_vector(7 downto 0) := (others => '0');

        procedure check(condition : boolean; message_text : string) is
        begin
            assert condition
                report "Loopback baud " & integer'image(BAUD_RATE) & ": " & message_text
                severity failure;
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;

        check(frame_error = '0', "unexpected framing error");
        if rst = '1' then
            check(serial_line = '1' and tx_busy = '0', "TX reset failed");
            check(rx_valid = '0' and rx_data = x"00", "RX reset failed");
            previous_valid := '0';
            previous_data  := (others => '0');
        else
            check(rx_valid = '0' or rx_valid = '1', "unknown rx_valid");
            check(not (rx_valid = '1' and previous_valid = '1'),
                "rx_valid lasted more than one clock");

            if rx_valid = '1' then
                check(received_count < sent_count, "duplicate or unsolicited byte");
                check(rx_data = expected_data,
                    "byte mismatch at index " & integer'image(received_count));
                -- RX samples the stop-bit centre before TX finishes the stop bit.
                check(tx_busy = '1', "RX result arrived after TX had finished");
                received_count <= received_count + 1;
            else
                check(rx_data = previous_data, "rx_data changed without rx_valid");
            end if;

            previous_valid := rx_valid;
            previous_data  := rx_data;
        end if;
    end process;

    stimulus : process
        variable walking_bit    : std_logic_vector(7 downto 0);
        variable last_frame_end : time := 0 ns;

        procedure check(condition : boolean; message_text : string) is
        begin
            assert condition
                report "Loopback baud " & integer'image(BAUD_RATE) & ": " & message_text
                severity failure;
        end procedure;

        procedure tick is
        begin
            wait until rising_edge(clk);
            -- Read after the monitor has sampled and updated its event count.
            wait for 2 ns;
        end procedure;

        procedure expect_idle(cycles : positive) is
            variable count_before : natural;
        begin
            count_before := received_count;
            for cycle in 1 to cycles loop
                tick;
                check(serial_line = '1' and tx_busy = '0', "TX did not stay idle");
                check(rx_valid = '0' and received_count = count_before,
                    "extra receive event during idle");
            end loop;
        end procedure;

        procedure send_and_check(
            data      : std_logic_vector(7 downto 0);
            tight_gap : boolean := false
        ) is
            variable count_before : natural;
        begin
            check(tx_busy = '0' and serial_line = '1', "TX not ready");
            check(received_count = sent_count, "previous byte is missing");
            count_before := received_count;

            wait until falling_edge(clk);
            expected_data <= data;
            tx_data       <= data;
            tx_start      <= '1', '0' after CLK_PERIOD;
            sent_count    <= sent_count + 1;
            tick;

            check(tx_busy = '1' and serial_line = '0', "TX rejected request");
            if tight_gap then
                check(now - last_frame_end = CLK_PERIOD,
                    "consecutive frames did not have a one-clock gap");
            end if;
            tx_data <= not data;

            -- Keep checking until the complete transmitted frame has ended.
            for cycle in 1 to 10 * EXPECTED_CLKS_PER_BIT loop
                tick;
                if cycle < 10 * EXPECTED_CLKS_PER_BIT then
                    check(tx_busy = '1', "TX ended early");
                else
                    check(tx_busy = '0' and serial_line = '1', "TX ended late");
                end if;
            end loop;

            check(received_count = count_before + 1, "missing or duplicate byte");
            check(rx_data = data, "received byte was not retained");
            last_frame_end := now;
        end procedure;
    begin
        for cycle in 1 to 3 loop
            tick;
        end loop;
        wait until falling_edge(clk);
        rst <= '0';
        expect_idle(8);
        report "PASS loopback baud " & integer'image(BAUD_RATE) & ": reset and idle"
            severity note;

        for pattern in PATTERNS'range loop
            send_and_check(PATTERNS(pattern));
            expect_idle(EXPECTED_CLKS_PER_BIT / 4);
        end loop;
        report "PASS loopback baud " & integer'image(BAUD_RATE)
            & ": eight fixed patterns with idle gaps"
            severity note;

        for bit_number in 0 to 7 loop
            walking_bit := std_logic_vector(shift_left(to_unsigned(1, 8), bit_number));
            send_and_check(walking_bit);
            send_and_check(not walking_bit, tight_gap => true);
        end loop;
        report "PASS loopback baud " & integer'image(BAUD_RATE)
            & ": sixteen walking-bit patterns"
            severity note;

        for frame_number in PATTERNS'range loop
            send_and_check(PATTERNS(frame_number), tight_gap => true);
        end loop;
        report "PASS loopback baud " & integer'image(BAUD_RATE)
            & ": consecutive frames with a one-clock gap"
            severity note;

        expect_idle(20 * EXPECTED_CLKS_PER_BIT);
        check(sent_count = 32 and received_count = 32,
            "final sent/received counts differ from 32");

        report "CASE PASSED: loopback baud " & integer'image(BAUD_RATE)
            & ", sent=" & integer'image(sent_count)
            & ", received=" & integer'image(received_count)
            severity note;
        done <= '1';
        finished <= true;
        wait;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_loopback is
end entity tb_uart_loopback;

architecture sim of tb_uart_loopback is
    signal done_9600   : std_logic := '0';
    signal done_115200 : std_logic := '0';
begin
    suite_9600 : entity work.tb_uart_loopback_case
        generic map (
            BAUD_RATE             => 9600,
            EXPECTED_CLKS_PER_BIT => 10417
        )
        port map (done => done_9600);

    suite_115200 : entity work.tb_uart_loopback_case
        generic map (
            BAUD_RATE             => 115200,
            EXPECTED_CLKS_PER_BIT => 868
        )
        port map (done => done_115200);

    completion : process
    begin
        wait until done_9600 = '1' and done_115200 = '1';
        report "ALL TESTS PASSED: UART loopback at 9600 and 115200 baud"
            severity note;
        stop;
        wait;
    end process;

    watchdog : process
    begin
        wait for 100 ms;
        assert false report "FAIL: UART loopback timeout" severity failure;
        stop;
        wait;
    end process;
end architecture sim;
