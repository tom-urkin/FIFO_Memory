`timescale 1ns/100ps
//Following TB verifies the Synchronous_FIFO operation including reading, writing and FIFO full/empty conditions
module Synchronous_FIFO_TB();

//Parameter declarations

parameter DATA_WIDTH = 8;                        //Word width
parameter ADDR_WIDTH = 5;                        //FIFO memory depth
parameter CLK_PERIOD = 20;
//Internal signals declarations
logic clk;
logic rst;
logic [DATA_WIDTH-1:0] data_in;
logic [DATA_WIDTH-1:0] data_out;
logic FIFO_empty;
logic FIFO_full;
logic wr_en;
logic rd_en;

integer k;

//Synchronous FIFO memory module
Synchronous_FIFO #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) U1(
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
            $display("Data written is %b data stored in memory is %b on iteration number %d- success",data_in,U1.mem[k],k);
        else if (FIFO_full==1)
            $display("The FIFO memory is full - write operation was not completed on iteraion %d", k);
        else
            begin
                $display("Data written is %b data stored in memory is %b on iteration %d- write oepartion failed",data_in,U1.mem[k],k);
                $finish;
            end

        end

    $display("Test 1 completed successfully");

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
            $display("Data read is %b data stored in memory is %b on iteration number %d- success",data_out,U1.mem[k],k);
        else if (FIFO_empty==1)
            $display("The FIFO memory is empty - read operation was not completed on iteraion %d", k);
        else
            begin
                $display("Data read is %b data stored in memory is %b on iteration %d- read oepartion failed",data_out,U1.mem[k],k);
                $finish;
            end

        end

    $display("Test 2 completed successfully");

    //----------------------------------------//
    //Test #3: Reading and writing from the FIFO memory for 3*FIFO depth times

    for(k=0; k<(2**ADDR_WIDTH*3); k++)       //
        begin
        data_in= $random%8;                  //8-bit random number to be written to the FIFO memory
        @(posedge clk)
        wr_en=1;                             //Enabling write operation
        @(posedge clk)
        wr_en=0;
        @(posedge clk)
        rd_en=1;
        @(posedge clk)
        rd_en=0;

        #1;

        if (data_out == data_in)
            $display("Data written is %b data read is %b on iteration number %d- success",data_in,data_out,k);
        else if (FIFO_full==1)
            $display("The FIFO memory is full - write operation was not completed on iteraion %d", k);
        else if (FIFO_empty==1)
            $display("The FIFO memory is empty - read operation was not completed on iteraion %d", k);
        else
            begin
                $display("Data written is %b data read in memory is %b on iteration %d- write oepartion failed",data_in,data_out,k);
                $finish;
            end

        end

    $display("Test 3 completed successfully");

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
