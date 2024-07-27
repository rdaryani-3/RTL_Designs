// 4-input priority encoder with Valid
module priority_enc(Out,In0,In1,In2,In3);
  output logic [1:0]Out;
  input logic In0, In1, In2, In3;
  logic Vld;
  
  assign Vld = In0 || In1 || In2 || In3;
  
  assign Out = Vld ? (In3 ? '1 : (In2 ? 2'b10 : (In1 ? 2'b01 : '0))) : 'x; 
  
endmodule