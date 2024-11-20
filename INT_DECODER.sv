`timescale 1ns / 1ps  
///////////////////////////////////////////////////////////////////////////
// Company: Ratner Surf Designs  
// Engineer: James Ratner  
// Create Date: 01/29/2019 04:56:13 PM  
// Design Name:   
// Module Name: CU_DCDR  
// Project Name:   
// Target Devices:   
// Tool Versions:   
// Description: The CU_DCDR module takes an Opcode another other inputs and decodes them into a given set of outputs that control the MCU. This DCDR module controls the ALU with ALU_FUN, the PC with PC_SEL, the ALU muxes with both srcA_SEL and srcB_sel as well as the reg_file's write mux with RF_SEL.  
// Dependencies:  
// Instantiation Template:  
// CU_DCDR my_cu_dcdr(  
//   .br_eq     (xxxx),   
//   .br_lt     (xxxx),   
//   .br_ltu    (xxxx),  
//   .opcode    (xxxx),      
//   .func7     (xxxx),      
//   .func3     (xxxx),      
//   .ALU_FUN   (xxxx),  
//   .PC_SEL    (xxxx),  
//   .srcA_SEL  (xxxx),  
//   .srcB_SEL  (xxxx),   
//   .RF_SEL    (xxxx)   );  
// Revision:  
// Revision 1.00 - Created (02-01-2020) - from Paul, Joseph, & Celina  
//          1.01 - (02-08-2020) - removed  else's; fixed assignments  
//          1.02 - (02-25-2020) - made all assignments blocking  
//          1.03 - (05-12-2020) - reduced func7 to one bit  
//          1.04 - (05-31-2020) - removed misleading code  
//          1.05 - (12-10-2020) - added comments  
//          1.06 - (02-11-2021) - fixed formatting issues  
//          1.07 - (12-26-2023) - changed signal names  
///////////////////////////////////////////////////////////////////////////
 
module INT_DECODER(  
   input br_eq,   
   input br_lt,   
   input br_ltu,  
   input [6:0] opcode,   //-  ir[6:0]  
   input func7,          //-  ir[30]  
   input [2:0] func3,    //-  ir[14:12]
   input int_taken,   
   output logic [3:0] ALU_FUN,  
   output logic [2:0] PC_SEL,  
   output logic [1:0] srcA_SEL,  
   output logic [2:0] srcB_SEL,   
   output logic [1:0] RF_SEL   
);  
 
   //- datatypes for RISC-V opcode types  
   typedef enum logic [6:0] {  
        LUI    = 7'b0110111,  
        AUIPC  = 7'b0010111,  
        JAL    = 7'b1101111,  
        JALR   = 7'b1100111,  
        BRANCH = 7'b1100011,  
        LOAD   = 7'b0000011,  
        STORE  = 7'b0100011,  
        OP_IMM = 7'b0010011,  
        OP_RG3 = 7'b0110011,
        SYS    = 7'b1110011  
   } opcode_t;  
 
   opcode_t OPCODE; //- define variable of new opcode type  
   assign OPCODE = opcode_t'(opcode); //- Cast input enum   
 
   //- datatype for func3Symbols tied to values  
   typedef enum logic [2:0] {  
        //BRANCH labels  
        BEQ = 3'b000,  
        BNE = 3'b001,  
        BLT = 3'b100,  
        BGE = 3'b101,  
        BLTU = 3'b110,  
        BGEU = 3'b111  
   } func3_t;      
 
   func3_t FUNC3; //- define variable of new opcode type  
   assign FUNC3 = func3_t'(func3); //- Cast input enum   
 
   always_comb begin   
      //- schedule all values to avoid latch  
      PC_SEL = 3'b000; 
      srcB_SEL = 3'b000; 
      RF_SEL = 2'b00;   
      srcA_SEL = 2'b00; 
      ALU_FUN  = 4'b0000;  
 
      case(OPCODE)  
      AUIPC: begin 
            srcA_SEL = 2'b01; 
            srcB_SEL = 3'b011; 
            ALU_FUN = 4'h0; 
            RF_SEL = 2'b11; 
            PC_SEL = 3'b000; 
      end 
 
      LUI: begin  
            ALU_FUN = 4'h9; // done  
            srcA_SEL = 2'b01; // U-type   
            srcB_SEL = 3'b000; // DC  
            RF_SEL = 2'b11; // load into register  
            PC_SEL = 3'b000;  
         end  
 
      JAL: begin  
            RF_SEL = 2'b00; // just want PC + 4  
            PC_SEL = 3'b011;  
      end  
 
      LOAD: // Itype  
         begin  
            ALU_FUN = 4'h0; // Addition   
            srcA_SEL = 2'b00;    // not a U-Type so good  
            srcB_SEL = 3'b001;   // I-Type  
            RF_SEL = 2'b10; // Coming from Memory to the Reg file (out2)  
            PC_SEL = 3'b000; // not a jump or branch  
         end  
 
      STORE: // Stype  
         begin  
            PC_SEL = 3'b000; // not a jump or branch  
            RF_SEL = 2'b11;   
            ALU_FUN = 4'h0;  // Addition  
            srcA_SEL = 2'b00; // Not a U-Type instruction  
            srcB_SEL = 3'b010; // S-Type  
         end  
 
      JALR: begin  
            PC_SEL = 3'b001;  
            RF_SEL = 2'b00;  
         end  
 
      BRANCH: begin 
         PC_SEL = 3'b000; 
         RF_SEL = 2'b00; 
         case(func3) 
            BEQ: if (br_eq == 1) PC_SEL = 3'b010; 
            BNE: if (br_eq == 0) PC_SEL = 3'b010; 
            BLT: if (br_lt == 1) PC_SEL = 3'b010; 
            BGE: if (br_lt == 0) PC_SEL = 3'b010; 
            BLTU: if (br_ltu == 1) PC_SEL = 3'b010; 
            BGEU: if (br_ltu == 0) PC_SEL = 3'b010; 
            default: PC_SEL = 3'b000; 
         endcase 
         end 
 
      OP_IMM: begin  
            case(FUNC3)  
               3'b000: begin // instr: ADDI  
                  ALU_FUN = 4'b0000; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b010: begin // instr: SLTI  
                  ALU_FUN = 4'b0010; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b011: begin // instr: SLTIU  
                  ALU_FUN = 4'b0011; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b110: begin // instr: ORI  
                  ALU_FUN = 4'b0110; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b100: begin // instr: XORI  
                  ALU_FUN = 4'b0100; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b111: begin // instr: ANDI  
                  ALU_FUN = 4'b0111; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b001: begin // instr: SLLI  
                  ALU_FUN = 4'b0001; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b001; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
               3'b101: begin  
                  if (func7 == 0) begin // instr: SRLI  
                     ALU_FUN = 4'b0101; 
                     srcA_SEL = 2'b00; 
                     srcB_SEL = 3'b001; 
                     RF_SEL = 2'b11; 
                     PC_SEL = 3'b000;  
                  end else begin  
                     ALU_FUN = 4'b1000; 
                     srcA_SEL = 2'b00; 
                     srcB_SEL = 3'b001; 
                     RF_SEL = 2'b11; 
                     PC_SEL = 3'b000;  
                  end  
               end  
               default: begin // no function  
                  PC_SEL = 3'b000; 
                  srcB_SEL = 3'b000; 
                  RF_SEL = 2'b00; 
                  srcA_SEL = 2'b00; 
                  ALU_FUN  = 4'b0000;  
               end  
            endcase  
         end  
 
      OP_RG3: begin  
         case(FUNC3)  
            3'b000: begin  
               if (func7 == 0) begin // ADD  
                  ALU_FUN = 4'b0000; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b000; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end else begin // SUB  
                  ALU_FUN = 4'b1000; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b000; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
            end  
            3'b010: begin // instr: SLT  
               ALU_FUN = 4'b0010; 
               srcA_SEL = 2'b00; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b11; 
               PC_SEL = 3'b000;  
            end  
            3'b011: begin // instr: SLTU  
               ALU_FUN = 4'b0011; 
               srcA_SEL = 2'b00; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b11; 
               PC_SEL = 3'b000;  
            end  
            3'b110: begin // instr: OR  
               ALU_FUN = 4'b0110; 
               srcA_SEL = 2'b00; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b11; 
               PC_SEL = 3'b000;  
            end  
            3'b111: begin // instr: AND  
               ALU_FUN = 4'b0111; 
               srcA_SEL = 2'b00; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b11; 
               PC_SEL = 3'b000;  
            end  
            3'b100: begin // instr: XOR  
               ALU_FUN = 4'b0100; 
               srcA_SEL = 2'b00; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b11; 
               PC_SEL = 3'b000;  
            end  
            3'b001: begin // instr: SLL  
               ALU_FUN = 4'b0001; 
               srcA_SEL = 2'b00; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b11; 
               PC_SEL = 3'b000;  
            end  
            3'b101: begin  
               if (func7 == 0) begin // instr: SRL  
                  ALU_FUN = 4'b0101; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b000; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end else begin // instr: SRA  
                  ALU_FUN = 4'b1000; 
                  srcA_SEL = 2'b00; 
                  srcB_SEL = 3'b000; 
                  RF_SEL = 2'b11; 
                  PC_SEL = 3'b000;  
               end  
            end  
            default: begin // no function  
               PC_SEL = 3'b000; 
               srcB_SEL = 3'b000; 
               RF_SEL = 2'b00; 
               srcA_SEL = 2'b00; 
               ALU_FUN  = 4'b0000;  
            end  
         endcase  
      end
      
     SYS: begin  
         case(FUNC3)  
            3'b000: begin   //MRET
            PC_SEL = 3'b101; // mepc
            //srcB_SEL = ; 
            //srcA_SEL = ;
            //ALU_FUN = ;
         end 
            3'b001: begin   //CSRRW
            PC_SEL = 3'b000 ;
            RF_SEL = 2'b01;
            //srcB_SEL = ; DC
            //srcA_SEL = ; DC
            //ALU_FUN = ;  DC
         end
            3'b010: begin   // CSRRS
            PC_SEL = 3'b000;
            srcB_SEL = 3'b100;
            srcA_SEL = 2'b00;
            ALU_FUN = 4'b0110;
            RF_SEL = 2'b10;
        end
            3'b011: begin   //CSRRC
            PC_SEL = 3'b000;
            srcB_SEL = 3'b100;
            srcA_SEL = 2'b10;
            ALU_FUN = 4'b0111;
            RF_SEL = 2'b10;
        end
     endcase
     end

      default: begin // no opcode  
         PC_SEL = 3'b000; 
         srcB_SEL = 3'b000; 
         RF_SEL = 2'b00; 
         srcA_SEL = 2'b00; 
         ALU_FUN  = 4'b0000;  
      end  
      endcase 
    end  
endmodule
