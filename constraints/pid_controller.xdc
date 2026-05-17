##==============================================================
## pid_controller.xdc
## EDGE Artix 7 FPGA Board Constraints
## PID Controller — Disturbance Demo
##==============================================================
## Port mapping (our top.v signal → EDGE board peripheral):
##   clk        → 50 MHz oscillator (N11)
##   rst_btn    → pb[4] CENTER button (M14)
##   btn[0]     → pb[0] TOP    button (+10 setpoint)
##   btn[1]     → pb[1] BOTTOM button (-10 setpoint)
##   btn[2]     → pb[2] LEFT   button (-1  setpoint)
##   btn[3]     → pb[3] RIGHT  button (+1  setpoint)
##   sw[15:0]   → 16 slide switches
##   led[15:0]  → 16 LEDs (control_signal bar graph)
##   seg[6:0]   → Seven_Seg[6:0] (A..G cathodes, active low)
##   dp         → Seven_Seg[7]   (decimal point,  active low)
##   an[3:0]    → digit[3:0]     (digit anodes,   active low)
##   pwm_out    → Buzzer pin     (K12, PWM drives piezo)
##   uart_tx    → usb_uart_txd   (C4,  115200 baud to PC)
##==============================================================

##------------------------------------------------------------
## Clock — 100 MHz on-board oscillator
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN N11 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 20.000 -waveform {0 10} [get_ports { clk }];

##------------------------------------------------------------
## Reset — CENTER push button (pb[4], active high)
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { rst_btn }];

##------------------------------------------------------------
## Buttons (active high with PULLDOWN)
##   btn[0] = TOP    (+10)
##   btn[1] = BOTTOM (-10)
##   btn[2] = LEFT   (-1)
##   btn[3] = RIGHT  (+1)
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { btn[0] }];
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { btn[1] }];
set_property -dict { PACKAGE_PIN M12 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { btn[2] }];
set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { btn[3] }];

##------------------------------------------------------------
## Switches (16 total)
##   sw[7:0]  = disturbance injection (0=none, 255=maximum)
##   sw[11:8] = Kp preset (4-bit)
##   sw[13:12]= Ki preset (2-bit)
##   sw[15:14]= Kd preset (2-bit)
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN L5 IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN L4 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN M4 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS33 } [get_ports { sw[4] }];
set_property -dict { PACKAGE_PIN N3 IOSTANDARD LVCMOS33 } [get_ports { sw[5] }];
set_property -dict { PACKAGE_PIN N2 IOSTANDARD LVCMOS33 } [get_ports { sw[6] }];
set_property -dict { PACKAGE_PIN N1 IOSTANDARD LVCMOS33 } [get_ports { sw[7] }];
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports { sw[8] }];
set_property -dict { PACKAGE_PIN P4 IOSTANDARD LVCMOS33 } [get_ports { sw[9] }];
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS33 } [get_ports { sw[10] }];
set_property -dict { PACKAGE_PIN R8 IOSTANDARD LVCMOS33 } [get_ports { sw[11] }];
set_property -dict { PACKAGE_PIN N6 IOSTANDARD LVCMOS33 } [get_ports { sw[12] }];
set_property -dict { PACKAGE_PIN T7 IOSTANDARD LVCMOS33 } [get_ports { sw[13] }];
set_property -dict { PACKAGE_PIN P8 IOSTANDARD LVCMOS33 } [get_ports { sw[14] }];
set_property -dict { PACKAGE_PIN M6 IOSTANDARD LVCMOS33 } [get_ports { sw[15] }];

##------------------------------------------------------------
## LEDs (16 total) — control_signal bar graph
##   More LEDs lit = PID working harder (fighting disturbance)
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN H3  IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { led[7] }];
set_property -dict { PACKAGE_PIN K5  IOSTANDARD LVCMOS33 } [get_ports { led[8] }];
set_property -dict { PACKAGE_PIN P6  IOSTANDARD LVCMOS33 } [get_ports { led[9] }];
set_property -dict { PACKAGE_PIN R7  IOSTANDARD LVCMOS33 } [get_ports { led[10] }];
set_property -dict { PACKAGE_PIN R6  IOSTANDARD LVCMOS33 } [get_ports { led[11] }];
set_property -dict { PACKAGE_PIN T5  IOSTANDARD LVCMOS33 } [get_ports { led[12] }];
set_property -dict { PACKAGE_PIN R5  IOSTANDARD LVCMOS33 } [get_ports { led[13] }];
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[14] }];
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { led[15] }];

##------------------------------------------------------------
## 7-Segment Display
## seg[6:0] maps to Seven_Seg[A..G] cathodes (active low)
## seg[0]=A  seg[1]=B  seg[2]=C  seg[3]=D
## seg[4]=E  seg[5]=F  seg[6]=G
## dp = decimal point (active low, used as digit separator)
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports { seg[0] }];
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } [get_ports { seg[1] }];
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports { seg[2] }];
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports { seg[3] }];
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } [get_ports { seg[4] }];
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 } [get_ports { seg[5] }];
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports { seg[6] }];
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } [get_ports { dp }];

## Digit anodes: an[0]=rightmost digit, an[3]=leftmost digit
set_property -dict { PACKAGE_PIN F2 IOSTANDARD LVCMOS33 } [get_ports { an[0] }];
set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports { an[1] }];
set_property -dict { PACKAGE_PIN G5 IOSTANDARD LVCMOS33 } [get_ports { an[2] }];
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 } [get_ports { an[3] }];

##------------------------------------------------------------
## PWM Output — Buzzer pin (K12)
## Connects directly to the on-board piezo buzzer.
## At 390 kHz PWM carrier it will buzz at full volume when
## control_signal > 0. You will hear the PID working!
## To use silently: connect an LED or oscilloscope probe here.
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN K12 IOSTANDARD LVCMOS33 } [get_ports { pwm_out }];

##------------------------------------------------------------
## UART TX — USB UART (C4) → connect to PC at 115200 baud
## Output: "SP=NNN,PO=NNN,CT=NNN\r\n" every 100 ms
##------------------------------------------------------------
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];

##------------------------------------------------------------
## Timing Constraints
##------------------------------------------------------------
## Async inputs (buttons/switches) go through synchronizers
## in RTL — mark as false paths
set_false_path -from [get_ports { btn[*] }];
set_false_path -from [get_ports { sw[*] }];
set_false_path -from [get_ports { rst_btn }];

## Outputs are non-timing-critical relative to external world
set_output_delay -clock sys_clk_pin -max 4.0 [get_ports { pwm_out }];
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports { pwm_out }];
set_output_delay -clock sys_clk_pin -max 4.0 [get_ports { uart_tx }];
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports { uart_tx }];
