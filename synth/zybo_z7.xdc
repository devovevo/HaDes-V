## ----------------------------------------------------------------------------
## HACK XDC FOR ZYBO Z7 (HaDes-V Compatibility)
## ----------------------------------------------------------------------------

## 1. CLOCK (CRITICAL: Change Clock Wizard Input to 125 MHz!)
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports {clk_100mhz}]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports {clk_100mhz}]

## 2. REAL SWITCHES (Switches 0-3 mapped to actual hardware)
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports {switches_async[0]}]
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports {switches_async[1]}]
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports {switches_async[2]}]
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports {switches_async[3]}]

## 3. GHOST SWITCHES (Switches 4-15 mapped to Pmod JB to satisfy Vivado)
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports {switches_async[4]}]
set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports {switches_async[5]}]
set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports {switches_async[6]}]
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports {switches_async[7]}]
set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports {switches_async[8]}]
set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports {switches_async[9]}]
set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports {switches_async[10]}]
set_property -dict { PACKAGE_PIN W6    IOSTANDARD LVCMOS33 } [get_ports {switches_async[11]}]
# Mapping remaining switches to Pmod JC
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {switches_async[12]}]
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {switches_async[13]}]
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports {switches_async[14]}]
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports {switches_async[15]}]

## 4. REAL LEDS (LEDs 0-3 mapped to actual hardware)
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports {leds[0]}]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports {leds[1]}]
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports {leds[2]}]
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports {leds[3]}]

## 5. GHOST LEDS (LEDs 4-15 mapped to Pmod JD)
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports {leds[4]}]
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports {leds[5]}]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports {leds[6]}]
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports {leds[7]}]
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports {leds[8]}]
set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports {leds[9]}]
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports {leds[10]}]
set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports {leds[11]}]
# Overflow to Pmod JE
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports {leds[12]}]
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports {leds[13]}]
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports {leds[14]}]
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports {leds[15]}]

## 6. BUTTONS (Real buttons)
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports {buttons_async[0]}]
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports {buttons_async[1]}]
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports {buttons_async[2]}]
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports {buttons_async[3]}]
# Missing button 5 mapped to Pmod JE pin
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports {buttons_async[4]}]

## 7. GHOST 7-SEGMENT DISPLAY (Mapped to Pmod JA)
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports {segments[0]}]
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports {segments[1]}]
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports {segments[2]}]
set_property -dict { PACKAGE_PIN K14   IOSTANDARD LVCMOS33 } [get_ports {segments[3]}]
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports {segments[4]}]
set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports {segments[5]}]
set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports {segments[6]}]
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports {segments[7]}]

set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports {segments_select[0]}] ;# JD unused
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports {segments_select[1]}] ;# JD unused
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports {segments_select[2]}] ;# JD unused
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports {segments_select[3]}] ;# JD unused

## 8. GHOST VGA (Mapped to Header JC and others if needed)
## We are just dumping these to satisfy the constraint requirement.
## Since VGA has many pins, we reuse some Pmod pins. 
## WARNING: Do not connect a VGA monitor or Pmods while using this bitstream.

set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {vga_red[0]}]
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {vga_red[1]}]
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports {vga_red[2]}]
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports {vga_red[3]}]

set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports {vga_blue[0]}]
set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS33 } [get_ports {vga_blue[1]}]
set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports {vga_blue[2]}]
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports {vga_blue[3]}]

set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports {vga_green[0]}]
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports {vga_green[1]}]
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports {vga_green[2]}]
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports {vga_green[3]}]

set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports {vga_hsync}]
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports {vga_vsync}]


## 9. CONFIGURATION (Standard)
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]