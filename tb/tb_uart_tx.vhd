library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_uart_tx is
end entity tb_uart_tx;

architecture sim of tb_uart_tx is
    constant CLK_PERIOD            : time := 10 ns;
    constant EXPECTED_CLKS_PER_BIT : positive := 10417;
    constant TEST_DATA             : std_logic_vector(7 downto 0) := x"53";

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal tx_start : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx       : std_logic;
    signal tx_busy  : std_logic;
begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.uart_tx
        generic map (
            CLK_FREQ_HZ => 100_000_000,
            BAUD_RATE   => 9600
        )
        port map (
            clk      => clk,
            rst      => rst,
            tx_start => tx_start,
            tx_data  => tx_data,
            tx       => tx,
            tx_busy  => tx_busy
        );

    stimulus : process
        variable expected_bit : std_logic;
        variable frame_data   : std_logic_vector(7 downto 0);
    begin
        -- Apply reset for two clock periods.
        wait for 2 * CLK_PERIOD;

        assert tx = '1' and tx_busy = '0'
            report "Reset check failed"
            severity failure;

        rst <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert tx = '1' and tx_busy = '0'
            report "Idle check failed"
            severity failure;

        -- Request transmission. Keep the request high for one clock period.
        wait until falling_edge(clk);
        tx_data  <= TEST_DATA;
        tx_start <= '1', '0' after CLK_PERIOD;

        -- The next rising edge accepts the request.
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Changing the input must not change the accepted byte.
        tx_data <= x"A6";

        -- Check every clock cycle of the complete 8N1 frame.
        for frame_bit in 0 to 9 loop
            if frame_bit = 0 then
                expected_bit := '0';
            elsif frame_bit = 9 then
                expected_bit := '1';
            else
                expected_bit := TEST_DATA(frame_bit - 1);
            end if;

            for cycle in 0 to EXPECTED_CLKS_PER_BIT - 1 loop
                -- A one-clock request during transmission must be ignored.
                if frame_bit = 4 and cycle = 0 then
                    tx_data  <= x"C3";
                    tx_start <= '1', '0' after CLK_PERIOD;
                end if;

                assert tx = expected_bit
                    report "TX mismatch at frame bit "
                        & integer'image(frame_bit)
                        & ", cycle " & integer'image(cycle)
                    severity failure;

                assert tx_busy = '1'
                    report "Busy released before the frame completed"
                    severity failure;

                wait until rising_edge(clk);
                wait for 1 ns;
            end loop;
        end loop;

        -- The full stop bit has now completed.
        assert tx = '1' and tx_busy = '0'
            report "Frame completion check failed"
            severity failure;

        -- Observe a full frame interval to detect an unwanted queued frame.
        for cycle in 1 to 10 * EXPECTED_CLKS_PER_BIT loop
            wait until rising_edge(clk);
            wait for 1 ns;

            assert tx = '1' and tx_busy = '0'
                report "Unexpected transmission after a request made while busy"
                severity failure;
        end loop;

        report "PASS: reset, frame timing, bit order, data latch and ignored busy request"
            severity note;

        -- Send two frames with only one system-clock interval between them.
        for frame_number in 0 to 1 loop
            if frame_number = 0 then
                frame_data := x"55";
            else
                frame_data := x"AA";
            end if;

            assert tx = '1' and tx_busy = '0'
                report "Transmitter not ready for the next frame"
                severity failure;

            wait until falling_edge(clk);
            tx_data  <= frame_data;
            tx_start <= '1', '0' after CLK_PERIOD;

            wait until rising_edge(clk);
            wait for 1 ns;

            for frame_bit in 0 to 9 loop
                if frame_bit = 0 then
                    expected_bit := '0';
                elsif frame_bit = 9 then
                    expected_bit := '1';
                else
                    expected_bit := frame_data(frame_bit - 1);
                end if;

                for cycle in 0 to EXPECTED_CLKS_PER_BIT - 1 loop
                    assert tx = expected_bit
                        report "Consecutive frame " & integer'image(frame_number)
                            & ": TX mismatch at bit " & integer'image(frame_bit)
                            & ", cycle " & integer'image(cycle)
                        severity failure;

                    assert tx_busy = '1'
                        report "Busy released early in consecutive frame "
                            & integer'image(frame_number)
                        severity failure;

                    wait until rising_edge(clk);
                    wait for 1 ns;
                end loop;
            end loop;

            assert tx = '1' and tx_busy = '0'
                report "Consecutive frame did not complete on time"
                severity failure;
        end loop;

        report "PASS: consecutive frames 55 and AA with a one-clock gap"
            severity note;

        -- Interrupt a frame while TX is actively sending a low data bit.
        wait until falling_edge(clk);
        tx_data  <= x"00";
        tx_start <= '1', '0' after CLK_PERIOD;

        wait until rising_edge(clk);
        wait for 1 ns;
        wait for (5 * EXPECTED_CLKS_PER_BIT * CLK_PERIOD) / 2;

        assert tx_busy = '1' and tx = '0'
            report "Reset test did not reach an active low data bit"
            severity failure;

        wait until falling_edge(clk);
        rst <= '1';

        -- A synchronous reset takes effect at the next rising edge.
        wait until rising_edge(clk);
        wait for 1 ns;

        assert tx = '1' and tx_busy = '0'
            report "Reset did not abort the active frame"
            severity failure;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert tx = '1' and tx_busy = '0'
            report "Reset outputs were not held idle"
            severity failure;

        wait until falling_edge(clk);
        rst <= '0';

        -- No new request: the interrupted frame must not resume.
        for cycle in 1 to 10 * EXPECTED_CLKS_PER_BIT loop
            wait until rising_edge(clk);
            wait for 1 ns;

            assert tx = '1' and tx_busy = '0'
                report "Interrupted transmission resumed after reset"
                severity failure;
        end loop;

        report "PASS: reset during transmission aborts the frame"
            severity note;

        stop;
        wait;
    end process;

    watchdog : process
    begin
        wait for 6 ms;

        assert false
            report "FAIL: simulation timeout"
            severity failure;

        stop;
        wait;
    end process;

end architecture sim;