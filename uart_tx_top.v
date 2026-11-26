// 发送上板顶层：每秒发一个字节，循环 55 -> A5 -> 0F -> F0
`timescale 1ns/1ns

module uart_tx_top(
    input  wire       Clk,        // Y18
    input  wire       Rst_n,      // B21，S4 按下为 0
    output wire       Uart_Tx,    // M15
    output wire [3:0] Led
);

    localparam CLOCK_FREQ = 50_000_000;
    localparam BAUD       = 9600;

    wire Tx_Done;

    reg [25:0] tick_cnt;
    reg        send_tick;

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            tick_cnt  <= 26'd0;
            send_tick <= 1'b0;
        end
        else if (tick_cnt == CLOCK_FREQ - 1) begin
            tick_cnt  <= 26'd0;
            send_tick <= 1'b1;
        end
        else begin
            tick_cnt  <= tick_cnt + 1'b1;
            send_tick <= 1'b0;
        end
    end

    reg [1:0] idx;

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            idx <= 2'd0;
        else if (Tx_Done)
            idx <= idx + 1'b1;
    end

    reg [7:0] send_data;

    always @(*) begin
        case (idx)
            2'd0:    send_data = 8'h55;
            2'd1:    send_data = 8'hA5;
            2'd2:    send_data = 8'h0F;
            default: send_data = 8'hF0;
        endcase
    end

    uart_tx #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD       (BAUD)
    ) u_uart_tx (
        .Clk     (Clk),
        .Rst_n   (Rst_n),
        .Send_Go (send_tick),
        .Data    (send_data),
        .Uart_Tx (Uart_Tx),
        .Tx_Done (Tx_Done)
    );

    reg heartbeat;

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            heartbeat <= 1'b0;
        else if (Tx_Done)
            heartbeat <= ~heartbeat;
    end

    assign Led[0]   = heartbeat;
    assign Led[1]   = Uart_Tx;
    assign Led[3:2] = idx;

endmodule
