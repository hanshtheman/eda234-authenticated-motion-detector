library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_block is
port(
clk : in std_logic;
resetn : in std_logic;
motion_detected : in std_logic;  
bluetooth_connected : in std_logic;
--radar_input : in std_logic; 
bt_passphrase_in : in std_logic_vector(7 downto 0); --'HELLO' for now
bt_rx_valid : in std_logic;
led_r_out : out std_logic;
led_g_out : out std_logic;
buzzer_out_approved : out std_logic;
buzzer_out_denied : out std_logic;
screen_out : out std_logic
);

end control_block;


architecture structural of control_block is
--Radar_auth(tbd): to calculate if there's one person or more
--Bluetooth_auth: to see if the password match. password is 'HELLO' at the beginnning
--approved: password match, green light on, buzzer on
--denied: password do not match, red light on, buzzer on another sound
type block_states is (IDLE, BLUETOOTH_AUTH, APPROVED, DENIED, WAIT_MOTION_CLEAR);
signal states : block_states := IDLE;

	type passphrase_t is array (0 to 4) of std_logic_vector(7 downto 0);
    constant PASS_PHRASE : passphrase_t := (
        x"48", x"45", x"4C", x"4C", x"4F"  -- ASCII: HELLO
    );
    signal byte_index : integer range 0 to 4 := 0;

	constant RESULT_CYCLES : positive := 500_000_000; -- 5 s at 100 MHz
	signal result_count : natural range 0 to RESULT_CYCLES := 0;
	signal result_approved : std_logic := '0';

	constant BT_WAIT_CYCLES : positive := 300_000_000; -- 3 s at 100 MHz
	signal bt_wait_count : natural range 0 to BT_WAIT_CYCLES := 0;

begin

	clk_process : process(clk)
	begin

	if rising_edge(clk) then
		if resetn = '0' then
			states <= IDLE;
			byte_index <= 0;
			result_count <= 0;
			result_approved <= '0';
			bt_wait_count <= 0;
		else
			if result_count > 0 then
                result_count <= result_count - 1;
            end if;

			case states is
				when IDLE =>
					if motion_detected = '1' then
						byte_index <= 0;
						bt_wait_count <= BT_WAIT_CYCLES;
						states <= BLUETOOTH_AUTH;
					end if;
				
				when BLUETOOTH_AUTH =>
					if bt_wait_count > 0 then
        				bt_wait_count <= bt_wait_count - 1;
					end if;

					if bt_wait_count = 1 and bluetooth_connected /= '1' then
						states <= DENIED; --more than 3 seconds
					elsif bluetooth_connected /= '1' then
						byte_index <= 0;
					elsif bt_rx_valid = '1' then
						if byte_index = 0 then
							--ignore until the start of 'HELLO' which is 'H'
							if bt_passphrase_in = PASS_PHRASE(0) then
								byte_index <= 1;
							end if;
						elsif bt_passphrase_in /= PASS_PHRASE(byte_index) then 
							states <= DENIED ;
						elsif byte_index = PASS_PHRASE'high then
							states <= APPROVED;
						else 
							byte_index <= byte_index + 1;
						end if;
					end if;
				
				when APPROVED | DENIED =>
					if states = APPROVED then
                        result_approved <= '1';
                    else
                        result_approved <= '0';
                    end if;

                    result_count <= RESULT_CYCLES;
                    states <= WAIT_MOTION_CLEAR;

				when WAIT_MOTION_CLEAR =>
					if motion_detected = '0' then
							states <= IDLE;
					end if;

			end case;
			end if ;
		end if;
	end process clk_process;
    led_r_out           <= '1' when result_count > 0 and result_approved = '0' else '0';
    buzzer_out_denied   <= '1' when result_count > 0 and result_approved = '0' else '0';
    led_g_out           <= '1' when result_count > 0 and result_approved = '1' else '0';
    buzzer_out_approved <= '1' when result_count > 0 and result_approved = '1' else '0';
	screen_out <= '0';
end architecture structural;

				


