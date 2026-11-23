library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Demo messages only; these are not the project's authentication protocol.
entity uart_message_tx is
    generic (
        CLK_FREQ_HZ : positive := 100_000_000;
        BAUD_RATE   : positive := 9600
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        send_a  : in  std_logic;
        send_b  : in  std_logic;
        tx      : out std_logic;
        busy    : out std_logic
    );
end entity uart_message_tx;

architecture rtl of uart_message_tx is
    -- Five letters plus CR (13) and LF (10): seven bytes per message.
    constant MESSAGE_A : string(1 to 7) :=
        "HELLO" & character'val(13) & character'val(10);
    constant MESSAGE_B : string(1 to 7) :=
        "ALARM" & character'val(13) & character'val(10);

    -- Select a message, request one byte, then wait for that byte to finish.
    type state_t is (IDLE, LOAD_BYTE, WAIT_BUSY, WAIT_DONE);
    signal state        : state_t;
    signal selected_b   : boolean; -- false: HELLO; true: ALARM
    signal byte_index   : integer range 1 to 7; -- Current character position
    signal byte_data    : std_logic_vector(7 downto 0);
    signal byte_start   : std_logic;
    signal byte_busy    : std_logic;
begin
    -- Message busy stays high between bytes; byte_busy covers just one frame.
    busy <= '0' when state = IDLE else '1';

    -- Reuse uart_tx to send one byte at a time.
    transmitter : entity work.uart_tx
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk      => clk,
            rst      => rst,
            tx_start => byte_start,
            tx_data  => byte_data,
            tx       => tx,
            tx_busy  => byte_busy
        );

    process (clk)
    begin
        if rising_edge(clk) then
            -- Default low: a request lasts only one system-clock cycle.
            byte_start <= '0';
            if rst = '1' then
                state      <= IDLE;
                selected_b <= false;
                byte_index <= 1;
                byte_data  <= (others => '0');
            else
                case state is
                    when IDLE =>
                        -- A has priority if both requests arrive together.
                        if send_a = '1' or send_b = '1' then
                            -- Choose B only when A was not requested.
                            selected_b <= send_a = '0';
                            byte_index <= 1;
                            state      <= LOAD_BYTE;
                        end if;

                    when LOAD_BYTE =>
                        -- Character -> character code -> 8-bit unsigned -> logic vector.
                        -- For these messages, the character codes are ASCII.
                        if selected_b then
                            byte_data <= std_logic_vector(
                                to_unsigned(character'pos(MESSAGE_B(byte_index)), 8));
                        else
                            byte_data <= std_logic_vector(
                                to_unsigned(character'pos(MESSAGE_A(byte_index)), 8));
                        end if;
                        -- uart_tx sees this data and request on the next clock edge.
                        byte_start <= '1';
                        state      <= WAIT_BUSY;

                    when WAIT_BUSY =>
                        -- Wait until uart_tx has accepted the request.
                        if byte_busy = '1' then
                            state <= WAIT_DONE;
                        end if;

                    when WAIT_DONE =>
                        -- First see busy go high, then wait for it to go low.
                        -- Otherwise, the old low value could look like completion.
                        if byte_busy = '0' then
                            -- Finish after LF, or move to the next character.
                            if byte_index = 7 then
                                state <= IDLE;
                            else
                                byte_index <= byte_index + 1;
                                state      <= LOAD_BYTE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
