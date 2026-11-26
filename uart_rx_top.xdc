# ACX720-V3  xc7a35tfgg484-2
# 串口回环用到的管脚

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# 时钟 50MHz
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports Clk]
create_clock -period 20.000 -name sys_clk [get_ports Clk]

# 复位，S4 按键，低电平有效
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS33} [get_ports Rst_n]

# 串口：J21 是电脑发过来的，M15 是发回电脑的
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS33} [get_ports Uart_Rx]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports Uart_Tx]

# LED0~LED3
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports {Led[0]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33} [get_ports {Led[1]}]
set_property -dict {PACKAGE_PIN L21 IOSTANDARD LVCMOS33} [get_ports {Led[2]}]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS33} [get_ports {Led[3]}]
