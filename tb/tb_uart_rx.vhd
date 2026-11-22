library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Generate UART input independently of uart_tx.
entity tb_uart_rx_case is
    generic (
        BAUD_RATE : positive := 9600
    );
    port (
        done : out std_logic := '0'
    );
end entity tb_uart_rx_case;

architecture sim of tb_uart_rx_case is
    constant CLK_PERIOD : time := 10 ns;
    constant BIT_PERIOD : time := 1 sec / BAUD_RATE;

    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
    constant PATTERNS : byte_array_t := (
        x"00", x"FF", x"55", x"AA", x"53", x"80", x"01", x"7F"
    );
    type slot_array_t is array (natural range <>) of natural;
    constant RESET_SLOTS : slot_array_t := (0, 4, 9);
    type time_array_t is array (natural range <>) of time;
    constant PHASES : time_array_t := (1 ns, 3 ns, 7 ns, 9 ns);
    constant GLITCH_WIDTHS : time_array_t := (2 * CLK_PERIOD, BIT_PERIOD / 4);

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal rx          : std_logic := '1';
    signal rx_data     : std_logic_vector(7 downto 0);
    signal rx_valid    : std_logic;
    signal frame_error : std_logic;
    signal finished    : boolean := false;

    -- The stimulus declares what the next received event must be.
    -- 0: no event, 1: valid byte, 2: bad stop bit.
    signal expected_event   : natural range 0 to 2 := 0;
    signal expected_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal frame_started    : time := 0 ns;
    signal source_bit_time  : time := BIT_PERIOD;
    signal valid_count      : natural := 0;
    signal error_count      : natural := 0;
begin
    clk <= not clk after CLK_PERIOD / 2 when not finished else '0';

    dut : entity work.uart_rx
        generic map (
            CLK_FREQ_HZ => 100_000_000,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk         => clk,
            rst         => rst,
            rx          => rx,
            rx_data     => rx_data,
            rx_valid    => rx_valid,
            frame_error => frame_error
        );

    -- Observe outputs independently of the serial-input driver.
    monitor : process
        variable previous_valid : std_logic := '0';
        variable previous_error : std_logic := '0';
        variable previous_data  : std_logic_vector(7 downto 0) := (others => '0');

        procedure check(condition : boolean; message_text : string) is
        begin
            assert condition
                report "Baud " & integer'image(BAUD_RATE) & ": " & message_text
                severity failure;
        end procedure;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;

        if rst = '1' then
            check(rx_valid = '0' and frame_error = '0',
                "event output active during reset");
            check(rx_data = x"00", "reset did not clear output data");
            previous_valid := '0';
            previous_error := '0';
            previous_data  := (others => '0');
        else
            check((rx_valid = '0' or rx_valid = '1')
                and (frame_error = '0' or frame_error = '1'),
                "unknown event output");
            check(not (rx_valid = '1' and frame_error = '1'),
                "valid and error asserted together");
            check(not (rx_valid = '1' and previous_valid = '1'),
                "rx_valid lasted longer than one clock");
            check(not (frame_error = '1' and previous_error = '1'),
                "frame_error lasted longer than one clock");

            if rx_valid = '1' then
                check(expected_event = 1, "unexpected valid-byte event");
                check(rx_data = expected_data, "received byte mismatch");
                valid_count <= valid_count + 1;
            else
                check(rx_data = previous_data,
                    "output data changed without a valid-byte event");
            end if;

            if frame_error = '1' then
                check(expected_event = 2, "unexpected framing error");
                error_count <= error_count + 1;
            end if;

            if rx_valid = '1' or frame_error = '1' then
                check(now >= frame_started + 9 * source_bit_time
                    and now < frame_started + 10 * source_bit_time,
                    "received event occurred outside the stop-bit interval");
            end if;

            previous_valid := rx_valid;
            previous_error := frame_error;
            previous_data  := rx_data;
        end if;
    end process;

    stimulus : process
        variable walking_bit : std_logic_vector(7 downto 0);
        variable old_valid   : natural;
        variable old_error   : natural;
        variable old_data    : std_logic_vector(7 downto 0);

        procedure check(condition : boolean; message_text : string) is
        begin
            assert condition
                report "Baud " & integer'image(BAUD_RATE) & ": " & message_text
                severity failure;
        end procedure;

        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 2 ns;
        end procedure;

        procedure quiet(duration : time) is
            variable before_valid : natural;
            variable before_error : natural;
        begin
            before_valid := valid_count;
            before_error := error_count;
            expected_event <= 0;
            wait for duration;
            check(valid_count = before_valid and error_count = before_error,
                "unexpected event while no frame was expected");
        end procedure;

        procedure send_frame(
            data       : std_logic_vector(7 downto 0);
            stop_ok    : boolean := true;
            bit_time   : time := BIT_PERIOD
        ) is
            variable before_valid : natural;
            variable before_error : natural;
        begin
            check(rx = '1', "serial driver must be idle before a new frame");
            before_valid := valid_count;
            before_error := error_count;
            expected_data   <= data;
            frame_started   <= now;
            source_bit_time <= bit_time;
            if stop_ok then
                expected_event <= 1;
            else
                expected_event <= 2;
            end if;

            rx <= '0';
            wait for bit_time;
            for bit_number in 0 to 7 loop
                rx <= data(bit_number);
                wait for bit_time;
            end loop;

            if stop_ok then
                rx <= '1';
            else
                rx <= '0';
            end if;
            wait for bit_time;

            if stop_ok then
                check(valid_count = before_valid + 1,
                    "missing or duplicate valid-byte event");
                check(error_count = before_error, "valid frame caused an error");
                check(rx_data = data, "output byte not retained after frame");
            else
                check(valid_count = before_valid, "bad frame published data");
                check(error_count = before_error + 1,
                    "missing or duplicate framing-error event");
            end if;
        end procedure;
    begin
        for cycle in 1 to 3 loop
            tick;
        end loop;
        wait until falling_edge(clk);
        rst <= '0';
        quiet(2 * BIT_PERIOD);
        report "PASS RX baud " & integer'image(BAUD_RATE) & ": reset and idle"
            severity note;

        -- All-zero/all-one, alternating patterns and individual bit positions.
        for pattern in PATTERNS'range loop
            send_frame(PATTERNS(pattern));
        end loop;
        for bit_number in 0 to 7 loop
            walking_bit := std_logic_vector(shift_left(to_unsigned(1, 8), bit_number));
            send_frame(walking_bit);
            send_frame(not walking_bit);
        end loop;
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": 24 patterns, output retention and one-clock event pulses"
            severity note;

        -- Change the asynchronous start phase relative to the FPGA clock.
        for phase in PHASES'range loop
            quiet(BIT_PERIOD);
            wait until falling_edge(clk);
            wait for PHASES(phase);
            send_frame(x"53");
        end loop;
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": four asynchronous start phases"
            severity note;

        -- No extra idle time between one frame's stop bit and the next start.
        for frame_number in 0 to 7 loop
            send_frame(PATTERNS(frame_number));
        end loop;
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": eight consecutive frames with one stop bit each"
            severity note;

        -- Exercise small source/receiver timing differences, not just rounded DUT timing.
        for frame_number in 0 to 3 loop
            send_frame(PATTERNS(frame_number), bit_time => BIT_PERIOD * 98 / 100);
        end loop;
        for frame_number in 0 to 3 loop
            send_frame(PATTERNS(frame_number), bit_time => BIT_PERIOD * 102 / 100);
        end loop;
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": source bit periods at 98 and 102 percent of nominal"
            severity note;

        for glitch in GLITCH_WIDTHS'range loop
            expected_event <= 0;
            old_valid := valid_count;
            old_error := error_count;
            rx <= '0';
            wait for GLITCH_WIDTHS(glitch);
            rx <= '1';
            quiet(2 * BIT_PERIOD);
            check(valid_count = old_valid and error_count = old_error,
                "short low pulse produced a receive event");
            send_frame(x"55");
        end loop;
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": false starts rejected and next valid frame received"
            severity note;

        old_data := rx_data;
        send_frame(x"A6", stop_ok => false);
        check(rx_data = old_data, "bad frame overwrote the last valid byte");

        -- Keep the line low: the receiver must wait rather than repeatedly decode it.
        quiet(12 * BIT_PERIOD);
        rx <= '1';
        quiet(2 * BIT_PERIOD);
        send_frame(x"53");
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": bad stop, sustained low input and recovery"
            severity note;

        -- Abort in the start bit, a data bit and the stop bit before its sample.
        for test in RESET_SLOTS'range loop
            old_valid := valid_count;
            old_error := error_count;
            expected_event <= 0;
            for frame_bit in 0 to RESET_SLOTS(test) loop
                if frame_bit = 0 then
                    rx <= '0';
                elsif frame_bit = 9 then
                    rx <= '1';
                else
                    rx <= PATTERNS(4)(frame_bit - 1);
                end if;

                if frame_bit = RESET_SLOTS(test) then
                    wait for BIT_PERIOD / 4;
                else
                    wait for BIT_PERIOD;
                end if;
            end loop;

            wait until falling_edge(clk);
            old_data := rx_data;
            rst <= '1';
            wait for 1 ns;
            check(rx_data = old_data, "synchronous reset changed data before a clock edge");
            for cycle in 1 to 3 loop
                tick;
            end loop;
            check(valid_count = old_valid and error_count = old_error,
                "aborted frame generated an event");

            rx <= '1';
            wait until falling_edge(clk);
            rst <= '0';
            quiet(11 * BIT_PERIOD);
            send_frame(x"53");
        end loop;
        report "PASS RX baud " & integer'image(BAUD_RATE)
            & ": reset in start/data/stop, no stale event and successful restart"
            severity note;

        quiet(2 * BIT_PERIOD);
        report "CASE PASSED: UART RX baud " & integer'image(BAUD_RATE)
            & ", valid=" & integer'image(valid_count)
            & ", errors=" & integer'image(error_count)
            severity note;
        done <= '1';
        finished <= true;
        wait;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_rx is
end entity tb_uart_rx;

architecture sim of tb_uart_rx is
    signal done_9600   : std_logic := '0';
    signal done_115200 : std_logic := '0';
begin
    suite_9600 : entity work.tb_uart_rx_case
        generic map (BAUD_RATE => 9600)
        port map (done => done_9600);

    suite_115200 : entity work.tb_uart_rx_case
        generic map (BAUD_RATE => 115200)
        port map (done => done_115200);

    completion : process
    begin
        wait until done_9600 = '1' and done_115200 = '1';
        report "ALL TESTS PASSED: UART RX at 9600 and 115200 baud" severity note;
        stop;
        wait;
    end process;

    watchdog : process
    begin
        wait for 200 ms;
        assert false report "FAIL: UART RX regression timeout" severity failure;
        stop;
        wait;
    end process;
end architecture sim;
