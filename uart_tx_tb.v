// uart_tx 的自检 testbench
// 参数改小：CLOCK_FREQ=1000, BAUD=100，一位 10 拍，一帧 100 拍
`timescale 1ns/1ns

module uart_tx_tb;

    reg        Clk     = 1'b0;
    reg        Rst_n   = 1'b0;
    reg        Send_Go = 1'b0;
    reg  [7:0] Data    = 8'h00;

    wire Uart_Tx;
    wire Tx_Done;

    integer err_cnt = 0;

    always #10 Clk = ~Clk;

    uart_tx #(
        .CLOCK_FREQ (1000),
        .BAUD       (100)
    ) u_dut (
        .Clk     (Clk),
        .Rst_n   (Rst_n),
        .Send_Go (Send_Go),
        .Data    (Data),
        .Uart_Tx (Uart_Tx),
        .Tx_Done (Tx_Done)
    );

    localparam CLK_PER_BIT = 10;

    // Tx_Done 只有一拍，先存起来，后面再慢慢看
    reg done_seen = 1'b0;

    always @(posedge Clk) begin
        if (Tx_Done)
            done_seen <= 1'b1;
    end

    initial begin
        #500_000;
        $display("===== TIMEOUT ===== ");
        $stop;
    end

    // 发一个字节，在每一位中点采样，然后逐位比对
    task send_and_check(input [7:0] d);
        integer   i;
        reg [9:0] got;          // got[0] 起始位, got[8:1] 数据位, got[9] 停止位
        reg       ok;
        begin
            done_seen = 1'b0;

            @(posedge Clk); #1;
            Data    = d;
            Send_Go = 1'b1;
            @(posedge Clk); #1;
            Send_Go = 1'b0;

            wait (Uart_Tx === 1'b0);            // 等起始位
            repeat (CLK_PER_BIT/2) @(posedge Clk);   // 挪到中点

            for (i = 0; i < 10; i = i + 1) begin
                got[i] = Uart_Tx;
                repeat (CLK_PER_BIT) @(posedge Clk);
            end

            wait (done_seen);
            @(posedge Clk); #1;

            ok = 1'b1;

            if (got[0] !== 1'b0) begin
                err_cnt = err_cnt + 1;
                ok = 1'b0;
                $display("[!] %h : start bit is %b, expected 0", d, got[0]);
            end
            if (got[9] !== 1'b1) begin
                err_cnt = err_cnt + 1;
                ok = 1'b0;
                $display("[!] %h : stop bit is %b, expected 1", d, got[9]);
            end
            if (got[8:1] !== d) begin
                err_cnt = err_cnt + 1;
                ok = 1'b0;
                $display("[!] %h : data bits = %b, expected %b",
                         d, got[8:1], d);
            end

            $display("  sent %h  ->  start=%b  data=%b  stop=%b  %s",
                     d, got[0], got[8:1], got[9], ok ? "OK" : "FAIL");
        end
    endtask

    initial begin
        $display("uart tx test start");

        repeat (5) @(posedge Clk);
        #1 Rst_n = 1'b1;
        repeat (5) @(posedge Clk);

        send_and_check(8'h55);
        send_and_check(8'hA5);
        send_and_check(8'h0F);
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h3C);

        #200;
        if (err_cnt == 0)
            $display("===== PASS =====");
        else
            $display("===== FAIL : %0d error(s) =====", err_cnt);

        $stop;
    end

endmodule
