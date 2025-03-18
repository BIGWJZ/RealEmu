module ROM1 #(
    parameter ADDR_WIDTH = 10;
    parameter DATA_WIDTH = 16;
    parameter HEX_FILE   = "";
    parameter ADDR_LO    = 0 ;
    parameter ADDR_HI    = 2 ** ADDR_WIDTH;
) (
    input CLK,
    input [ADDR_WIDTH-1:0] ADDR,
    output reg [DATA_WIDTH-1:0] DOUT
);

    initial 
    begin : init_rom_block
            $readmemh(HEX_FILE, rom, ADDR_LO, ADDR_HI);
    end 

    (* ram_style = "block" *) reg [DATA_WIDTH:0] rom[ADDR_LO:ADDR_HI];

    always @(posedge clk) begin
        DOUT <= rom[ADDR]; // 1-cycle 读取
    end
    
endmodule
