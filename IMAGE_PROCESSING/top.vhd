library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
use std.textio.all;


use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL;




entity top is
    Port ( CLK_I : in  STD_LOGIC;
           VGA_HS_O : out  STD_LOGIC;
           VGA_VS_O : out  STD_LOGIC;
           VGA_R : out  STD_LOGIC_VECTOR (3 downto 0);
           VGA_B : out  STD_LOGIC_VECTOR (3 downto 0);
           VGA_G : out  STD_LOGIC_VECTOR (3 downto 0); 
           row : in std_logic_vector(3 downto 0);
           col : out std_logic_vector(3 downto 0);
           rst: in std_logic;
           mul: in std_logic;
           zoom1: in std_logic;
           zoom2: in std_logic;
           zoom3: in std_logic
           );
end top;

architecture Behavioral of top is




component blk_mem_gen_0
port(
addra: std_logic_vector(6 downto 0);
clka: in std_logic;
douta: out std_logic_vector(783 downto 0);
ena: in std_logic
);
end component;


component SHIFT_ADDER 
generic( n : integer; m: integer);
port(a: in std_logic_vector(m-1 downto 0); b: in std_logic_vector(n-1 downto 0); c: out std_logic_vector((n+m)-1 downto 0));
end component;

component clk_wiz_0
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic
 );
end component;

component Decoder is
    port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        Row : in STD_LOGIC_VECTOR (3 downto 0);
        Col : out STD_LOGIC_VECTOR (3 downto 0);
        DecodeOut : out STD_LOGIC_VECTOR (3 downto 0)
        );
end component;

component DeBounce is
generic (
    clk_freq    : integer; 
    stable_time : integer
    );        
port (
        clk     : in std_logic;   
        reset_n : in std_logic;   
        button  : in std_logic;
        result  : out std_logic); 
end component;

type rom_type is array(0 to 27) of std_logic_vector (0 to 27);

signal img: rom_type;
signal img2: rom_type;


type rom_type2 is array(0 to 27) of std_logic_vector (0 to 55);
signal diff: rom_type2;


--for storing mul result
--type rom_type1 is array(0 to 27) of std_logic_vector (0 to 27);
--signal result: rom_type1;
--signal result2: rom_type1;

 constant clk_freq    : integer := 50_000_000; 
 constant stable_time : integer := 10;

--***1920x1080@60Hz***-- Requires 148.5 MHz pxl_clk
constant FRAME_WIDTH : natural := 1920;
constant FRAME_HEIGHT : natural := 1080;

constant H_FP : natural := 88; --H front porch width (pixels)
constant H_PW : natural := 44; --H sync pulse width (pixels)
constant H_MAX : natural := 2200; --H total period (pixels)

constant V_FP : natural := 4; --V front porch width (lines)
constant V_PW : natural := 5; --V sync pulse width (lines)
constant V_MAX : natural := 1125; --V total period (lines)


constant H_POL : std_logic := '1';
constant V_POL : std_logic := '1';

--Moving Box constants
constant BOX_WIDTH : natural := 30;
constant BOX_CLK_DIV : natural := 5000; --MAX=(2^25 - 1)

constant BOX_X_MAX : natural := (FRAME_WIDTH);
constant BOX_Y_MAX : natural := (FRAME_HEIGHT);

constant BOX_X_MIN : natural := 0;
constant BOX_Y_MIN : natural := 0;

constant BOX_X_INIT : std_logic_vector(11 downto 0) := x"000";
constant BOX_Y_INIT : std_logic_vector(11 downto 0) := x"190"; --400

signal pxl_clk : std_logic;
signal active : std_logic;

signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');

signal vert_count : std_logic_vector(5 downto 0) := (others =>'0');
signal horz_count : std_logic_vector(5 downto 0) := (others =>'0');

signal h_cntr_reg_sqr : signed(23 downto 0) := (others =>'0');
signal v_cntr_reg_sqr : signed(23 downto 0) := (others =>'0');
signal expr : signed (24 downto 0) := (others => '0');
signal radius : signed(3 downto 0) := "1111";

signal h_sync_reg : std_logic := not(H_POL);
signal v_sync_reg : std_logic := not(V_POL);

signal h_sync_dly_reg : std_logic := not(H_POL);
signal v_sync_dly_reg : std_logic :=  not(V_POL);

signal vga_red_reg : std_logic_vector(3 downto 0) := (others =>'0');
signal vga_green_reg : std_logic_vector(3 downto 0) := (others =>'0');
signal vga_blue_reg : std_logic_vector(3 downto 0) := (others =>'0');

signal vga_red : std_logic_vector(3 downto 0);
signal vga_green : std_logic_vector(3 downto 0);
signal vga_blue : std_logic_vector(3 downto 0);

signal box_x_reg : std_logic_vector(11 downto 0) := BOX_X_INIT;
signal box_x_dir : std_logic := '1';
signal box_y_reg : std_logic_vector(11 downto 0) := BOX_Y_INIT;
signal box_y_dir : std_logic := '1';
signal box_cntr_reg : std_logic_vector(24 downto 0) := (others =>'0');

signal mover : signed(32 downto 0 ) := (others => '0'); --300
signal mover2 : signed(32 downto 0 ) := (others => '0');

signal update_box : std_logic;
signal pixel_in_box : std_logic;

signal img_pixel: std_logic;

signal douta: std_logic_vector(783 downto 0);
signal addra: std_logic_vector(6 downto 0);
signal addr1: std_logic_vector(6 downto 0);
signal addr2: std_logic_vector(6 downto 0);

signal i: natural := 0;

signal ena: std_logic := '1';

signal decode : STD_LOGIC_VECTOR (3 downto 0);


signal pulse: STD_LOGIC_VECTOR(3 downto 0);

constant m: natural:= 28;
constant n: natural:= 28;

signal key_sel: std_logic:='0';

signal c: STD_LOGIC_VECTOR((m+n)-1 downto 0);
signal a : STD_LOGIC_VECTOR (m-1 downto 0);
signal b : STD_LOGIC_VECTOR (m-1 downto 0);

signal decode1: STD_LOGIC_VECTOR(3 downto 0);
signal decode2: STD_LOGIC_VECTOR(3 downto 0);

signal a0: natural:= 0; -- 0 to 9
signal a1: natural:= 10;
signal a2: natural:= 20;
signal a3: natural:= 30;
signal a4: natural:= 40;
signal a5: natural:= 50;
signal a6: natural:= 60;
signal a7: natural:= 70;
signal a8: natural:= 80;
signal a9: natural:= 90;

signal vert, horz: integer;


signal zoom_level: std_logic_vector(2 downto 0) := zoom1 & zoom2 & zoom3;


signal upper_bound: natural := 0;
signal lower_bound: natural := 0;
signal upper_bound1: natural:=0;
signal lower_bound1: natural:=0;
signal speed1: natural :=0;
signal speed2: natural:= 0;

begin

process(zoom1, zoom2, zoom3)
begin

if(zoom_level = "000") then
lower_bound <= 0;
upper_bound <= 23;

lower_bound1<=26;
upper_bound1<=75;

speed1 <= 4;
speed2<= 0;
vert <= conv_integer(v_cntr_Reg(4 downto 0));
horz <= conv_integer(h_cntr_Reg(4 downto 0));

elsif(zoom_level = "100") then 
lower_bound<= 0;
upper_bound <= 100;

lower_bound1<=101;
upper_bound1<=250;

speed1 <= 6;
speed2 <= 2;
vert <= conv_integer(v_cntr_Reg(6 downto 2));
horz <= conv_integer(h_cntr_Reg(6 downto 2));

elsif(zoom_level = "110") then
lower_bound<= 0;
upper_bound <= 400;

lower_bound1<=401;
upper_bound1<=860;

speed1<=8;
speed2 <= 4;
vert <= conv_integer(v_cntr_Reg(8 downto 4));
horz <= conv_integer(h_cntr_Reg(8 downto 4));

else
lower_bound<=0;
upper_bound<=600;

lower_bound1<=601;
upper_bound1<=1200;

speed1<=10;
speed2<=6;
vert <= conv_integer(v_cntr_Reg(10 downto 6));
horz <= conv_integer(h_cntr_Reg(10 downto 6));

end if;

end process;



--POOR CODING style, will change in future--

--load values multiplication product values into memory
process(CLK_I, rst)
begin

if(rst = '1') then
i<=0;

elsif (rising_edge(CLK_I)) then

if(mul = '1') then

if(i<28) then

a<=img(i);
b<=img2(i);
diff(i) <= c;
i<=i+1;

else
i<=0;

end if;

else
i<=0;

end if;

end if;

end process;

process(decode, decode1, decode2, img)
begin

if(decode = decode1) then
img(0) <= douta(783 downto 756);
img(1) <= douta(755 downto 728);
img(2) <= douta(727 downto 700);
img(3) <= douta(699 downto 672);
img(4) <= douta(671 downto 644);
img(5) <= douta(643 downto 616);
img(6) <= douta(615 downto 588);
img(7) <= douta(587 downto 560);
img(8) <= douta(559 downto 532);
img(9) <= douta(531 downto 504);
img(10) <= douta(503 downto 476);
img(11) <= douta(475 downto 448);
img(12) <= douta(447 downto 420);
img(13) <= douta(419 downto 392);
img(14) <= douta(391 downto 364);
img(15) <= douta(363 downto 336);
img(16) <= douta(335 downto 308);
img(17) <= douta(307 downto 280);
img(18) <= douta(279 downto 252);
img(19) <= douta(251 downto 224);
img(20) <= douta(223 downto 196);
img(21) <= douta(195 downto 168);
img(22) <= douta(167 downto 140);
img(23) <= douta(139 downto 112);
img(24) <= douta(111 downto 84);
img(25) <= douta(83 downto 56);
img(26) <= douta(55 downto 28);
img(27) <= douta(27 downto 0);


elsif(decode = decode2) then
img2(0) <= douta(783 downto 756);
img2(1) <= douta(755 downto 728);
img2(2) <= douta(727 downto 700);
img2(3) <= douta(699 downto 672);
img2(4) <= douta(671 downto 644);
img2(5) <= douta(643 downto 616);
img2(6) <= douta(615 downto 588);
img2(7) <= douta(587 downto 560);
img2(8) <= douta(559 downto 532);
img2(9) <= douta(531 downto 504);
img2(10) <= douta(503 downto 476);
img2(11) <= douta(475 downto 448);
img2(12) <= douta(447 downto 420);
img2(13) <= douta(419 downto 392);
img2(14) <= douta(391 downto 364);
img2(15) <= douta(363 downto 336);
img2(16) <= douta(335 downto 308);
img2(17) <= douta(307 downto 280);
img2(18) <= douta(279 downto 252);
img2(19) <= douta(251 downto 224);
img2(20) <= douta(223 downto 196);
img2(21) <= douta(195 downto 168);
img2(22) <= douta(167 downto 140);
img2(23) <= douta(139 downto 112);
img2(24) <= douta(111 downto 84);
img2(25) <= douta(83 downto 56);
img2(26) <= douta(55 downto 28);
img2(27) <= douta(27 downto 0);

end if;



end process;

DC0 : Decoder port map(
   clk => CLK_I, 
   rst => rst, 
   Row => row, 
   Col => col, 
   DecodeOut => decode);
   
SM0: SHIFT_ADDER
generic map
(m=>m, n=>n) 
port map(
a => a,
b => b,
c => c
);

D0 : DeBounce  generic map(clk_freq => clk_freq, stable_time => stable_time)
port map(
   clk => CLK_I, 
   reset_n => rst, 
   button => decode(3),
   result => pulse(3));
   
   
D1 : DeBounce  generic map(clk_freq => clk_freq, stable_time => stable_time)
port map(
   clk => CLK_I, 
   reset_n => rst, 
   button => decode(2),
   result => pulse(2));
   
   
D2 : DeBounce  generic map(clk_freq => clk_freq, stable_time => stable_time)
port map(
   clk => CLK_I, 
   reset_n => rst, 
   button => decode(1),
   result => pulse(1));
   
D3 : DeBounce  generic map(clk_freq => clk_freq, stable_time => stable_time)
port map(
   clk => CLK_I, 
   reset_n => rst, 
   button => decode(0),
   result => pulse(0));
   
   
blk_mem_inst: blk_mem_gen_0
port map
(
clka => CLK_I,
douta => douta,
addra => addra,
ena => ena
);

clk_div_inst : clk_wiz_0
  port map
   (-- Clock in ports
    CLK_IN1 => CLK_I,
    -- Clock out ports
    CLK_OUT1 => pxl_clk);


with (decode1) select
addr1 <= std_logic_vector(to_unsigned(a0,addr1'length)) when "0000",
std_logic_vector(to_unsigned(a1,addr1'length)) when "0001",
std_logic_vector(to_unsigned(a2,addr1'length)) when "0010",
std_logic_vector(to_unsigned(a3,addr1'length)) when "0011",
std_logic_vector(to_unsigned(a4,addr1'length)) when "0100",
std_logic_vector(to_unsigned(a5,addr1'length)) when "0101",
std_logic_vector(to_unsigned(a6,addr1'length)) when "0110",
std_logic_vector(to_unsigned(a7,addr1'length)) when "0111",
std_logic_vector(to_unsigned(a8,addr1'length)) when "1000",
std_logic_vector(to_unsigned(a9,addr1'length)) when "1001",
"0000100" when others;

with (decode2) select
addr2 <= std_logic_vector(to_unsigned(a0,addr1'length)) when "0000",
std_logic_vector(to_unsigned(a1,addr1'length)) when "0001",
std_logic_vector(to_unsigned(a2,addr1'length)) when "0010",
std_logic_vector(to_unsigned(a3,addr1'length)) when "0011",
std_logic_vector(to_unsigned(a4,addr1'length)) when "0100",
std_logic_vector(to_unsigned(a5,addr1'length)) when "0101",
std_logic_vector(to_unsigned(a6,addr1'length)) when "0110",
std_logic_vector(to_unsigned(a7,addr1'length)) when "0111",
std_logic_vector(to_unsigned(a8,addr1'length)) when "1000",
std_logic_vector(to_unsigned(a9,addr1'length)) when "1001",
"1000000" when others;

addra <= addr1 when (decode1 = decode)
else addr2;


  
    
vga_red <= (others => img_pixel);
vga_green <= (others => img_pixel);
vga_blue <= (others => img_pixel);
    



 process(CLK_I, rst)
 begin
 if(rst = '1') then
 key_sel <= '0';
 decode1 <= (others => '0');
 decode2 <= (others => '0');
 else if(rising_edge(CLK_I)) then       
        if(decode /= pulse) then
            key_sel <= not key_sel;       
        else
            if(key_sel = '0') then
                decode1 <= decode;
            else
                decode2 <= decode;
            end if;      
       end if;
       end if;
   end if;   
 end process;

 
 
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (update_box = '1') then
        if (box_x_dir = '1') then
          box_x_reg <= box_x_reg + 1;
        else
          box_x_reg <= box_x_reg - 1;
        end if;
        if (box_y_dir = '1') then
          box_y_reg <= box_y_reg + 1;
        else
          box_y_reg <= box_y_reg - 1;
        end if;
      end if;
    end if;
  end process;
      
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (update_box = '1') then
        if ((box_x_dir = '1' and (box_x_reg = BOX_X_MAX - 1)) or (box_x_dir = '0' and (box_x_reg = BOX_X_MIN + 1))) then
          box_x_dir <= not(box_x_dir);
        end if;
        if ((box_y_dir = '1' and (box_y_reg = BOX_Y_MAX - 1)) or (box_y_dir = '0' and (box_y_reg = BOX_Y_MIN + 1))) then
          box_y_dir <= not(box_y_dir);
        end if;
      end if;
    end if;
  end process;
  
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (box_cntr_reg = (BOX_CLK_DIV - 1)) then
        box_cntr_reg <= (others=>'0');
        vert_count <= vert_count + 1;
        horz_count <= horz_count + 1;
      else
        box_cntr_reg <= box_cntr_reg + 1;   
        horz_count <= (others => '0');
        vert_count <= (others => '0');  
      end if;
    end if;
  end process;
  
  update_box <= '1' when box_cntr_reg = (BOX_CLK_DIV - 1) else
                '0';

  
  process(decode)
  begin
  
  if(mul = '0' and douta > 0) then
  
  --lower = 0, upper = 400.
  if((h_cntr_reg >= lower_bound and (h_cntr_reg < upper_bound) and v_cntr_reg >= lower_bound and (v_cntr_reg < upper_bound))  and (douta > 0)) then
        img_pixel <=  img(vert)(horz);

  elsif((h_cntr_reg >= lower_bound1 and (h_cntr_reg < upper_bound1) and v_cntr_reg >= lower_bound and (v_cntr_reg < upper_bound))  and (douta > 0)) then
        img_pixel <=  img2(vert)(horz);
  else 
    img_pixel <= '0';
  end if;
  
  elsif(mul = '1' and douta > 0) then
 
  if((h_cntr_reg >= lower_bound and (h_cntr_reg < upper_bound) and v_cntr_reg >= lower_bound and (v_cntr_reg < upper_bound))  and (douta > 0)) then
        img_pixel <=  diff(vert)(horz);
  else 
    img_pixel <= '0';
  end if;
  
  else
    img_pixel <= '0'; 
           
  end if;
  
  end process;
  
--  img_pixel <=  img(conv_integer(v_cntr_Reg(8 downto 4)))((conv_integer(h_cntr_reg(8 downto 4)))) when 
--  (h_cntr_reg >= 0 and (h_cntr_reg < 400) and v_cntr_reg >= 0 and (v_cntr_reg < 400))  and (douta > 0) else '0';


--  img_pixel <=  douta(conv_integer(v_cntr_Reg(9 downto 0))) when 
--  (h_cntr_reg >= 0 and (h_cntr_reg < 600) and v_cntr_reg >= 0 and (v_cntr_reg < 600)) else '0';  
 ------------------------------------------------------
 -------         SYNC GENERATION                 ------
 ------------------------------------------------------
 
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (h_cntr_reg = (H_MAX - 1)) then
        h_cntr_reg <= (others =>'0');
      else
        h_cntr_reg <= h_cntr_reg + 1;
      end if;
    end if;
  end process;
  
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if ((h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1))) then
        v_cntr_reg <= (others =>'0');
      elsif (h_cntr_reg = (H_MAX - 1)) then
        v_cntr_reg <= v_cntr_reg + 1;
      end if;
    end if;
  end process;
  
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) and (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) then
        h_sync_reg <= H_POL;
      else
        h_sync_reg <= not(H_POL);
      end if;
    end if;
  end process;
  
  
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) and (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) then
        v_sync_reg <= V_POL;
      else
        v_sync_reg <= not(V_POL);
      end if;
    end if;
  end process;
  
  
  active <= '1' when ((h_cntr_reg < FRAME_WIDTH) and (v_cntr_reg < FRAME_HEIGHT))else
            '0';

  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      v_sync_dly_reg <= v_sync_reg;
      h_sync_dly_reg <= h_sync_reg;
      vga_red_reg <= vga_red;
      vga_green_reg <= vga_green;
      vga_blue_reg <= vga_blue;
    end if;
  end process;

  VGA_HS_O <= h_sync_dly_reg;
  VGA_VS_O <= v_sync_dly_reg;
  VGA_R <= vga_red_reg;
  VGA_G <= vga_green_reg;
  VGA_B <= vga_blue_reg;
  

end Behavioral;
