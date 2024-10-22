`timescale 1ns/1ps

interface cmd_if #(parameter ADDRW = 32, parameter BYTE_CNTw = 16, parameter DATAW = 32);
  
  logic req,wr;
  logic [BYTE_CNTw-1:0] byte_cnt;
  logic [ADDRW-1:0] start_addr;
  logic [DATAW-1:0] wdata;
  logic done,wr_done,req_ack;
  
  modport master (input done,wr_done,req_ack, output req,byte_cnt,start_addr,wr,wdata);
  modport slave (input req,byte_cnt,start_addr,wr,wdata, output done,req_ack,wr_done);
  
endinterface

interface ahb_if #(parameter ADDRW = 32, parameter DATAW = 32);
  
  logic hwrite;
  logic [DATAW-1:0] hwdata, hrdata;
  logic [ADDRW-1:0] haddr;
  logic [2:0] hsize, hburst;
  logic [1:0] htrans;
  logic [3:0] hprot;
  logic hmastlock;
  logic hready, hresp;
  logic hresetn, hclk;
  
  modport master (input hresetn, hclk, hready, hresp, hrdata, output hwdata, haddr, hwrite, hsize, hburst, htrans, hprot, hmastlock);
  modport slave (input hwdata, haddr, hwrite, hsize, hburst, htrans, hprot, hmastlock, output hresetn, hclk, hready, hresp, hrdata);
  
endinterface

module ahb_m(clk, rst);
  
  parameter ADDRW = 32;
  parameter DATAW = 32;
  parameter BYTE_CNTw = 16;
  
  input logic clk,rst;
  cmd_if in(.*); 
  ahb_if out(.*);
  
  logic hwrite_reg, hwrite_nxt;
  logic [DATAW-1:0] hwdata_reg, hrdata_reg, hwdata_nxt, hrdata_nxt;
  logic [ADDRW-1:0] haddr_reg, haddr_nxt;
  logic [2:0] hsize_reg, hburst_reg, hsize_nxt, hburst_nxt;
  logic [1:0] htrans_reg, htrans_nxt;
  logic [3:0] hprot;
  logic [3:0] seq_cnt, seq_cnt_nxt;
  logic hmastlock;
  logic hready, hresp;
  logic done,wr_done, req_ack;
  logic [BYTE_CNTw-1:0] byte_cnt, byte_cnt_nxt;
  logic [DATAW-1:0] wdata_reg, wdata_nxt;
  
  //state enum  
  typedef enum logic [2:0] {IDLE, START, INCR, INCR4, INCR8, INCR16, DONE} state;
  state pr_state,nx_state;
  
  
  //Driving master output from flops
  always_comb ahb_if.master.haddr   = haddr_reg;
  always_comb ahb_if.master.hwdata  = hwdata_reg;
  always_comb ahb_if.master.hwrite  = hwrite_reg;
  always_comb ahb_if.master.hsize   = hsize_reg;
  always_comb ahb_if.master.hburst  = hburst_reg;
  always_comb ahb_if.master.htrans  = htrans_reg;
  always_comb ahb_if.master.hmastlock= hmastlock;
  always_comb ahb_if.master.hprot   = hprot;
    
  assign hmastlock = '0;
  assign hprot = '0;
  assign cmd_if.master.cmd_done = done;
  assign cmd_if.master.req_ack = req_ack;
  assign wdata_nxt = (cmd_if.master.wr && wr_done) ? cmd_if.master.wdata : wdata_reg;

  //penable to be low during setup phase only
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      byte_cnt <= '0;
      wdata_reg<= '0;
    end
    else begin
      byte_cnt <= byte_cnt_nxt;
      wdata_reg<= wdata_nxt;
    end
  end
  
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      haddr_reg   <= '0;
      hwdata_reg  <= '0;
      hwrite_reg  <= '0;
      hsize_reg   <= '0;
      hburst_reg  <= '0;
      htrans_reg  <= '0;
      seq_cnt     <= '0;
    end
    else if (ahb_if.master.hready) begin //pready dependent driven output
      pr_state    <= nx_state;
      haddr_reg   <= haddr_nxt;
      hwdata_reg  <= hwdata_nxt;
      hwrite_reg  <= hwrite_nxt;
      hsize_reg   <= hsize_nxt;
      hburst_reg  <= hburst_nxt;
      htrans_reg  <= htrans_nxt;
      seq_cnt     <= seq_cnt_nxt;
    end
  end
  
  always_comb begin
      nx_state    = pr_state; //default case values
      haddr_nxt   = haddr_reg;
      hwdata_nxt  = hwdata_reg;
      hwrite_nxt  = hwrite_reg;
      hsize_nxt   = hsize_reg;
      hburst_nxt  = hburst_reg;
      htrans_nxt  = htrans_reg;
      byte_cnt_nxt= byte_cnt;
      seq_cnt_nxt = seq_cnt;
      done        = '0;
      req_ack     = '0; 
          
    case (pr_state) 
      IDLE : begin
               if (cmd_if.master.req) begin
                 nx_state     = START;
                 byte_cnt_nxt = cmd_if.master.byte_cnt;
               end  
             end
      
      START : begin
                req_ack     = '1;
                haddr_nxt    = cmd_if.master.start_addr;
                hwrite_nxt   = cmd_if.master.wr;
                hwdata_nxt   = cmd_if.master.wdata;
                hsize_nxt    = 3'd2;
                htrans_nxt   = 2'd3;
                seq_cnt_nxt  = '0;
        
                if  (byte_cnt%DATAW == '0) begin
                  nx_state = INCR;
                  hburst_nxt   = 3'd1; 
                end
                else if  (byte_cnt>=512) begin
                  nx_state     = INCR16;
                  byte_cnt_nxt = byte_cnt - 16'd512;
                  hburst_nxt   = 3'd7; 
                end
                else if  (byte_cnt>=256) begin
                  nx_state = INCR8;
                  byte_cnt_nxt = byte_cnt - 16'd256;
                  hburst_nxt   = 3'd5; 
                end
                else if  (byte_cnt>=128) begin
                  nx_state = INCR4;
                  byte_cnt_nxt = byte_cnt - 16'd128;
                  hburst_nxt   = 3'd3; 
                end
                else begin
                  nx_state = INCR;
                  hburst_nxt   = 3'd1; 
                end
              end
      
      INCR16 : begin
               
               
      end

endmodule
