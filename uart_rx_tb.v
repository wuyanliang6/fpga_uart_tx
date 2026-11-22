//=============================================================================
//  uart_rx_tb.v  ——  自检式 testbench：扮演“电脑”，往接收端一个字节一个字节地灌
//
//  它做的事：
//    1. 按 9600-8N1 的时序，在 uart_rx 这根线上“手动”拉出一个字节
//    2. 等模块吐出 Rx_Done
//    3. 把 Data 和“应该是什么”比一比
//
//  参数说明（为什么是 1600 / 100）：
//    CLOCK_FREQ=1600, BAUD=100  →  一位 = 16 拍（真实是 5208 拍）
//    门限逻辑完全一样，只是把时间缩小了 325 倍，仿真几微秒就跑完。
//=============================================================================
`timescale 1ns / 1ps

module uart_rx_tb;

    //------------------------------------------------------------------
    // 参数
    //------------------------------------------------------------------
    localparam CLOCK_FREQ   = 1600;
    localparam BAUD         = 100;
    localparam CLK_PER_BIT  = CLOCK_FREQ / BAUD;   // 16 拍 = 一位

    //------------------------------------------------------------------
    // 信号
    //------------------------------------------------------------------
    reg         Clk;
    reg         Rst_n;
    reg         uart_rx;        // 我（tb）扮演电脑，往这根线上推电平

    wire [7:0]  Data;
    wire        Rx_Done;

    integer     err_cnt;

    //------------------------------------------------------------------
    // 被测模块
    //------------------------------------------------------------------
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

    //------------------------------------------------------------------
    // 时钟：周期 20ns
    //------------------------------------------------------------------
    initial Clk = 1'b0;
    always #10 Clk = ~Clk;

    //------------------------------------------------------------------
    // task 1：按协议在线上“画”出一个字节
    //   起始位(0) → 8 个数据位(LSB first) → 停止位(1)
    //------------------------------------------------------------------
    task send_byte(input [7:0] b);
        integer i;
        begin
            uart_rx = 1'b0;                              // 起始位
            repeat (CLK_PER_BIT) @(posedge Clk);

            for (i = 0; i < 8; i = i + 1) begin          // 8 个数据位
                uart_rx = b[i];                          // ★ LSB first：先发 b[0]
                repeat (CLK_PER_BIT) @(posedge Clk);
            end

            uart_rx = 1'b1;                              // 停止位
            repeat (CLK_PER_BIT) @(posedge Clk);
        end
    endtask

    //------------------------------------------------------------------
    // task 2：等 Rx_Done，然后把 Data 和期望值比一比
    //------------------------------------------------------------------
    task check(input [7:0] expect);
        begin
            @(posedge Rx_Done);        // 等到“收完了”那一个脉冲
            #1;                        // 让 Data 稳定一下
            if (Data !== expect) begin
                err_cnt = err_cnt + 1;
                $display("[!] %0t : got %02h, expect %02h", $time, Data, expect);
            end
            else begin
                $display("[OK] %0t : got %02h", $time, Data);
            end
        end
    endtask

    //------------------------------------------------------------------
    // 主流程
    //------------------------------------------------------------------
    initial begin
        err_cnt = 0;
        uart_rx = 1'b1;          // 空闲是高

        // 复位
        Rst_n = 1'b0;
        repeat (3) @(posedge Clk);
        Rst_n = 1'b1;
        repeat (3) @(posedge Clk);

        // 注意：send_byte 和 check 必须【并行】跑
        // 因为 Rx_Done 只亮一拍，send_byte 还没返回它就已经过去了
        fork
            send_byte(8'h55); check(8'h55);
        join

        fork
            send_byte(8'hA5); check(8'hA5);
        join

        fork
            send_byte(8'h0F); check(8'h0F);   // ★ 重点：0x0F 和 0xF0 能抓出“位序反了”
        join

        fork
            send_byte(8'hF0); check(8'hF0);
        join

        if (err_cnt == 0)
            $display("\n===== PASS : 4 bytes received correctly =====\n");
        else
            $display("\n===== FAIL : %0d error(s) =====\n", err_cnt);

        $stop;
    end

    //------------------------------------------------------------------
    // 看门狗：如果 200us 还没结束，说明模块卡死了
    //------------------------------------------------------------------
    initial begin
        #200_000;
        $display("\n===== TIMEOUT : simulation hung (200us), err_cnt=%0d =====\n", err_cnt);
        $stop;
    end

endmodule
