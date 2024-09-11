
// Parameterized Asynchronous FIFO Implementation

module async_FIFO (rd_data,full,empty,rd,wr,wr_data,r_clk,w_clk,r_rst,w_rst);
  parameter depth = 8;
  parameter width = 8;
  parameter addr  = $clog2(depth);
  
  output logic full,empty;
  input logic r_clk,r_rst,w_clk,w_rst,rd,wr;
  input logic [width-1:0] wr_data; 
  output logic [width-1:0] rd_data; 
  
  logic [addr-1:0] rd_ptr,wr_ptr;
  logic [width-1:0] FIFO [depth-1:0];
  logic [width-1:0] rd_data_ff; 
  logic [addr-1:0] sync_rd_ptr,sync_wr_ptr;
 
  
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      for (int i=0;i<depth;i++) FIFO[i] <= '0;
    end
    else if (wr && !full) begin
      FIFO[wr_ptr] <= wr_data;//write
    end
  end
  
  always @(posedge clk or negedge rst) begin
    if (!rst) wr_ptr <= '0;
    else if (wr && !full) begin
      wr_ptr <= (wr_ptr == 4'd15) ? '0 : wr_ptr + 4'd1;
    end
  end   
  
  always @(posedge clk or negedge rst) begin
    if (!rst) rd_data_ff <= '0;
    else if (rd && !empty) begin
      rd_data_ff <= FIFO [rd_ptr];
    end
  end 
  
  assign rd_data =  rd_data_ff;//read
  
  always @(posedge clk or negedge rst) begin
    if (!rst) rd_ptr <= '0;
    else if (rd && !empty) begin
      rd_ptr <= (rd_ptr == 4'd15) ? '0 : rd_ptr + 4'd1;
    end
  end 
  
  always @(posedge clk or negedge rst) begin
    if (!rst) wr_ptr_ov <= '0;
    else if (wr_ptr == 4'd15 && wr && !full) wr_ptr_ov <= !wr_ptr_ov;
  end 
  
  always @(posedge clk or negedge rst) begin
    if (!rst) rd_ptr_ov <= '0;
    else if (rd_ptr == 4'd15 && rd && !empty) rd_ptr_ov <= !rd_ptr_ov;
  end
  
  always_comb begin
    full = '0;
    if ((wr_ptr == rd_ptr) && (wr_ptr_ov != rd_ptr_ov)) begin
      full = '1;
    end
  end 
  
  always_comb begin
    empty = '0;
    if ((wr_ptr == rd_ptr) && (wr_ptr_ov == rd_ptr_ov)) begin
      empty = '1;
    end
  end 
        
endmodule

// Synchronizer module for clock domain crossing
module sync(sync_o,rst,clk,sync_i);
  parameter depth = 8;
  parameter addr  = $clog2(depth);
  
  input logic [addr-1:0] sync_i;
  output logic [addr-1:0] sync_o;
  input logic clk,rst;
  
  logic [addr-1:0] Q;
  
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      Q <= '0;
      sync_o <= '0;
    end
    else begin
      Q <= sync_i;
      sync_o <= Q;
    end 
endmodule
      
      
