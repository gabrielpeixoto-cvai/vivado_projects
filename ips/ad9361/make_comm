####################################################################################
####################################################################################
# Generate the AD 9361 communication IP
####################################################################################
####################################################################################

M_DEPS := ad9361_comm.tcl
M_DEPS += src/ad_iobuf.v
M_DEPS += src/ad9361comm_top.v

M_VIVADO := vivado -mode batch -source

M_FLIST := *.cache
M_FLIST += *.data
M_FLIST += *.xpr
M_FLIST += *.log
M_FLIST += component.xml
M_FLIST += *.jou
M_FLIST +=  xgui
M_FLIST += .Xil


.PHONY: all clean clean-all
all: ad9361_comm.xpr


clean:clean-all


clean-all:
	rm -rf $(M_FLIST)


ad9361_comm.xpr: $(M_DEPS)
	rm -rf $(M_FLIST)
	$(M_VIVADO) ad9361_comm.tcl  >> ad9361_comm.log 2>&1

####################################################################################
####################################################################################
