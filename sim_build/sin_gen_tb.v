`timescale 1ns / 1ps

module sin_gen_tb();

    // 信号定义
    reg         clk;
    reg         rst_n;
    reg         en;
    reg  [7:0]  freq_word;
    wire [15:0] sin_out;

    // 实例化设计模块 (DUT)
    sin_gen uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (en),
        .freq_word (freq_word),
        .sin_out   (sin_out)
    );

    // 1. 生成 100MHz 时钟 (周期 10ns) 
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 2. 仿真激励过程
    initial begin
        // 系统初始化
        rst_n     = 0;
        en        = 0;
        freq_word = 8'd0;

        // 复位释放
        #100;
        rst_n = 1;
        #50;

        // --- 场景 A: 验证 3.125MHz 正弦波  ---
        // 计算公式: n = (f_out * 2^8) / f_clk = (3.125 * 256) / 100 = 8 
        freq_word = 8'd8; 
        en = 1;
        
        // 运行足够长的时间以观察多个周期
        // 3.125MHz 周期约为 320ns
        #2000;

        // --- 场景 B: 验证停止产生信号 ---
        en = 0;
        #200;

        // --- 场景 C: 验证其他频率 (例如 10MHz) ---
        // n = (10 * 256) / 100 = 25.6 -> 取整为 26
        freq_word = 8'd26;
        en = 1;
        #1000;

        // 结束仿真
        $display("Simulation Task Finished.");
        $stop;
    end

    // 3. 结果监测
    // 在仿真窗口中可以查看 sin_out 的模拟波形 (Analog Display)
    initial begin
        $monitor("Time=%0t | EN=%b | Freq_Word=%d | Sin_Value=%h", 
                 $time, en, freq_word, sin_out);
    end

endmodule