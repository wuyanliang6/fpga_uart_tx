// uart_rx 的自检 testbench
// 参数缩小 325 倍：一位 16 拍，真实是 5208 拍
`timescale 1ns / 1ps

module uart_rx_tb;

    localparam CLOCK_FREQ  = 1600;
    localparam BAUD        = 100;
    localparam CLK_PER_BIT = CLOCK_FREQ / BAUD;

    reg         Clk;
    reg         Rst_n;
    reg         uart_rx;

    wire [7:0]  Data;
    wire        Rx_Done;

    integer     err_cnt;

    uart_rx #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD       (BAUD)
    ) dut (
        .Clk        (Clk),
        .Rst_n      (Rst_n),
        .uart_rx    (uart_rx),
        .Data       (Data),
        .Rx_Done    (Rx_Done)
    );

    initial Clk = 1'b0;
    always #10 Clk = ~Clk;

    // 按 8N1 在线上一个字节
    task send_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 1'b0;
            repeat (CLK_PER_BIT) @(posedge Clk);

            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i];                 // 先发低位
                repeat (CLK_PER_BIT) @(posedge Clk);
            end

            uart_rx = 1'b1;
            repeat (CLK_PER_BIT) @(posedge Clk);
        end
    endtask

    task check(input [7:0] expect);
        begin
            @(posedge Rx_Done);
            #1;
            if (Data !== expect) begin
                err_cnt = err_cnt + 1;
                $display("[!] %0t : got %02h, expect %02h", $time, Data, expect);
            end
            else
                $display("[OK] %0t : got %02h", $time, Data);
        end
    endtask

    initial begin
        err_cnt = 0;
        uart_rx = 1'b1;

        Rst_n = 1'b0;
        repeat (3) @(posedge Clk);
        Rst_n = 1'b1;
        repeat (3) @(posedge Clk);

        // Rx_Done 只有一拍，必须和 send_byte 并行跑
        fork send_byte(8'h55); check(8'h55); join
        fork send_byte(8'hA5); check(8'hA5); join
        fork send_byte(8'h0F); check(8'h0F); join   // 0F 和 F0 能抓出位序反了
        fork send_byte(8'hF0); check(8'hF0); join

        if (err_cnt == 0)
            $display("\n===== PASS : 4 bytes received correctly =====\n");
        else
            $display("\n===== FAIL : %0d error(s) =====\n", err_cnt);

        $stop;
    end

    // 卡死保护
    initial begin
        #200_000;
        $display("\n===== TIMEOUT =====\n");
        $stop;
    end

endmodule
