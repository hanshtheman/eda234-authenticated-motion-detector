library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_block is
port(
clk : in std_logic;
resetn : in std_logic;
motion_detected : in std_logic;
--radar_input : in std_logic; 
bt_passphrase_in : in std_logic_vector(7 downto 0); -- size unknown
bt_rx_valid : in std_logic;
led_r_out : out std_logic;
led_g_out : out std_logic;
buzzer_out : out std_logic;
screen_out : out std_logic
);

end control_block;


architecture structural of control_block is
--Radar_auth(tbd): to calculate if there's one person or more
--Bluetooth_auth: to see if the password match. password is 'HELLO' at the beginnning
--approved: password match, green light on, buzzer on
--denied: password do not match, red light on, buzzer on another sound
type block_states is (IDLE, BLUETOOTH_AUTH, APPROVED, DENIED);
signal states : block_states := IDLE;

begin

clk_process : process(clk, resetn)

	if rising_edge(clk) then
		if resetn = '0' then
			states <= IDLE;


