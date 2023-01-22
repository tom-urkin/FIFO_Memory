//Synchronous and Asynchronous FIFO memory

//Sub-modules 
module counter(rst,clk,en,count);
//Parameter declerations
parameter LENGTH_COUNTER = 5;
//Input declerations
input logic rst;
input logic clk;
input logic en;
//Output declerations
output logic [LENGTH_COUNTER:0] count;

//HDL code
always @(posedge clk or negedge rst)
  if (!rst)
    count<='0;
  else if (en)
    count<=count+$bits(count)'('d1);	
endmodule

module synchronizer(rst,clk,in,out);
//Parameter declerations 
parameter LENGTH = 5;
//Input declerations
input logic rst;
input logic clk;
input logic [LENGTH:0] in;
//Output declerations 
output logic [LENGTH:0] out;
//Internal signals
logic [LENGTH:0] temp_reg;

//HDL code
always @(posedge clk or negedge rst)					
  if (!rst)
    {out,temp_reg}<={($bits(out))'('d0),($bits(temp_reg))'('d0)};
  else
    {out,temp_reg}<={temp_reg,in};		
endmodule


module FIFO(wr_clk,wr_rst,data_in,wr_en,FIFO_full,avail, rd_clk,rd_rst,data_out,rd_en,FIFO_empty);

//Parameters
parameter DATA_WIDTH = 8;                                     //Word width - 8-bit word in deafualt settings
parameter ADDR_WIDTH = 5;                                     //FIFO memory depth - 32 words in default settings
parameter TYPE = 0;                                           //FIFO memory type: Synchronous ('0') or Asynchronous ('1')

//Inputs
input logic wr_clk;                                           //Write-side clock
input logic wr_rst;                                           //Write-side asynchronous reset
input logic [(DATA_WIDTH-1):0] data_in;                       //Input data to be written
input logic wr_en;                                            //Write request from external logic

input logic rd_clk;                                           //Read-side clock
input logic rd_rst;                                           //Read-side asynchronous reset
input logic rd_en;                                            //Read request from external logic

//Outputs
output logic FIFO_empty;                                    //Logic high when the FIFO memory is empty - calculated at the 'read' side
output logic FIFO_full;                                     //Logic high when the FIFO memory is full - calculated at the 'write' side
output logic [(DATA_WIDTH-1):0] data_out;                   //FIFO memory output
output logic [ADDR_WIDTH:0] avail;                          //Number of available memory slots - calculated at the 'write' side

//Internal signals
logic [ADDR_WIDTH:0] rptr;                                  //Read pointer in the 'read' domain
logic [ADDR_WIDTH:0] wptr;                                  //Write pointer in the 'write'domain
logic [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH-1):0];           //FIFO memory registers (32 8-bit words in defaults settings)

logic [ADDR_WIDTH:0] rgray;											//Gray-code equivalent of the read pointer
logic [ADDR_WIDTH:0] wgray;											//Gray-code equivalent of the write pointer

logic [ADDR_WIDTH:0] w_ff1_rgray;									//Two-flop synchronization to capture the gray-coded read pointer
logic [ADDR_WIDTH:0] w_ff2_rgray;									//Two-flop synchronization to capture the gray-coded read pointer

logic [ADDR_WIDTH:0] r_ff1_wgray;									//Two-flop synchronization to capture the gray-coded write pointer
logic [ADDR_WIDTH:0] r_ff2_wgray;									//Two-flop synchronization to capture the gray-coded write pointer

logic [ADDR_WIDTH:0] binary_w_ff2_rgray;

integer i;                                                   //Used for reseting the FIFO memory

//HDL code

generate
  if (TYPE==0)	begin //Synchronous FIFO memory. wr_clk and rd_clk are the same in synchronous implementation (so are the reset signals).
    counter #(.LENGTH_COUNTER(ADDR_WIDTH)) counter_w(.rst(wr_rst), .clk(wr_clk), .en(((~FIFO_full)&&(wr_en))), .count(wptr));
    counter #(.LENGTH_COUNTER(ADDR_WIDTH)) counter_r(.rst(wr_rst), .clk(wr_clk), .en(((~FIFO_empty)&&(rd_en))), .count(rptr));
		
    always @(posedge wr_clk or negedge wr_rst)
      if (!wr_rst) begin
        for (i=0; i<(2**ADDR_WIDTH); i=i+1)	//Reseting the FIFO memory
          mem[i]<='0;
        data_out<='0;
      end
      else if ((~FIFO_full)&&(wr_en))  //Write operation	
        mem[wptr[ADDR_WIDTH-1:0]]<=data_in;	
      else if ((~FIFO_empty)&&rd_en)   //Read operation
        data_out<=mem[rptr[ADDR_WIDTH-1:0]];
	
    assign FIFO_empty = (wptr==rptr) ? 1'b1 : 1'b0;  //If the pointers are equal there is no new data to be read
    assign FIFO_full = ({~wptr[ADDR_WIDTH],wptr[ADDR_WIDTH-1:0]}==rptr) ? 1'b1 : 1'b0;  //If the (ADDR_WIDTH-1) LSB bits are equal and the MSB is with reversed polarity, the FIFO memory is full
    assign avail = $bits(wptr)'(2**ADDR_WIDTH) - (wptr-rptr);  //Number of unwritten memory slots
  end
		
  else begin  //Asynchronous FIFO memory
  //Write-side logic
    counter #(.LENGTH_COUNTER(ADDR_WIDTH)) counter_w(.rst(wr_rst), .clk(wr_clk), .en(((~FIFO_full)&&(wr_en))), .count(wptr));
    always @(posedge wr_clk or negedge wr_rst)
      if (!wr_rst)
        for (i=0; i<(2**ADDR_WIDTH); i=i+1)
          mem[i]<='0;	
      else if ((~FIFO_full)&&(wr_en))
        mem[wptr[ADDR_WIDTH-1:0]]<=data_in;

    assign wgray = wptr^(wptr>>1);  //Converting write pointer to its gray-code equivalent
    synchronizer #(.LENGTH(ADDR_WIDTH)) synchronizer_w (.rst(wr_rst),.clk(wr_clk),.in(rgray),.out(w_ff2_rgray));  //Capture gray-coded read pointer
    assign FIFO_full = (~wgray[ADDR_WIDTH-:2]==w_ff2_rgray[ADDR_WIDTH-:2])&&(wgray[ADDR_WIDTH-2:0]==w_ff2_rgray[ADDR_WIDTH-2:0]);																	
			
    always @(*) begin //Convert from Gray to Binary
      binary_w_ff2_rgray='0;
      for (i=0; i<(ADDR_WIDTH+1); i=i+1) 
        if (i==0)
          binary_w_ff2_rgray[ADDR_WIDTH]=w_ff2_rgray[ADDR_WIDTH];
        else
          binary_w_ff2_rgray[ADDR_WIDTH-i]=binary_w_ff2_rgray[ADDR_WIDTH-i+1]^w_ff2_rgray[ADDR_WIDTH-i];
    end				
    assign avail=2**ADDR_WIDTH-(wptr-binary_w_ff2_rgray);  //Number of unwritten memory slots			
  //Read-side logic		
    counter #(.LENGTH_COUNTER(ADDR_WIDTH)) counter_r(.rst(rd_rst), .clk(rd_clk), .en(((~FIFO_empty)&&(rd_en))), .count(rptr));
	
    always @(posedge rd_clk or negedge rd_rst)
      if (!rd_rst)
        data_out<='0;
      else if ((rd_en)&&(!FIFO_empty))
        data_out<=mem[rptr[ADDR_WIDTH-1:0]];
		  
    assign rgray = rptr^(rptr>>1);  //Converting read pointer to its gray-code equivalent					    
    synchronizer #(.LENGTH(ADDR_WIDTH)) synchronizer_r (.rst(rd_rst),.clk(rd_clk),.in(wgray),.out(r_ff2_wgray)); //Capture gray-coded write pointer
    assign FIFO_empty = (r_ff2_wgray==rgray);						//FIFO-empty calculation		
	 
  end
		
endgenerate

endmodule
