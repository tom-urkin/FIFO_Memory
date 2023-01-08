`timescale 1ns/100ps
//Following TB verifies the Synchronous/Asynchronous FIFO memory operation including reading, writing and FIFO full/empty conditions
module FIFO_TB();

//Parameter declarations

parameter DATA_WIDTH = 8;                        //Word width
parameter ADDR_WIDTH = 5;                        //FIFO memory depth
parameter SYNCHRONOUS = 0;
parameter ASYNCHRONOUS = 1;
parameter CLK_PERIOD = 20;
//Internal signals declarations
logic wr_clk;
logic wr_rst;
logic [DATA_WIDTH-1:0] data_in;
logic wr_en;									//FIFO memory write enable
logic FIFO_full;								//Memory full indicator
logic [ADDR_WIDTH:0] avail;

logic rd_clk;
logic rd_rst;
logic [DATA_WIDTH-1:0] data_out;
logic rd_en;									//FIFO memory read enable
logic FIFO_empty;								//Memory empty indicator

logic r_w;										//Randomize read/write command for test #3
logic [ADDR_WIDTH-1:0] wptr_tst;					//FIFO write pointer used in test #3
logic [ADDR_WIDTH-1:0] rptr_tst;					//FIFO read pointer used in test #3
integer k;


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
initial
begin
    wr_rst=1'b0;
	rd_rst=1'b0;
    wr_clk=1'b0;
	rd_clk=1'b0;
    rd_en=0;
    wr_en=0;
	
	r_w=0;
	wptr_tst=0;
	rptr_tst=0;
    @(posedge wr_clk)
    wr_rst=1'b1;
    @(posedge rd_clk)
	rd_rst=1'b1;

    //----------------------------------------//
    //Test #1: Writing to the FIFO memory until full. Verify correctness of the writeen data and observe the FIFO_full signal
    for(k=0; k<(2**ADDR_WIDTH+5); k++)        //
        begin
        data_in= $random%8;                  //8-bit random number to be written to the FIFO memory
        @(posedge wr_clk)
        wr_en=1;                             //Enabling write operation
        @(posedge wr_clk)
        wr_en=0;
        #1;									//Added delay to allow the FIFO block to execute before the comparison task 
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
        @(posedge rd_clk)
        rd_en=1;                         //Enabling read operation
        @(posedge rd_clk)
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
		
		r_w={$random}%2; //randomizing read/write operation. '0' for read and '1' for write operation.
		
        data_in= $random%8;                    //8-bit random number to be written to the FIFO memory
		wptr_tst=U1.wptr[ADDR_WIDTH-1:0];
		rptr_tst= U1.rptr[ADDR_WIDTH-1:0];		
		if (r_w==0)							   //Write operation
			begin
				if (FIFO_full==1)
					begin
					$display("\nThe FIFO memory is full - write operation was not completed on iteraion %d", k);
					$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
					$display("Remaning memory slots : %d", U1.avail);
					@(posedge wr_clk);
					end
				else 
					begin
					@(posedge wr_clk)
					wr_en=1;                     //Enabling write operation
					@(posedge wr_clk)
					wr_en=0;
					#1										
					if (U1.mem[wptr_tst] == data_in)
						begin
							$display("\nData written is %b data stored in memory is %b on iteration number %d- success",data_in,U1.mem[wptr_tst],k);
							$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
							$display("Remaning memory slots : %d", U1.avail);
						end
					else
						begin
							$display("Data written is %b data stored in memory is %b on iteration %d- write oepartion failed",data_in,U1.mem[wptr_tst],k);
							$finish;
						end
					end
			end
		else
			begin							//Read operation
				if (FIFO_empty==1)
				begin
					$display("\nThe FIFO memory is empty - read operation was not completed on iteraion %d", k);
					$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
					$display("Remaning memory slots : %d", U1.avail);
					@(posedge rd_clk);					
				end				
				else 
					begin
					@(posedge rd_clk)
					rd_en=1;					
					@(posedge rd_clk)
					rd_en=0;
					#1;							
						if (U1.mem[rptr_tst] == data_out)
							begin
							$display("\nData read is %b data stored in memory is %b on iteration number %d- success",data_out,U1.mem[rptr_tst],k);
							$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
							$display("Remaning memory slots : %d", U1.avail);
							end
						else
							begin
							$display("Data read is %b data stored in memory is %b on iteration %d- read oepartion failed",data_out,U1.mem[rptr_tst],k);
							$display("The wptr value is %d and rptr is %d", U1.wptr, U1.rptr);
							$finish;
							end	
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
wr_clk=~wr_clk;
rd_clk=~rd_clk;
end


endmodule
