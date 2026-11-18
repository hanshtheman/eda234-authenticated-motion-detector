library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
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
    -- Round to the nearest whole clock cycle per bit.
    constant CLKS_PER_BIT : positive :=
        (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;
    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t;

    signal data_reg  : std_logic_vector(7 downto 0);
    signal busy_reg  : std_logic;
    signal bit_timer : integer range 0 to CLKS_PER_BIT - 1;
    signal bit_index : integer range 0 to 7;
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
                    when IDLE =>
                        tx        <= '1';
                        busy_reg  <= '0';
                        bit_timer <= 0;

                        if tx_start = '1' then
                            data_reg <= tx_data;
                            busy_reg <= '1';
                            tx       <= '0';
                            state    <= START_BIT;
                        end if;

                    when START_BIT =>
                        if bit_timer = CLKS_PER_BIT - 1 then
                            bit_timer <= 0;
                            bit_index <= 0;
                            tx        <= data_reg(0);
                            state     <= DATA_BITS;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;
  
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