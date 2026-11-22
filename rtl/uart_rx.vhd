library ieee;
use ieee.std_logic_1164.all;
--the same as uart_tx
--rx_valid and frame_error are one-system-clock event pulses.
--rx_data holds the last valid byte.
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
    --the same as uart_tx
    constant CLKS_PER_BIT : positive :=
        (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;
    constant HALF_BIT_CLKS : natural := CLKS_PER_BIT / 2;

    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT, WAIT_IDLE);
    signal state     : state_t;
    signal bit_timer : integer range 0 to CLKS_PER_BIT - 1;

    signal bit_index : integer range 0 to 7;
    signal data_reg  : std_logic_vector(7 downto 0);

    signal rx_meta : std_logic;
    signal rx_sync : std_logic;
begin

    assert CLKS_PER_BIT >= 2
        report "UART RX requires at least two clock cycles per bit"
        severity failure;

    input_sync : process (clk)
    -- Synchronize the asynchronous RX input into the system-clock domain.
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

    receiver : process (clk)
    begin
        if rising_edge(clk) then
            -- Event outputs default low so each event lasts one clock cycle.
            rx_valid    <= '0';
            frame_error <= '0';

            if rst = '1' then
                state     <= IDLE;
                bit_timer <= 0;
                bit_index <= 0;
                data_reg  <= (others => '0');
                rx_data   <= (others => '0');
            else
                case state is
                -- when recive request rx low
                    when IDLE =>
                        bit_timer <= 0;

                        if rx_sync = '0' then
                            state <= START_BIT;
                        end if;
                --wait half a bit period check if rx is still low
                --reject if rx is high
                    when START_BIT =>
                        if bit_timer = HALF_BIT_CLKS - 1 then
                            bit_timer <= 0;

                            if rx_sync = '0' then
                                bit_index <= 0;
                                state     <= DATA_BITS;
                            else
                                state <= IDLE;
                            end if;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;
                    --wait 1 uart bit period each data bit
                    when DATA_BITS =>
                        if bit_timer = CLKS_PER_BIT - 1 then
                            bit_timer           <= 0;
                            data_reg(bit_index) <= rx_sync;

                            if bit_index = 7 then
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;
                    --
                    when STOP_BIT =>
                        if bit_timer = CLKS_PER_BIT - 1 then
                            bit_timer <= 0;

                            if rx_sync = '1' then
                                rx_data  <= data_reg;
                                rx_valid <= '1';
                                state    <= IDLE;
                            else
                                frame_error <= '1';
                                state       <= WAIT_IDLE;
                            end if;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;

                    when WAIT_IDLE =>
                        -- Rearm only after a bad frame's low input returns high.
                        if rx_sync = '1' then
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;



end architecture rtl;
