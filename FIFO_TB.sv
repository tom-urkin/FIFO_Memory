`timescale 1ns/100ps
//Following TB verifies the Synchronous/Asynchronous FIFO memory operation including reading, writing and FIFO full/empty conditions
module FIFO_TB();

//Parameter declarations
parameter DATA_WIDTH = 8;                //Word width
parameter ADDR_WIDTH = 5;                //FIFO memory depth
parameter SYNCHRONOUS = 0;
parameter ASYNCHRONOUS = 1;
parameter CLK_PERIOD = 20;
//Internal signals declarations
logic Simulated_FIFO_TYPE;              //The same as U1.TYPE, i.e. SYNCHRONOUS or ASYNCHRONOUS FIFO memory

logic wr_clk;                           //Write-side clock
logic wr_rst;                           //Write-side reset
logic [DATA_WIDTH-1:0] data_in;         //Word width - 8-bit word in deafualt settings
logic wr_en;                            //FIFO memory write enable
logic FIFO_full;                        //Memory full indicator (output of the FIFO memory module)
logic [ADDR_WIDTH:0] avail;             //Number of available memory slots - calculated at the 'write' side

logic rd_clk;                           //Read-side clock
logic rd_rst;                           //Read-side reset
logic [DATA_WIDTH-1:0] data_out;        //FIFO memory output
logic rd_en;                            //FIFO memory read enable
logic FIFO_empty;                       //FIFOMemory empty indicator

logic r_w;                              //Randomize read/write command for test #3
integer SEED = 14;                      //Seed for randomization  
integer k;                              //Used in in TB for-loops
integer j;                              //Used in in TB for-loops
integer s;                              //Used in in TB for-loops


logic [DATA_WIDTH-1:0] queue_1 [$];     //Mimicked FIFO memory
logic [DATA_WIDTH-1:0] queue_2 [$];     //Used for verification purposes in the 'compare' task
logic [DATA_WIDTH-1:0] tmp;             //Temporary variable fot the 'popping' operation of the mimicked FIFO memory

logic FIFO_full_tst;                    //FIFO full indicator for the mimicked memory (queue_1)
logic FIFO_full_tst_delayed;            //Delayed version of the 'FIFO_full_tst' used in asynchrnous implementation (synchronization logic)
logic temp_reg_wr;                      //Temporary variable used in the synchronization lofgic of the FIFO_full indicator for the mimicked memory

logic FIFO_empty_tst;                   //FIFO empry indicator for the mimicked memory (queue_1)
logic FIFO_empty_tst_delayed;           //Delayed version of the 'FIFO_full_tst' used in asynchrnous implementation (synchronization logic)
logic temp_reg_rd;                      //Temporary variable used in the synchronization lofgic of the FIFO_full indicator for the mimicked memory

logic FIFO_full_tst_final;              //This signal mimicks the FIFO_memory 'FIFO_full' signal
logic FIFO_empty_tst_final;             //This signal mimicks the FIFO_memory 'FIFO_empty' signal

//Tasks and functions
task compare();  //The 'compare' function performs comparison between the relevant section of the FIFO_memory (which is a function of the read/write pointers) and the mimicked FIFO memory (queue_1)
queue_2={};
//Note: the relevant section is a function of the read/write pointers and its MSB polarity
if (U1.rptr[ADDR_WIDTH-1:0]<U1.wptr[ADDR_WIDTH-1:0])
  for(s=U1.rptr[ADDR_WIDTH-1:0]; s<U1.wptr[ADDR_WIDTH-1:0]; s++)     
    queue_2.push_back(U1.mem[s]);	
if ((U1.rptr[ADDR_WIDTH-1:0]>U1.wptr[ADDR_WIDTH-1:0])||((U1.rptr[ADDR_WIDTH-1:0]==U1.wptr[ADDR_WIDTH-1:0])&&(U1.rptr[ADDR_WIDTH]!=U1.wptr[ADDR_WIDTH]))) begin
  for(s=U1.rptr[ADDR_WIDTH-1:0]; s<2**ADDR_WIDTH; s++)    
    queue_2.push_back(U1.mem[s]);
  for(s=0; s<U1.wptr[ADDR_WIDTH-1:0]; s++)  
    queue_2.push_back(U1.mem[s]);
end
$display("\nThe verification queue at iteration %d  is: %p and the mimicked FIFO memory is: %p", k, queue_2, queue_1);
if (queue_1!=queue_2) begin                                //Comparison of the mimicked FIFO memory (queue_1) and the relevant section of the actual FIFO memory (queue_2)
  $display("Failed on iteration %d", k);
  $display("\nThe verification queue at iteration %d  is: %p and the mimicked FIFO memory is: %p", k, queue_2, queue_1);
  $display("The write pointes is %d and the read pointer is %d", U1.wptr, U1.rptr);
  $finish;
end
endtask

task reset_signals();                                     //This task reset all the queues and relevant signals before each test
queue_1={};
queue_2={};
wr_rst=1'b0;
rd_rst=1'b0;

@(posedge wr_clk)
wr_rst=1'b1;
@(posedge rd_clk)
rd_rst=1'b1;
	
FIFO_empty_tst=1'b1;
FIFO_full_tst=1'b0;	
endtask



//FIFO memory module instantiation
FIFO #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .TYPE(ASYNCHRONOUS)) U1(
                .wr_clk(wr_clk),
                .wr_rst(wr_rst),
                .data_in(data_in),
                .wr_en(wr_en),
                .FIFO_full(FIFO_full),
                .avail(avail),
                .rd_clk(rd_clk),
                .rd_rst(rd_rst),
                .data_out(data_out),
                .rd_en(rd_en),
                .FIFO_empty(FIFO_empty)
                );

//Initial blocks
initial begin
Simulated_FIFO_TYPE=ASYNCHRONOUS;                        //Manually change to match U1.TYPE
wr_rst=1'b0;
rd_rst=1'b0;
wr_clk=1'b0;
rd_clk=1'b0;
rd_en=0;
wr_en=0;
tmp=0;

r_w=0;
@(posedge wr_clk)
  wr_rst=1'b1;
@(posedge rd_clk)
  rd_rst=1'b1;

//----------------------------------------//
//Test #1: Write to FIFO memory
reset_signals();	
$display("Initiate continious writing ('pushing') test\n");

for(k=0; k<(2**ADDR_WIDTH+10); k++) begin            //Continious writing operation
  data_in= $dist_uniform(SEED,0,40);                 //8-bit random number to be written to the FIFO memory
  #1;
  if (!FIFO_full_tst_final)
    queue_1.push_back(data_in);
  else
    $display("Data was not written - FIFO memory is full on iteration %d", k);

  @(posedge wr_clk)
    wr_en=1;                                        //Enabling write operation
  @(posedge wr_clk)
    wr_en=0;
  #1;

  //if (k==7)//Modify the queue manually to make the test fail
  // queue_1[4]=8'd3;

  FIFO_full_tst = (queue_1.size()==2**ADDR_WIDTH);
  FIFO_empty_tst = (queue_1.size()==0);	

  compare();
 end	
 $display("\nWrite test passed!");

//----------------------------------------//
//Test #2: Read from FIFO memory
//Note: The reset task is no used here since this test reads the written values from previous test

$display("\nInitiate continious reading ('popping') test\n");
for(k=0; k<(2**ADDR_WIDTH+5); k++) begin
  #1;
  if (!FIFO_empty_tst_final)
    tmp=queue_1.pop_front();
  else
    $display("\nRead operation not completed on iteration %d - the FIFO memory is empty", k);       

  @(posedge rd_clk)
    rd_en=1;                         //Enabling read operation
  @(posedge rd_clk)
    rd_en=0;
  #1;
 
  //if (k==15)  //Modify the queue manually to make the test fail
  //queue_1[12]=8'd3;  //Modify the queue manually to make the test fail

  FIFO_full_tst = (queue_1.size()==2**ADDR_WIDTH);
  FIFO_empty_tst = (queue_1.size()==0);	

  compare();
end
$display("\nRead test passed!\n");

//----------------------------------------//
//Test #3: Reading and writing from the FIFO memory for 10*FIFO depth times with randomized read/write operations
reset_signals();
$display("Initiate 3rd test - randomly reading/writing random values\n");

for(k=0; k<2**ADDR_WIDTH*17; k++) begin
  r_w= $dist_uniform(SEED,0,1)==1;                 //randomizing read/write operation. '0' for read and '1' for write operation. Modify the condition to use different probabilties.       
  data_in= $dist_uniform(SEED,0,40);               //8-bit random number to be written to the FIFO memory
  if (r_w==0) begin                                //Write operation
    #1;
    if (!FIFO_full_tst_final)
      queue_1.push_back(data_in);	

      @(posedge wr_clk)
        wr_en=1;                                   //Enabling write operation
      @(posedge wr_clk)
        wr_en=0;
    #1;
  end
  else begin //Read operation
    #1;
    if (!FIFO_empty_tst_final)
      tmp=queue_1.pop_front();

    @(posedge rd_clk)
      rd_en=1;                                     //Enabling read operation
    @(posedge rd_clk)
      rd_en=0;
    #1;
  end

  FIFO_full_tst = (queue_1.size()==2**ADDR_WIDTH);
  FIFO_empty_tst = (queue_1.size()==0);

  compare();	
end

//Visual data for the last iteration (terminal view)
//Print the entire FIFO memory
$display("\nIn the last iteration the write pointer equals %d and the read pointer equals %d", U1.wptr, U1.rptr);
$display("The FIFO memory is :");
for(j=0; j<2**ADDR_WIDTH; j++)        
  $write("%d ", U1.mem[j]);
//Print the relevant section of the FIFO memory
if (U1.rptr[ADDR_WIDTH-1:0]<U1.wptr[ADDR_WIDTH-1:0])
$display("\nThe relevant section of the FIFO memory is from %d to %d:", U1.rptr[ADDR_WIDTH-1:0], U1.wptr[ADDR_WIDTH-1:0]-1);
for(s=U1.rptr[ADDR_WIDTH-1:0]; s<U1.wptr[ADDR_WIDTH-1:0]; s++)     
  $write("%d ", U1.mem[s]);

if (U1.rptr[ADDR_WIDTH-1:0]>U1.wptr[ADDR_WIDTH-1:0]) begin
  $display("\nThe relevant section of the FIFO memory is from %d to the end of memory and from begining of memory to %d:", U1.wptr[ADDR_WIDTH-1:0]-1, U1.rptr[ADDR_WIDTH-1:0]);	
for(s=U1.rptr[ADDR_WIDTH-1:0]; s<2**ADDR_WIDTH; s++)    
  $write("%d ", U1.mem[s]);
for(s=0; s<U1.wptr[ADDR_WIDTH-1:0]; s++)  
  $write("%d ", U1.mem[s]);
end
$display("\nThe queue at the last iteration is: %p", queue_1);
$display("The verification queue at the last iteration is: %p\n", queue_2);	

$display("Test 3 completed successfully\n");
$display("\nSynchronous FIFO memory tests completed successfully");
$finish;

end

//TB HDL code

always @(posedge wr_clk or negedge wr_rst)
  if (!wr_rst)
    {FIFO_full_tst_delayed,temp_reg_wr}<={1'b0,1'b0};
  else
    {FIFO_full_tst_delayed,temp_reg_wr}<={temp_reg_wr,FIFO_full_tst};

always @(posedge rd_clk or negedge rd_rst)
  if (!rd_rst)
    {FIFO_empty_tst_delayed,temp_reg_rd}<={1'b1,1'b1};
  else
    {FIFO_empty_tst_delayed,temp_reg_rd}<={temp_reg_rd,FIFO_empty_tst};	

assign FIFO_full_tst_final = (Simulated_FIFO_TYPE==ASYNCHRONOUS) ? (FIFO_full_tst_delayed||FIFO_full_tst) : FIFO_full_tst;
assign FIFO_empty_tst_final = (Simulated_FIFO_TYPE==ASYNCHRONOUS) ? (FIFO_empty_tst_delayed||FIFO_empty_tst) : FIFO_empty_tst;


//Clock generation
always
begin
#(CLK_PERIOD/2);
wr_clk=~wr_clk;
//rd_clk=~rd_clk;
end

always
begin
#(CLK_PERIOD/3);
rd_clk=~rd_clk;
end

endmodule
