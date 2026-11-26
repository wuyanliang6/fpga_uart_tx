// UART 发送，9600 8N1，LSB first
`timescale 1ns/1ns

module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD       = 9600
)(
    input               Clk,
    input               Rst_n,
    input               Send_Go,        // 单拍请求，忙的时候会被忽略
    input       [7:0]   Data,
    output reg          Uart_Tx,        // 空闲为高
    output reg          Tx_Done         // 发完给一拍
);

    localparam MCNT_BAUD = CLOCK_FREQ / BAUD - 1;   // 9600 时是 5207
    localparam MCNT_BIT  = 9;                       // 0~9，一共 10 位
    localparam BW        = $clog2(MCNT_BAUD + 1);

    reg [BW-1:0] baud_cnt;
    reg [3:0]    bit_cnt;
    reg          sending;
    reg [7:0]    r_data;

    wire bit_end   = (baud_cnt == MCNT_BAUD);
    wire frame_end = sending && bit_end && (bit_cnt == MCNT_BIT);

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            sending <= 1'b0;
        else if (Send_Go && !sending)
            sending <= 1'b1;
        else if (frame_end)
            sending <= 1'b0;
    end

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            baud_cnt <= {BW{1'b0}};
        else if (!sending)
            baud_cnt <= {BW{1'b0}};
        else if (bit_end)
            baud_cnt <= {BW{1'b0}};
        else
            baud_cnt <= baud_cnt + 1'b1;
    end

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            bit_cnt <= 4'd0;
        else if (!sending)
            bit_cnt <= 4'd0;
        else if (bit_end) begin
            if (bit_cnt == MCNT_BIT)
                bit_cnt <= 4'd0;
            else
                bit_cnt <= bit_cnt + 1'b1;
        end
    end

    // 开发那一刻锁一下，发送途中上层改 Data 也不会把这一帧改坏
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            r_data <= 8'd0;
        else if (Send_Go && !sending)
            r_data <= Data;
    end

    // 0 起始位 / 1~8 数据位 / 9 停止位
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            Uart_Tx <= 1'b1;
        else if (!sending)
            Uart_Tx <= 1'b1;
        else begin
            case (bit_cnt)
                4'd0:    Uart_Tx <= 1'b0;
                4'd1:    Uart_Tx <= r_data[0];
                4'd2:    Uart_Tx <= r_data[1];
                4'd3:    Uart_Tx <= r_data[2];
                4'd4:    Uart_Tx <= r_data[3];
                4'd5:    Uart_Tx <= r_data[4];
                4'd6:    Uart_Tx <= r_data[5];
                4'd7:    Uart_Tx <= r_data[6];
                4'd8:    Uart_Tx <= r_data[7];
                4'd9:    Uart_Tx <= 1'b1;
                default: Uart_Tx <= 1'b1;
            endcase
        end
    end

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            Tx_Done <= 1'b0;
        else
            Tx_Done <= frame_end;
    end

endmodule
