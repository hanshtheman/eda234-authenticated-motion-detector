library ieee;
use ieee.std_logic_1164.all;
--transmitter: one start bit, 8 data bits, no parity check, 1 stop bit
--Least significant bit first
--requests are accepted when IDLE. ignore when busy
--rst active-high synchronous rest
entity uart_tx is
--CLK_FREQ_HZ must match the actual freq of clock
--BAUD_RATE must match the target on pcb
    generic (
        CLK_FREQ_HZ : positive := 100_000_000;
        BAUD_RATE   : positive := 9600
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        tx_start : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);

        tx       : out std_logic;
        tx_busy  : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
    --CLKS_PERS_BIT is the rounded number of how much cycles it will take per UART bit
    constant CLKS_PER_BIT : positive :=
        (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;
    -- One frame: idle high -> start low -> bits 0 to 7 -> stop high.
    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t;

    signal data_reg  : std_logic_vector(7 downto 0);       -- holds the accepted bits
    signal busy_reg  : std_logic;                           --mantain high until stop bit
    signal bit_timer : integer range 0 to CLKS_PER_BIT - 1; -- counts from zero to CLKS_PERS_BITS-1
    signal bit_index : integer range 0 to 7;                --identifies the data bit currently being transmitted
begin

    tx_busy <= busy_reg;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state     <= IDLE;
                data_reg  <= (others => '0');
                busy_reg  <= '0';
                bit_timer <= 0;
                tx        <= '1';
                bit_index <= 0;

            else
                case state is
                --TX high
                --when recieve a request, TX low, busy
                    when IDLE =>
                        tx        <= '1';
                        busy_reg  <= '0';
                        bit_timer <= 0;

                        if tx_start = '1' then
                            -- Save the byte so later input changes cannot affect this frame.
                            data_reg <= tx_data;
                            busy_reg <= '1';
                            tx       <= '0';
                            state    <= START_BIT;
                        end if;
                --hold start bit low for a bit period
                    when START_BIT =>
                        -- Counting 0 through CLKS_PER_BIT - 1 gives one full bit.
                        if bit_timer = CLKS_PER_BIT - 1 then
                            bit_timer <= 0;
                            bit_index <= 0;
                            tx        <= data_reg(0);
                            state     <= DATA_BITS;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;
                --hold each data bit for a bit period
                    when DATA_BITS =>
                        if bit_timer = CLKS_PER_BIT - 1 then
                            bit_timer <= 0;

                            if bit_index = 7 then
                                tx    <= '1';
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                                tx        <= data_reg(bit_index + 1);
                            end if;

                        else
                            bit_timer <= bit_timer + 1;
                        end if;
                    --hold TX high for a bit period
                    --and go back to IDLE after transmition
                    when STOP_BIT =>
                        if bit_timer = CLKS_PER_BIT - 1 then
                            bit_timer <= 0;
                            busy_reg  <= '0';
                            state     <= IDLE;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;
                     end case;
                end if;

        end if;
                 
    end process;

end architecture rtl;