
set dev "nano20k"

# add_file src/tang_nano_20k/config.sv
add_file src/tang_nano_20k/gowin_pll_hdmi.v
add_file src/tang_nano_20k/gowin_pll_usb.v
add_file -type cst "src/tang_nano_20k/nestang.cst"
add_file -type sdc "src/tang_nano_20k/nestang.sdc"

set_option -use_sspi_as_gpio 1
set_option -ireg_in_iob 0
set_option -oreg_in_iob 0
set_option -ioreg_in_iob 0

source build.tcl
