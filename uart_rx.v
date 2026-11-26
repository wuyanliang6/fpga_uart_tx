// UART 接收，9600 8N1，LSB first
module uart_rx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD       = 9600
)(
    input               Clk,
    input               Rst_n,
    input               uart_rx,        // 板上引脚，和 Clk 没有关系
    output reg  [7:0]   Data,
    output reg          Rx_Done
);

    localparam MCNT_BAUD = CLOCK_FREQ / BAUD - 1;   // 5207
    localparam HALF_BAUD = MCNT_BAUD / 2;           // 2603，采样点在这儿
    localparam BW        = $clog2(MCNT_BAUD + 1);

    reg          uart_rx_d0, uart_rx_d1, uart_rx_d2;
    reg          sending;
    reg [BW-1:0] baud_cnt;
    reg [3:0]    bit_cnt;
    reg [7:0]    rx_shift;

    // 三拍同步，d2 留着和 d1 比边沿
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            uart_rx_d0 <= 1'b1;
            uart_rx_d1 <= 1'b1;
            uart_rx_d2 <= 1'b1;
        end
        else begin
            uart_rx_d0 <= uart_rx;
            uart_rx_d1 <= uart_rx_d0;
            uart_rx_d2 <= uart_rx_d1;
        end
    end

    wire rx_nedge  = uart_rx_d2 & ~uart_rx_d1;
    wire sample_en = sending && (baud_cnt == HALF_BAUD);

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            sending <= 1'b0;
        else if (rx_nedge && !sending)
            sending <= 1'b1;
        else if (sample_en && bit_cnt == 4'd9)
            sending <= 1'b0;
        else if (sample_en && bit_cnt == 4'd0 && uart_rx_d1)
            sending <= 1'b0;        // 起始位中点还是 1，是毛刺，这次不要
    end

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            baud_cnt <= {BW{1'b0}};
        else if (!sending)
            baud_cnt <= {BW{1'b0}};
        else if (baud_cnt == MCNT_BAUD)
            baud_cnt <= {BW{1'b0}};
        else
            baud_cnt <= baud_cnt + 1'b1;
    end

    // 只在采样那一拍动，不是每拍 +1
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            bit_cnt <= 4'd0;
        else if (!sending)
            bit_cnt <= 4'd0;
        else if (sample_en) begin
            if (bit_cnt == 4'd9)
                bit_cnt <= 4'd0;
            else
                bit_cnt <= bit_cnt + 1'b1;
        end
    end

    // 新位进最高位，老数据往右挪，收满 8 次正好拼正
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            rx_shift <= 8'd0;
        else if (sample_en && bit_cnt >= 4'd1 && bit_cnt <= 4'd8)
            rx_shift <= {uart_rx_d1, rx_shift[7:1]};
    end

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            Data    <= 8'd0;
            Rx_Done <= 1'b0;
        end
        else begin
            Rx_Done <= (sample_en && bit_cnt == 4'd9);
            if (sample_en && bit_cnt == 4'd9)
                Data <= rx_shift;
        end
    end

endmodule
