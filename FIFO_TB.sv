`timescale 1ns/100ps
//Following TB verifies the Synchronous_FIFO operation including reading, writing and FIFO full/empty conditions
module FIFO_TB();

//Parameter declarations

parameter DATA_WIDTH = 8;                        //Word width
parameter ADDR_WIDTH = 5;                        //FIFO memory depth
parameter SYNCHRONOUS = 0;
parameter CLK_PERIOD = 20;
//Internal signals declarations
logic clk;
logic rst;
logic [DATA_WIDTH-1:0] data_in;
logic [DATA_WIDTH-1:0] data_out;
logic FIFO_empty;								//Memory empty indicator
logic FIFO_full;								//Memory full indicator
logic wr_en;									//FIFO memory write enable
logic rd_en;									//FIFO memory read enable
logic r_w;										//Randomize read/write command for test #3
logic [ADDR_WIDTH-1:0] wptr;					//FIFO write pointer used in test #3
logic [ADDR_WIDTH-1:0] rptr;					//FIFO read pointer used in test #3
integer k;

//FIFO memory module instantiation
FIFO #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .TYPE(SYNCHRONOUS)) U1(
                .clk(clk),
                .rst(rst),
                .data_in(data_in),
                .data_out(data_out),
                .FIFO_empty(FIFO_empty),
                .FIFO_full(FIFO_full),
                .wr_en(wr_en),
                .rd_en(rd_en)
                );

//Initial blocks
initial
begin
    rst=1'b0;
    clk=1'b0;
    rd_en=0;
    wr_en=0;
	r_w=0;
	wptr=0;
	rptr=0;
    @(posedge clk)
    rst=1'b1;
    @(posedge clk)

    //----------------------------------------//
    //Test #1: Writing to the FIFO memory until full. Verify correctness of the writeen data and observe the FIFO_full signal
    for(k=0; k<(2**ADDR_WIDTH+5); k++)        //
        begin
        data_in= $random%8;                  //8-bit random number to be written to the FIFO memory
        @(posedge clk)
        wr_en=1;                             //Enabling write operation
        @(posedge clk)
        wr_en=0;
        #1;
        if (U1.mem[k] == data_in)
			begin
            $display("Data written is %b data stored in memory is %b on iteration number %d- success",data_in,U1.mem[k],k);
			$display("Remaning memory slots : %d", U1.avail);
			end
        else if (FIFO_full==1)
            $display("The FIFO memory is full - write operation was not completed on iteraion %d", k);
        else
            begin
                $display("Data written is %b data stored in memory is %b on iteration %d- write oepartion failed",data_in,U1.mem[k],k);
                $finish;
            end

        end

    $display("\nTest 1 completed successfully\n");

    //----------------------------------------//
    //Test #2: Reading from the FIFO memory until it is empty. Verify correctness of the read data and observe the FIFO_empty signal

    for(k=0; k<(2**ADDR_WIDTH+5); k++)    //
        begin
        @(posedge clk)
        rd_en=1;                         //Enabling read operation
        @(posedge clk)
        rd_en=0;
        #1;
        if (U1.mem[k] == data_out)
			begin
            $display("Data read is %b data stored in memory is %b on iteration number %d- success",data_out,U1.mem[k],k);
			$display("Remaning memory slots : %d", U1.avail);
			end
        else if (FIFO_empty==1)
            $display("The FIFO memory is empty - read operation was not completed on iteraion %d", k);
        else
            begin
                $display("Data read is %b data stored in memory is %b on iteration %d- read oepartion failed",data_out,U1.mem[k],k);
                $finish;
            end

        end

    $display("\nTest 2 completed successfully\n");

    //----------------------------------------//
    //Test #3: Reading and writing from the FIFO memory for 10*FIFO depth times with randomized read/write operations
    for(k=0; k<(2**ADDR_WIDTH*10); k++)       
        begin
		r_w= {$random}%2;                      //randomizing read/write operation. '0' for read and '1' for write operation.	
        data_in= $random%8;                    //8-bit random number to be written to the FIFO memory
		if (r_w==0)							   //Write operation
			begin
				wptr=U1.wptr[ADDR_WIDTH-1:0];
				@(posedge clk)
				wr_en=1;                     //Enabling write operation
				@(posedge clk)
				wr_en=0;
				#1
				if (FIFO_full==1)
					begin
					$display("\nThe FIFO memory is full - write operation was not completed on iteraion %d", k);
					$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
					$display("Remaning memory slots : %d", U1.avail);
					end
				else if (U1.mem[wptr] == data_in)
					begin
					$display("\nData written is %b data stored in memory is %b on iteration number %d- success",data_in,U1.mem[wptr],k);
					$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
					$display("Remaning memory slots : %d", U1.avail);
					end
				else
					begin
						$display("Data written is %b data stored in memory is %b on iteration %d- write oepartion failed",data_in,U1.mem[wptr],k);
						$finish;
					end
			end
		else
			begin							//Read operation
				rptr=U1.rptr[ADDR_WIDTH-1:0];
				@(posedge clk)
				rd_en=1;					
				@(posedge clk)
				rd_en=0;
				#1;	
				if (U1.mem[rptr] == data_out)
					begin
					$display("\nData read is %b data stored in memory is %b on iteration number %d- success",data_out,U1.mem[rptr],k);
					$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
					$display("Remaning memory slots : %d", U1.avail);
					end
				else if (FIFO_empty==1)
				begin
					$display("\nThe FIFO memory is empty - read operation was not completed on iteraion %d", k);
					$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
					$display("Remaning memory slots : %d", U1.avail);
				end
				else
					begin
						$display("Data read is %b data stored in memory is %b on iteration %d- read oepartion failed",data_out,U1.mem[rptr],k);
						$finish;
					end				
			end


        end

    $display("\nTest 3 completed successfully\n");

    $display("Synchronous FIFO memory tests completed successfully");
    $finish;

end

//Clock generation (50MHz)
always
begin
#(CLK_PERIOD/2);
clk=~clk;
end


endmodule
