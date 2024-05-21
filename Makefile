all: nestang.fs

nestang.synth.json: v.nestang.ys
	yosys -s v.nestang.ys > synth.log.txt

nestang.pnr.json: nestang.synth.json
	nextpnr-himbaechel --json nestang.synth.json --write nestang.pnr.json --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=src/tang_nano_20k/nestang.withsdram.cst

nestang.fs: nestang.pnr.json
	gowin_pack --mspi_as_gpio --ready_as_gpio --done_as_gpio  -d GW2A-18C -o nestang.fs nestang.pnr.json

clean:
	rm  -f nestang.synth.json nestang.pnr.json nestang.fs 


controls: controls.fs

controls.synth.json: controller.ys
	yosys -s controller.ys > controls_synth.log

controls.pnr.json: controls.synth.json
	nextpnr-himbaechel --json controls.synth.json --write controls.pnr.json --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=src/tang_nano_20k/nestang.withsdram.cst

controls.fs: controls.pnr.json
	gowin_pack --mspi_as_gpio --ready_as_gpio --done_as_gpio  -d GW2A-18C -o controls.fs controls.pnr.json

clean_controls:
	rm -f controls.pnr.json controls.fs controls.synth.json 

