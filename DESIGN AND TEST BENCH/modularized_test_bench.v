`include "defines.h"
`include "alu_design.v"
`timescale 1ns/1ps

`define PASS 1'b1
`define FAIL 1'b0

`define test_cases 88
`define SIZE 57


module combined_test;
  reg clk,rst,ce;
  reg [(`WIDTH - 1):0]opa,opb;
  reg cin,mode;
  reg [1:0]inp_valid;
  reg [(`COMMANDS - 1):0]cmd;
  event fetch_test;
  integer i; //responsible for the test_case address
  `ifdef en_mul
    wire [((`WIDTH * 2) - 1):0]res;
  `else
    wire [`WIDTH:0]res;
  `endif
  reg [56:0]curr_test;
  reg [56:0]stimuli[0:`test_cases];
  wire [16:0]expected_out;
  reg [16:0] response;
  reg [72:0]resp_packet;
  reg [`WIDTH:0]expected_res;

  wire oflow,cout,g,l,e,err,neg,zero;

  ALU DUT(clk,rst,ce,opa,opb,cin,mode,inp_valid,cmd,res,oflow,cout,g,l,e,err,neg,zero);

  integer stim_ptr = 0, stim_scb_ptr = 0;
  integer file_id = 0;

  task store();
     begin
       repeat(3)@(negedge clk);
       $readmemb("stimulus.mem",stimuli);
     end
  endtask

  always@(fetch_test)
  begin
    curr_test = stimuli[stim_ptr];
    $display("%0d | INPUT = %b",stim_ptr+1,stimuli[stim_ptr]);
    $display("FETCHED INPUT = %b",curr_test);
    stim_ptr = stim_ptr + 1;
  end

  task reset_block();
    begin
      ce = 1;
      rst = 1;
      repeat(2)@(negedge clk);
      rst = 0;
    end
  endtask

  task initialize();
    begin
      stim_ptr = 0;
      curr_test = 50'd0;
      resp_packet = 67'd0;
    end
  endtask

  reg [7:0] feature_id;
  reg c_out,ov,e_rr,n,z;
  reg [2:0]compare_EGL;

  task driver();
    begin
      ->fetch_test;
      @(negedge clk);
      inp_valid = curr_test[(`SIZE - 9) : (`SIZE - 10)];
      opa = curr_test[(`SIZE - 11) : (`SIZE - 18)];
      opb = curr_test[(`SIZE - 19) : (`SIZE - 26)];
      cmd = curr_test[(`SIZE - 27) : (`SIZE - 30)];
      cin = curr_test[(`SIZE - 31)];
      mode = curr_test[(`SIZE - 33)];
      ce = curr_test[(`SIZE - 32)];
      feature_id = curr_test[(`SIZE - 1) : (`SIZE - 8)];
      expected_res = curr_test[23 : 8];
      c_out = curr_test[7];
      ov = curr_test[3];
      e_rr = curr_test[2];
      n = curr_test[1];
      z = curr_test[0];
      compare_EGL = curr_test[6:4];
      $display("DRIVER: INPUT %0d DRIVEN AT %0t | FEATURE_ID = %8b INP_VALID = %2b OPA = %8b OPB = %8b CMD = %4b CIN = %0b CE = %0b MODE = %0b EXP_RES = %16b EXP_COUT = %0b EGL = %3b OV = %0b EXP_ERR = %0b EXP_NEG = %0b EXP_ZERO = %0b",stim_ptr+1,$time,feature_id,inp_valid,opa,opb,cmd,cin,ce,mode,expected_res,c_out,compare_EGL,ov,e_rr,n,z);
    end
  endtask
  assign expected_out = {expected_res[8:0],c_out,compare_EGL,ov,n,z,e_rr};

  task monitor();
    begin
      if((curr_test[(`SIZE - 33)] == 1) && ((curr_test[(`SIZE - 27) : (`SIZE - 30)] == `ADD_MUL) || (curr_test[(`SIZE - 27) : (`SIZE - 30)] == `SH_MUL)))
        repeat(4)@(posedge clk);
      else
        repeat(3)@(posedge clk);
      #5;
      resp_packet[56:0] = curr_test;
      resp_packet[63:56] = {cout,e,g,l,oflow,neg,zero,err};
      resp_packet[72:64] = res;
      response = {res,cout,e,g,l,oflow,neg,zero,err};
      $display("MONITOR: OUTPUT %0d AT %0t | RES = %b COUT = %0b E = %0b G = %0b L = %0b OV = %0b NEG = %0b ZERO = %0b ERR = %0b",stim_ptr+1,$time,res,cout,e,g,l,oflow,neg,zero,err);
    end
  endtask
  reg [28:0]scb_val[0:`test_cases];

  task scoreboard();
  reg [7:0]Feature_ID;
  reg [`WIDTH:0] expected_res;
  reg [`WIDTH:0] response_res;
    begin
      #5;
      Feature_ID = curr_test[(`SIZE - 1) : (`SIZE - 8)];
      expected_res = curr_test[16 : 8];
      response_res = resp_packet[72 : 64];
      $display("EXPECTED RESULT = %b RESPONSE OUT = %b\n--------------------------------------\n",expected_out,response);
      if(expected_out === response)
        begin
          scb_val[stim_scb_ptr] = {1'b0,Feature_ID,expected_res,response_res,1'b0,`PASS};
        end
      else
        begin
          scb_val[stim_scb_ptr] = {1'b0,Feature_ID,expected_res,response_res,1'b0,`FAIL};
        end
      stim_scb_ptr = stim_scb_ptr + 1;
    end
  endtask

  task write_res();
  integer point;
  reg [28:0]curr_cmp;
    begin
      file_id = $fopen("results.txt","w");
      for(point = 0; point <= `test_cases; point = point + 1)
        begin
          curr_cmp = scb_val[point];
          if(curr_cmp[0])
            $fdisplay(file_id,"FEATURE ID: %8b : PASS",curr_cmp[27 : 20]);
          else
            $fdisplay(file_id,"FEATURE ID: %8b : FAIL",curr_cmp[27 : 20]);
        end
    end
  endtask

  initial begin //main working of the test code
    rst = 0;
    repeat(2)@(posedge clk);
    reset_block();
    initialize();
    store();
    repeat(4)@(posedge clk);
    for(i = 0; i < `test_cases; i = i + 1)
      begin
        fork
          driver();
          monitor();
        join
        scoreboard();
      end
      write_res();
      $fclose(file_id);
      repeat(2)@(posedge clk);
      $finish;
  end
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0,combined_test);
  end

endmodule
