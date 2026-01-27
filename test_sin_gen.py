import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge

@cocotb.test()
async def test_3_125mhz_sine(dut):
    """验证 3.125MHz 正弦波产生 (freq_word = 8)"""

    # 1. 启动时钟: 100MHz -> 周期 10ns (新版本 units 改为 unit)
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # 2. 复位系统
    dut.rst_n.value = 0
    dut.en.value = 0
    dut.freq_word.value = 0
    await Timer(100, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 3. 设置频率控制字 n=8 产生 3.125MHz 波形
    dut.freq_word.value = 8
    dut.en.value = 1
    
    # 4. 等待流水线稳定 (31级迭代 + 1级初始，约32个周期)
    for _ in range(40):
        await RisingEdge(dut.clk)

    # 5. 采集数据并验证
    samples = []
    for i in range(64):  # 采样 2 个完整周期
        await FallingEdge(dut.clk)
        
        # 获取 16bit 补码值 (新版本推荐使用 to_signed())
        val = dut.sin_out.value.to_signed()
        samples.append(val)
        
        # 实时打印部分数据用于观察 (使用 integer 获取整数值)
        if i % 8 == 0:
            dut._log.info(f"Sample {i}: {val} (Integer: {int(dut.sin_out.value)})")

    # 6. 精度检查
    max_val = max(samples)
    min_val = min(samples)
    
    dut._log.info(f"Detected Max: {max_val}, Min: {min_val}")
    
    # 根据 16 位补码范围验证幅值
    assert max_val > 30000, "Amplitude positive peak too low!"
    assert min_val < -30000, "Amplitude negative peak too high!"

    dut._log.info("3.125MHz Sine Wave test passed!")