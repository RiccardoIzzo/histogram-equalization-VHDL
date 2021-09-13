-------------------------------------------------------------------------------
--
-- Progetto di Reti Logiche AA 2020-2021
-- Prof. F. Salice
--
-- Gabriele Lazzarelli
-- 10623766
-- Riccardo Izzo
-- 10599996
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity project_reti_logiche is
    Port ( i_clk : in std_logic;
           i_rst : in std_logic;
           i_start : in std_logic;
           i_data : in std_logic_vector (7 downto 0);
           o_address : out std_logic_vector (15 downto 0);
           o_done : out std_logic;
           o_en : out std_logic;
           o_we : out std_logic;
           o_data : out std_logic_vector (7 downto 0));
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
type state_type is (RESET, IDLE, WAIT_CLK, READ_BYTE, CALC_SIZE, CALC_SHIFT, WRITE_BYTE, DONE);
signal curr_state, next_state : state_type := IDLE;
signal status: integer range 0 to 3;
signal curr_address : std_logic_vector (15 downto 0);
signal max_address : std_logic_vector (15 downto 0);
signal n_col : integer range 0 to 128;
signal n_row : integer range 0 to 128;
signal max : integer range 0 to 255;
signal min : integer range 0 to 255;
signal shift_level : integer range 0 to 8;

begin

  state_reg: process(i_clk, i_rst)
  begin
    if i_rst='1' then
        curr_state <= RESET;
    elsif falling_edge(i_clk) then
        curr_state <= next_state;
    end if;
  end process;
  
  lambda: process(curr_state, i_start, i_clk)
  variable delta_value: integer range 0 to 255 := 0;
  variable new_pixel_value: integer range 0 to 65280 := 0;
  variable temp: integer range 0 to 255;
  begin
    if rising_edge(i_clk) then
        case curr_state is
            when RESET =>
                o_en <= '0';
                o_we <= '0';
                status <= 0;
                max <= 0;
                min <= 255;
                curr_address <= "0000000000000010";
                o_address <= "0000000000000000";
                next_state <= IDLE;
          
            when IDLE =>
                if(i_start = '1') then 
                    next_state <= WAIT_CLK;
                    o_en <= '1';
                    o_we <= '0';
                else 
                    next_state <= IDLE;
                    o_en <= '0';
                    o_we <= '0';
                end if;
          
            when WAIT_CLK =>
                o_en <= '0';
                o_we <= '0';
                next_state <= READ_BYTE;
            
            when READ_BYTE =>
                case status is
            
                    when 0 =>
                        o_en <= '1';
                        o_we <= '0';
                        n_col <= conv_integer(i_data);
                        next_state <= WAIT_CLK;
                        o_address <= "0000000000000001";
                        status <= 1;
                        
                    when 1 =>
                        o_en <= '0';
                        o_we <= '0';
                        n_row <= conv_integer(i_data);
                        next_state <= CALC_SIZE;
                        o_address <= "0000000000000010";
                        status <= 2;
                        
                    when 2 =>
                        o_en <= '0';
                        o_we <= '0';
                        temp := conv_integer(i_data);
                        if(temp > max) then max <= temp;
                        end if;
                        
                        if(temp < min) then min <= temp;
                        end if;
                        
                        if(curr_address = max_address) then 
                            next_state <= CALC_SHIFT;
                            status <= 3;
                        else 
                            next_state <= WAIT_CLK;
                            o_en <= '1';
                            o_we <= '0';
                        end if;
                        
                        curr_address <= curr_address + "0000000000000001";
                        o_address <= curr_address + "0000000000000001";
                        
                    when 3 =>
                        o_en <= '1';
                        o_we <= '1';
                        new_pixel_value := (conv_integer(i_data) - min) * (2 ** shift_level);
                        if(new_pixel_value > 255) then new_pixel_value := 255;
                        end if;
                        o_address <= curr_address + max_address - "0000000000000001";
                        o_data <= std_logic_vector(to_unsigned(new_pixel_value, o_data'length));
                        next_state <= WRITE_BYTE;
                  
                end case;
       
            when CALC_SIZE =>
                o_en <= '1';
                o_we <= '0';
                if(n_col = 0 or n_row = 0) then
                    next_state <= DONE;
                else
                    max_address <= std_logic_vector(to_unsigned(n_col * n_row + 1, max_address'length));
                    next_state <= WAIT_CLK;
                end if;
        
            when CALC_SHIFT =>
                o_en <= '1';
                o_we <= '0';
                curr_address <= "0000000000000010";
                o_address <= "0000000000000010";
                delta_value := max - min;
                if(delta_value = 0) then shift_level <= 8;
                elsif(delta_value >= 1 and delta_value <= 2) then shift_level <= 7;
                elsif(delta_value >= 3 and delta_value <= 6) then shift_level <= 6;
                elsif(delta_value >= 7 and delta_value <= 14) then shift_level <= 5;
                elsif(delta_value >= 15 and delta_value <= 30) then shift_level <= 4;
                elsif(delta_value >= 31 and delta_value <= 62) then shift_level <= 3;
                elsif(delta_value >= 63 and delta_value <= 126) then shift_level <= 2;
                elsif(delta_value >= 127 and delta_value <= 254) then shift_level <= 1;
                elsif(delta_value = 255) then shift_level <= 0;
                end if;
                next_state <= WAIT_CLK;
        
            when WRITE_BYTE =>
                o_we <= '0';
                if(curr_address = max_address) then 
                    next_state <= DONE;
                    o_en <= '0';
                else 
                    o_en <= '1';
                    next_state <= WAIT_CLK;
                    o_address <= curr_address + "0000000000000001";
                    curr_address <= curr_address + "0000000000000001";
                end if;
        
            when DONE =>
                o_en <= '0';
                o_we <= '0';
                next_state <= RESET;
        
        end case;
    end if;
  end process;

  delta: process(curr_state, i_clk)
  begin
    if rising_edge(i_clk) then
        case curr_state is
            when RESET =>
      
            when IDLE => 
                o_done <= '0';
        
            when WAIT_CLK =>
                o_done <= '0';
        
            when READ_BYTE =>
                o_done <= '0';
        
            when CALC_SIZE =>
                o_done <= '0';
            
            when CALC_SHIFT =>
                o_done <= '0';
          
            when WRITE_BYTE =>
                o_done <= '0';
            
            when DONE =>
                o_done <= '1';
    
        end case;
    end if;
  end process;
end Behavioral;