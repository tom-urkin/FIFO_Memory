//Synchronous and Asynchronous FIFO memory

module FIFO(wr_clk,wr_rst,data_in,wr_en,FIFO_full,avail, rd_clk,rd_rst,data_out,rd_en,FIFO_empty);

//Parameters
parameter DATA_WIDTH = 8;                                     //Word width - 8-bit word in deafualt settings
parameter ADDR_WIDTH = 5;                                     //FIFO memory depth - 32 words in default settings
parameter TYPE = 1;                                           //FIFO memory type: Synchronous ('0') or Asynchronous ('1')

//Inputs
input logic wr_clk;                                           //Write-side clock
input logic wr_rst;                                           //Write-side asynchronous reset
input logic [(DATA_WIDTH-1):0] data_in;                       //Input data to be written
input logic wr_en;                                            //Write request from external logic

input logic rd_clk;                                           //Read-side clock
input logic rd_rst;                                           //Read-side asynchronous reset
input logic rd_en;                                            //Read request from external logic

//Outputs
output logic FIFO_empty;                                      //Logic high when the FIFO memory is empty - calculated at the 'read' side
output logic FIFO_full;                                       //Logic high when the FIFO memory is full - calculated at the 'write' side
output logic [(DATA_WIDTH-1):0] data_out;                     //FIFO memory output
output logic [ADDR_WIDTH:0] avail;                            //Number of available memory slots - calculated at the 'write' side

//Internal signals
logic [ADDR_WIDTH:0] rptr;                                    //Read pointer in the 'read' domain
logic [ADDR_WIDTH:0] wptr;                                    //Write pointer in the 'write'domain
logic [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH-1):0];             //FIFO memory registers (32 8-bit words in defaults settings)

logic [ADDR_WIDTH:0] rgray;                                   //Gray-code equivalent of the read pointer
logic [ADDR_WIDTH:0] wgray;                                   //Gray-code equivalent of the write pointer

logic [ADDR_WIDTH:0] w_ff1_rgray;                             //Two-flop synchronization to capture the gray-coded read pointer
logic [ADDR_WIDTH:0] w_ff2_rgray;                             //Two-flop synchronization to capture the gray-coded read pointer

logic [ADDR_WIDTH:0] r_ff1_wgray;                             //Two-flop synchronization to capture the gray-coded write pointer
logic [ADDR_WIDTH:0] r_ff2_wgray;                             //Two-flop synchronization to capture the gray-coded write pointer

logic [ADDR_WIDTH:0] binary_w_ff2_rgray;

integer i;                                                   //Used for reseting the FIFO memory

//HDL code

generate
	if (TYPE==0)                                             //Synchronous FIFO memory
		begin
		always @(posedge wr_clk or negedge wr_rst)       //wr_clk and rd_clk are the same in synchronous omplementation
			if (!wr_rst)                                                //Reseting the FIFO memory
				begin
				for (i=0; i<(2**ADDR_WIDTH); i=i+1)
				mem[i]<=0;
				wptr<=0;
				end
			else
			if ((~FIFO_full)&&(wr_en))                            //Write operation
				begin
				mem[wptr[ADDR_WIDTH-1:0]]<=data_in;
				wptr<=wptr+1;
				end

		always @(posedge wr_clk or negedge wr_rst)
			if (!wr_rst)
				begin
				rptr<=0;
				data_out<='d0;
				end
			else
			if ((~FIFO_empty)&&rd_en)                            //Read operation
				begin
				data_out<=mem[rptr[ADDR_WIDTH-1:0]];
				rptr<=rptr+1;
				end

		assign FIFO_empty = (wptr==rptr) ? 1'b1 : 1'b0;                                       //If the pointers are equal there is no new data to be read
		assign FIFO_full = ({~wptr[ADDR_WIDTH],wptr[ADDR_WIDTH-1:0]}==rptr) ? 1'b1 : 1'b0;    //If the (ADDR_WIDTH-1) LSB bits are equal and the MSB is with reversed polarity, the FIFO memory is full
		assign avail = 2**ADDR_WIDTH - (wptr-rptr);                                           //Number of available memory slots
		end
		
	else                                                        //Asynchronous FIFO memory
		begin
			//Write-side logic
			always @(posedge wr_clk or negedge wr_rst)
				if (!wr_rst)
					begin
					for (i=0; i<(2**ADDR_WIDTH); i=i+1)
					mem[i]<=0;
					wptr<=0;
					end
				else if ((~FIFO_full)&&(wr_en))
					begin
					mem[wptr[ADDR_WIDTH-1:0]]<=data_in;
					wptr<=wptr+1;
					end
					
			assign wgray = wptr^(wptr>>1);                      //Converting write pointer to its gray-code equivalent
			
			always @(posedge wr_clk or negedge wr_rst)           //Capture gray-coded read pointer
				if (!wr_rst)
				{w_ff2_rgray,w_ff1_rgray}<={{ADDR_WIDTH{1'b0}},{ADDR_WIDTH{1'b0}}};
				else
				{w_ff2_rgray,w_ff1_rgray}<={w_ff1_rgray,rgray};
			
			assign FIFO_full = (~wgray[ADDR_WIDTH-:2]==w_ff2_rgray[ADDR_WIDTH-:2])&&(wgray[ADDR_WIDTH-2:0]==w_ff2_rgray[ADDR_WIDTH-2:0]);																	
			
			//Calculate available memory slots in the write domain
			always @(*)	begin                                           //Convert from Gray to Binary
			binary_w_ff2_rgray=0;
			for (i=0; i<(ADDR_WIDTH+1); i=i+1) 
				if (i==0)
				binary_w_ff2_rgray[ADDR_WIDTH]=w_ff2_rgray[ADDR_WIDTH];
				else
				binary_w_ff2_rgray[ADDR_WIDTH-i]=binary_w_ff2_rgray[ADDR_WIDTH-i+1]^w_ff2_rgray[ADDR_WIDTH-i];
			end
				
			assign avail=2**ADDR_WIDTH-(wptr-binary_w_ff2_rgray);       //Number of unwritten memory slots
			
			//Read-side logic
			always @(posedge rd_clk or negedge rd_rst)
				if (!rd_rst)
					begin
					rptr<=0;
					data_out<=0;
					end
				else if ((rd_en)&&(!FIFO_empty))
					begin
					rptr<=rptr+1;
					data_out<=mem[rptr[ADDR_WIDTH-1:0]];
					end
					
			assign rgray = rptr^(rptr>>1);                            //Converting read pointer to its gray-code equivalent
			
			always @(posedge rd_clk or negedge rd_rst)                //Capture gray-coded write pointer
				if (!rd_rst)
				{r_ff2_wgray,r_ff1_wgray}={{ADDR_WIDTH{1'b0}},{ADDR_WIDTH{1'b0}}};
				else
				{r_ff2_wgray,r_ff1_wgray}={r_ff1_wgray,wgray};
					
			assign FIFO_empty = (r_ff2_wgray==rgray);                   //FIFO-empty calculation
			
		end
		
endgenerate


endmodule
