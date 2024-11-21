
`timescale 1ns / 1ps 

////////////////////////////////////////////////////////////////////////////////// 
// Company:  
// Engineer: Jacob M & Tyler B 
//  
// Create Date: 10/14/2024 04:26:44 PM 
// Design Name:  
// Module Name: Top_Mod 
// Project Name:  
// Target Devices:  
// Tool Versions:  
// Description:  
//  
// Dependencies:  
//  
// Revision: 
// Revision 0.01 - File Created 
// Additional Comments: 
//  
////////////////////////////////////////////////////////////////////////////////// 

module Top_mod( 
input RST, 
input [31:0] IOBUS_IN,
input INTR,
input CLK,
output IOBUS_WR,
output [31:0] IOBUS_OUT,
output [31:0] IOBUS_ADDR
    ); 
    
    
// EX 4 I/O as signals
wire PC_WE;
wire [31:0] u_type_imm;
wire [31:0] s_type_imm;
wire [1:0] PC_SEL;
wire reset;


wire [31:0] Mux_out; 
wire [31:0] pc; 
wire [31:0] jalr; 
wire [31:0] branch; 
wire [31:0] jal; 

// exp 4 signals

wire [31:0] ir;

wire [31:0] Itype;
wire [31:0] Jtype;
wire [31:0] Btype;

// Exp 5 signals

wire [3:0] ALU_FUN;
wire srcA_sel;
wire [1:0] srcB_sel;
wire [1:0] RF_SEL;
wire [31:0] mem_out_2;
wire [31:0] result;
wire [31:0] srcA;
wire [31:0] srcB;
wire [31:0] rs1;
wire [31:0] rs2;
wire [31:0] w_data;
wire memWE2;    
wire memRDEN2;
wire memRDEN1;
wire RF_WE;

// EXP 7 signals 
wire int_taken;
wire mret_exec;
wire [31:0] RD;
wire [11:0] ADDR;
wire [31:0] WD;
wire WR_EN;
wire CSR_MSTATUS_MIE;
wire [31:0] CSR_MEPC=0;
wire [31:0] CSR_MTVEC=0;

// Branch Cond Gen
wire br_eq;
wire br_ltu;
wire br_lt;

mux_6t1_nb  #(.n(32)) PC_MUX  ( 
       .SEL   (PC_SEL),         //  
       .D0    (pc+4),           // adds 4 to the PC output  
       .D1    (jalr),       // assigned value of jalr  
       .D2    (branch),       // assigned value of branch  
       .D3    (jal),       // assigned value of jal 
       .D4    (mtvec),
       .D5    (mepc),
       .D_OUT (Mux_out) );      // mux selection value, goes into PC_MOD   

      //- Usage example from given file  

reg_nb #(.n(32)) PC_MOD ( 
          .data_in  (Mux_out),  
          .ld       (PC_WE),  
          .clk      (CLK),  
          .clr      (reset),  
          .data_out (pc) ); 
           
           

Memory OTTER_MEMORY ( 
    .MEM_CLK   (CLK), 
    .MEM_RDEN1 (memRDEN1),  
    .MEM_RDEN2 (memRDEN2),  
    .MEM_WE2   (memWE2), 
    .MEM_ADDR1 (pc[15:2]), 
    .MEM_ADDR2 (result), 
    .MEM_DIN2  (rs2),   
    .MEM_SIZE  (ir[13:12]), 
    .MEM_SIGN  (ir[14]), 
    .IO_IN     (IOBUS_IN), 
    .IO_WR     (IOBUS_WR),      // output 
    .MEM_DOUT1 (ir),    
    .MEM_DOUT2 (mem_out_2)  );  // Dout 2 not working
    
    
    CU_DCDR my_cu_dcdr(
   .br_eq     (br_eq), 
   .br_lt     (br_lt), 
   .br_ltu    (br_ltu),
   .opcode    (ir[6:0]),    
   .func7     (ir[30]),    
   .func3     (ir[14:12]),    
   .ALU_FUN   (ALU_FUN),
   .PC_SEL    (PC_SEL),
   .srcA_SEL  (srcA_sel),
   .srcB_SEL  (srcB_sel),
   .int_taken (int_taken), 
   .RF_SEL    (RF_SEL)   );
   
   CU_FSM my_fsm(
        .intr     (INTR),
        .clk      (CLK),
        .RST      (RST),
        .opcode   (ir[6:0]),   // ir[6:0]
        .PC_WE    (PC_WE),
        .RF_WE    (RF_WE),
        .memWE2   (memWE2),
        .memRDEN1 (memRDEN1),
        .memRDEN2 (memRDEN2),
        .int_taken(int_taken),
        .csr_WE   (WR_EN),
        .mret_exec(mret_exec),
        .reset    (reset)   );
        
     mux_4t1_nb  #(.n(32)) reg_mux  (
       .SEL   (RF_SEL), 
       .D0    (pc+4), 
       .D1    (32'h00000000), // grounded (connected to a CSR output)
       .D2    (mem_out_2), 
       .D3    (result),
       .D_OUT (w_data) );  
        
        
    RegFile my_regfile (    
        .w_data (w_data),
        .clk    (CLK), 
        .en     (RF_WE),
        .adr1   (ir[19:15]),
        .adr2   (ir[24:20]),
        .w_adr  (ir[11:7]),
        .rs1    (rs1), 
        .rs2    (rs2)  );
        
   
   mux_3t1_nb  #(.n(32)) muxA  (
       .SEL   (srcA_sel), 
       .D0    (rs1), 
       .D1    (u_type_imm),
       .D2    (~ D0),
       .D_OUT (srcA) );  
       
   
  mux_5t1_nb   #(.n(32)) muxB  (
       .SEL   (srcB_sel), 
       .D0    (rs2), 
       .D1    (Itype), 
       .D2    (s_type_imm), 
       .D3    (pc),
       .D4    (csr_RD),
       .D_OUT (srcB) ); 
           
   
   alu my_alu(  // done
       .alu_fun(ALU_FUN),
       .srcA(srcA),
       .srcB(srcB),
       .result(result)
   );
   
   CSR CSR(
       .CLK(CLK),
       .RST(RST),
       .MRET_EXEC(mret_exec),
       .INT_TAKEN(Int_taken),
       .ADDER(ir[31:20]),
       .PC(pc),
       .WD(WD),
       .WR_EN(csr_WE),
       .RD(csr_RD),
       .CSR_MEPC(mepc),
       .CSR_MTVEC(mtvec),
       .CSR_MSTATUS_MIE(CSR_MSTATUS_MIE),
       .CSR_MSTATUS(CSR_MSTATUS)
       );
       
    
    // IMMED_GEN
    assign Itype = {{21{ir[31]}}, ir[30:25], ir[24:20]};    //21 + 6 + 5 = 32
    assign Jtype = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};  // 12 + 8 + 1 + 10 + 1 = 32
    assign u_type_imm = {ir[31:12], 12'b0};  // should be right // 20 + 12 = 32
    assign Btype = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0}; // 20 + 1 + 6 + 4 + 1 = 32
    assign s_type_imm = {{21{ir[31]}}, ir[30:25], ir[11:7]};    // 21 + 6 + 5 = 32
    
    
    // Branch Gen Addr
    assign branch = (pc + Btype); // B Type, yes pc
    assign jalr = (rs1 + Itype); // I Type, no pc
    assign jal = (pc + Jtype);  // J Type, yes pc
    

    // Branch cond gen
    assign br_eq = $signed(rs1) == $signed(rs2) ? 1 : 0;
    assign br_lt = $signed(rs1) < $signed(rs2) ? 1 : 0;
    assign br_ltu = rs1 < rs2 ? 1 : 0;
    
    
    
    
    // Outputs
    
    assign IOBUS_OUT = rs2;
    assign IOBUS_ADDR = result;
    
    
     
endmodule 
