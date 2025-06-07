module ALU(clk,rst,ce,opa,opb,cin,mode,inp_valid,cmd,res,oflow,cout,g,l,e,err,ne                                                                                                             g,zero);
    input clk,rst,ce,mode,cin;
    input [1:0] inp_valid;
    input [(`COMMANDS-1):0]cmd;
    input [(`WIDTH-1):0] opa,opb;
    output reg oflow,cout,g,l,e,err,neg,zero;
   `ifdef enable_mul
    output reg[((`WIDTH - 1)*2):0] res;
   `else
    output  reg [`WIDTH:0]res;
   `endif

    localparam log2 = $clog2(`WIDTH),
               MASK = (2**`WIDTH) - 1;

    wire signed [(`WIDTH-1):0] a,b;
    reg [1:0]toggle;
    reg tempc;
    reg [(`WIDTH-1):0] tempa,tempb;
    reg [(`COMMANDS-1) : 0]cmd_prev;
    //ASYNCHRONOUS ACTIVE HIGH RESET HENCE, SAME PRIORITY AS CLK(POSEDGE TRIGGER                                                                                                             ED DEVICE)
    wire [(log2-1):0]shift_amt = tempb[(log2-1):0];
    always@(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            toggle <= 0;
            res <= {(`WIDTH + 1){1'b0}};
            g <= 1'b0;
            l <= 1'b0;
            e <= 1'b0;
            err <= 1'b0;
            tempa <= {`WIDTH{1'b0}};
            tempb <= {`WIDTH{1'b0}};
            tempc <= 1'b0;
            cmd_prev <= {`COMMANDS{1'b0}};
        end
        else begin
            if(ce) begin
                if(mode) begin
                  if((cmd_prev != cmd || tempa != opa || tempb != opb || (((cmd                                                                                                              == `ADD_CIN)||(cmd == `SUB_CIN))&& tempc != cin)) && cmd != `CMP) begin
                    g <= 1'b0;
                    l <= 1'b0;
                    e <= 1'b0;
                  end
                  else begin
                    g <= g;
                    l <= l;
                    e <= e;
                  end
                    err <= 1'b0;
                    toggle <= toggle;
                    tempc <= 1'b0;
                    if( ( cmd == `ADD || cmd == `SUB || cmd == `ADD_CIN || cmd <                                                                                                             = `SUB_CIN ) | cmd == `CMP) begin
                        if(inp_valid == 3) begin
                            if(cmd_prev != cmd || tempa != opa || tempb != opb |                                                                                                             | (((cmd == `ADD_CIN)||(cmd == `SUB_CIN))&& tempc != cin))
                            begin
                                toggle <= 1;
                                cmd_prev <= cmd;
                                tempa <= opa;
                                tempb <= opb;
                                res <= res;
                                tempc <= cin;
                            end
                            else begin
                                case(cmd)
                                    `SUB: res <= tempa - tempb;
                                    `ADD_CIN: res <= tempa + tempb + tempc;
                                    `SUB_CIN: res <= tempa - tempb - tempc;
                                    `CMP: begin
                                            if(tempa > tempb)
                                                {g,l,e} <= 3'b100;
                                            else if(a < b)
                                                {g,l,e} <= 3'b010;
                                            else
                                                {g,l,e} <= 3'b001;
                                         end
                                     default: res <= tempa + tempb;
                                endcase
                                toggle <= toggle;
                            end
                        end
                        else begin
                            res <= {(`WIDTH + 1){1'b0}};
                            err <= 1; //if there is no valid opa and opb
                            g <= 1'b0;
                            l <= 1'b0;
                            e <= 1'b0;
                            toggle <= 0;
                        end
                    end
                    else if(cmd == `INC_A | cmd == `DEC_A) begin
                        if(inp_valid == 2'b01) begin
                            if(cmd_prev != cmd || tempa != opa)
                            begin
                                toggle <= 1;
                                cmd_prev <= cmd;
                                tempa <= opa;
                                tempb <= opb;
                                res <= res;
                            end
                            else begin
                                if(cmd == `INC_A)
                                    res <= tempa + 1;
                                else
                                    res <= tempa - 1;
                                toggle <= toggle;
                            end
                        end
                        else begin
                            res <= {(`WIDTH + 1){1'b0}};
                            err <= 1; //if there is no valid opa
                            toggle <= 0;
                        end
                    end
                    else if(cmd == `INC_B | cmd == `DEC_B) begin
                        if(inp_valid == 2) begin
                            if(cmd_prev != cmd || tempb != opb)
                            begin
                                toggle <= 1;
                                cmd_prev <= cmd;
                                tempa <= opa;
                                tempb <= opb;
                                res <= res;
                            end
                            else begin
                                if(cmd == `INC_B)
                                    res <= tempb + 1;
                                else
                                    res <= tempb - 1;
                                toggle <= 1;
                            end
                        end
                        else begin
                            res <= {(`WIDTH + 1){1'b0}};
                            err <= 1;
                            toggle <= 0;
                        end
                    end
                    else if(cmd == `ADD_MUL || cmd == `SH_MUL || cmd == `SP_1 ||                                                                                                              cmd <= `SP_2)begin
                        if(inp_valid == 3) begin
                            if(cmd_prev != cmd || (toggle != 2 && (tempa != opa                                                                                                              || tempb != opb)) || (cmd == `ADD_MUL && toggle == 2 && (((tempa == 0) ? ((opa !                                                                                                             = {`WIDTH{1'b1}}) ? 1 : 0) : ((tempa != opa+1) ? 1 : 0)) || (((tempb == 0) ? ((o                                                                                                             pb != {`WIDTH{1'b1}}) ? 1 : 0) : ((tempb != opb + 1) ? 1 : 0))))) || (cmd == `SH                                                                                                             _MUL && toggle == 2 && (tempa != opa << 1 || tempb != opb)))
                            begin
                                    toggle <= 1;
                                    cmd_prev <= cmd;
                                    tempa <= opa;
                                    tempb <= opb;
                                    res <= res;
                                    tempc <= cin;
                                    $display("TRUE = %0b TOGGLE 0",(cmd_prev !=                                                                                                              cmd || tempa != opa || tempb != opb));
                                end
                            else begin
                                case(cmd)
                                    `ADD_MUL: begin
                                                $display("Enters ADD_MUL");
                                                if(toggle == 1)
                                                begin
                                                    tempa <= tempa + 1;
                                                    tempb <= tempb + 1;
                                                    res <= res;
                                                    toggle <= 2;
                                                    $display("TOGGLE 1");
                                                end
                                                else
                                                begin
                                                    $display("ENTERS MAIN");
                                                    res <= tempa * tempb;
                                                    toggle <= 2;
                                                end
                                             end
                                    `SH_MUL: begin
                                            if(toggle == 1) begin
                                                tempa <= tempa << 1;
                                                tempb <= tempb;
                                                toggle <= 2;
                                            end
                                            else
                                            begin
                                                res <= tempa * tempb;
                                                toggle <= 2;
                                            end
                                            end
                                    `SP_1: begin
                                                res <= a + b;
                                                if(a > b)
                                                    {g,l,e} <= 3'b100;
                                                else if(a < b)
                                                    {g,l,e} <= 3'b010;
                                                else
                                                    {g,l,e} <= 3'b001;
                                                toggle <= toggle;
                                           end
                                    default: begin
                                                res <= a - b;
                                                if(a > b)
                                                    {g,l,e} <= 3'b100;
                                                else if(a < b)
                                                    {g,l,e} <= 3'b010;
                                                else
                                                    {g,l,e} <= 3'b001;
                                                toggle <= toggle;
                                          end
                                endcase
                            end
                        end
                        else begin
                            res <= {(`WIDTH + 1){1'b0}};
                            {g,l,e} <= 3'b000;
                            err <= 1;
                            toggle <= 0;
                        end
                end
                else begin
                    res <= {(`WIDTH + 1){1'b0}};
                    err <= 1;
                    toggle <= 0;
                end
           end
           else begin
            g <= 1'b0;
            l <= 1'b0;
            e <= 1'b0;
            err <= 1'b0;
            toggle <= toggle;
            tempc <= 1'b0;
            if(((cmd >= `AND && cmd <= `XNOR) || (cmd == `ROL_A_B) || (cmd == `R                                                                                                             OR_A_B)))
            begin
                if(inp_valid == 3)
                begin
                    if(cmd_prev != cmd || tempa != opa || tempb != opb)
                    begin
                        toggle <= 1;
                        cmd_prev <= cmd;
                        tempa <= opa;
                        tempb <= opb;
                        res <= res;
                    end
                    else
                    begin
                        case(cmd)
                            `NAND: res <= ~(tempa & tempb) & MASK;
                            `OR: res <= tempa | tempb;
                            `NOR: res <= ~(tempa | tempb) & MASK;
                            `XOR: res <= tempa ^ tempb;
                            `XNOR: res <= ~(tempa ^ tempb) & MASK;
                            `ROL_A_B:
                            begin
                                res <= {1'b0,(tempa << shift_amt) | (tempa>>(`WI                                                                                                             DTH-shift_amt))};
                                err <= |tempb[(`WIDTH-1):(log2+1)];
                            end
                            `ROR_A_B:
                            begin
                                res <= {1'b0,(tempa>>shift_amt)|(tempa<<(`WIDTH-                                                                                                             shift_amt))};
                                err <= |tempb[(`WIDTH-1):(log2+1)];
                            end
                            default: res <= tempa & tempb;
                        endcase
                        toggle <= toggle;
                    end
                end
                else begin
                    err <= 1;
                    res <= {(`WIDTH + 1){1'b0}};
                    toggle <= 0;
                end
            end
            else if((cmd == `NOT_A) || (cmd == `SHR1_A) || (cmd == `SHL1_A))
            begin
                if(inp_valid == 1)
                begin
                    if(cmd_prev != cmd || tempa != opa)
                    begin
                        toggle <= 1;
                        cmd_prev <= cmd;
                        tempa <= opa;
                        tempb <= opb;
                        res <= res;
                    end
                    else
                    begin
                        if(cmd == `NOT_A)begin
                            res <= ~tempa & MASK;
                        end
                        else if(cmd == `SHR1_A)
                            res <= tempa >> 1;
                        else
                            res <= tempa << 1;
                        toggle <= toggle;
                    end
                end
                else
                begin
                    err <= 1;
                    res <= {(`WIDTH + 1){1'b0}};
                    toggle <= 0;
                end
            end
            else if((cmd == `NOT_B) || (cmd == `SHR1_B) | (cmd == `SHL1_B))
            begin
                if(inp_valid == 2)
                begin
                    if(cmd_prev != cmd || tempb != opb)
                    begin
                        toggle <= 1;
                        cmd_prev <= cmd;
                        tempa <= opa;
                        tempb <= opb;
                        res <= res;
                    end
                    else
                    begin
                        if(cmd == `NOT_B)
                            res <= ~tempb & MASK;
                        else if(cmd == `SHR1_B)
                            res <= tempb >> 1;
                        else
                            res <= tempb << 1;
                        toggle <= toggle;
                    end
                end
                else
                begin
                    err <= 1;
                    res <= {(`WIDTH + 1){1'b0}};
                    toggle <= 0;
                end
            end
            else begin
                res <= {(`WIDTH + 1){1'b0}};
                err <= 1;
                toggle <= 0;
            end
           end
       end
       else begin //assuming that the previous value is kept
        res <= res;
        g <= g;
        l <= l;
        e <= e;
        err <= err;
        toggle <= 0;
       end
    end
end
    always@(*)
    begin
        cout = 1'b0;
        neg = 1'b0;
        oflow = 1'b0;
        zero = 1'b0;
        if(mode == 1) begin
          if( cmd == `SUB | cmd == `SUB_CIN | cmd == `ADD | cmd == `ADD_CIN ) be                                                                                                             gin
              if(toggle == 1) begin
                cout = res[`WIDTH];
                oflow = res[`WIDTH];
              end
          end
          else if( cmd == `SP_2 | cmd == `SP_1 ) begin
              if(toggle == 1) begin
                cout = res[`WIDTH];
                if(cmd == `SP_1)
                  oflow = ((tempa[`WIDTH-1] == tempb[`WIDTH-1]) && (res[`WIDTH-1                                                                                                             ] != tempa[`WIDTH-1])) ? 1 : 0;
                else
                  oflow = ((tempa[`WIDTH-1] != tempb[`WIDTH-1]) && (res[`WIDTH-1                                                                                                             ] != tempa[`WIDTH-1])) ? 1 : 0;
              end
          end
          else begin
              cout = 1'b0;
              oflow = 1'b0;
          end
          if(cmd == `SP_1 | cmd == `SP_2)
          begin
            if(toggle == 1) begin
              zero = (res == 0) ? 1 : 0;
              neg = res[`WIDTH];
            end
          end
          else begin
            neg = 1'b0;
            zero = 1'b0;
          end
      end
      else
      begin
         cout = 1'b0;
         neg = 1'b0;
         oflow = 1'b0;
         zero = 1'b0;
      end
    end
    assign a = $signed(tempa);
    assign b = $signed(tempb);
endmodule
