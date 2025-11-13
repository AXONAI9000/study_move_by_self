// 套利计算器脚本
// 计算套利机会的预期收益和风险

// 简单套利计算器
class SimpleArbitrageCalculator {
  private feeRate: number;
  private gasEstimate: number;
  
  constructor(feeRate: number = 0.003, gasEstimate: number = 0.5) {
    this.feeRate = feeRate;
    this.gasEstimate = gasEstimate;
  }
  
  // 计算考虑滑点的输出
  calculateOutputWithSlippage(
    amountIn: number,
    reserveIn: number,
    reserveOut: number
  ): number {
    // 扣除手续费
    const amountInWithFee = amountIn * (1 - this.feeRate);
    
    // 恒定乘积公式
    const k = reserveIn * reserveOut;
    const newReserveIn = reserveIn + amountInWithFee;
    const newReserveOut = k / newReserveIn;
    
    return reserveOut - newReserveOut;
  }
  
  // 计算套利净利润
  calculateProfit(
    buyPrice: number,
    sellPrice: number,
    amount: number,
    buyLiquidity: number,
    sellLiquidity: number
  ): number | null {
    // 计算买入获得的数量（考虑滑点）
    const buyReserveUSDC = buyLiquidity;
    const buyReserveToken = buyLiquidity / buyPrice;
    
    const tokensReceived = this.calculateOutputWithSlippage(
      amount,
      buyReserveUSDC,
      buyReserveToken
    );
    
    // 计算卖出获得的 USDC（考虑滑点）
    const sellReserveToken = sellLiquidity / sellPrice;
    const sellReserveUSDC = sellLiquidity;
    
    const usdcReceived = this.calculateOutputWithSlippage(
      tokensReceived,
      sellReserveToken,
      sellReserveUSDC
    );
    
    // 计算净利润
    const netProfit = usdcReceived - amount - this.gasEstimate;
    
    return netProfit > 0 ? netProfit : null;
  }
  
  // 计算最优交易量
  findOptimalAmount(
    priceDiff: number,
    buyLiquidity: number,
    sellLiquidity: number,
    maxAmount: number = 10000
  ): { amount: number; profit: number } {
    let maxProfit = 0;
    let optimalAmount = 0;
    
    // 从100到maxAmount，步长100
    for (let amount = 100; amount <= maxAmount; amount += 100) {
      const profit = this.calculateProfit(
        10,  // 示例买入价
        10 + priceDiff,  // 示例卖出价
        amount,
        buyLiquidity,
        sellLiquidity
      );
      
      if (profit && profit > maxProfit) {
        maxProfit = profit;
        optimalAmount = amount;
      }
    }
    
    return { amount: optimalAmount, profit: maxProfit };
  }
}

// 三角套利计算器
class TriangularArbitrageCalculator {
  private feeRate: number;
  
  constructor(feeRate: number = 0.003) {
    this.feeRate = feeRate;
  }
  
  // 计算三角套利收益
  calculateProfit(
    startAmount: number,
    rate1: number,
    rate2: number,
    rate3: number
  ): { endAmount: number; profit: number; profitRate: number } {
    // 第一步交换
    let amount = startAmount * rate1 * (1 - this.feeRate);
    
    // 第二步交换
    amount = amount * rate2 * (1 - this.feeRate);
    
    // 第三步交换
    const endAmount = amount * rate3 * (1 - this.feeRate);
    
    const profit = endAmount - startAmount;
    const profitRate = (endAmount / startAmount - 1) * 100;
    
    return { endAmount, profit, profitRate };
  }
  
  // 查找三角套利路径
  findPaths(
    tokens: string[],
    rates: Map<string, Map<string, number>>,
    minProfitRate: number = 0.5
  ): any[] {
    const paths: any[] = [];
    
    for (let i = 0; i < tokens.length; i++) {
      const tokenA = tokens[i];
      
      for (let j = 0; j < tokens.length; j++) {
        if (i === j) continue;
        const tokenB = tokens[j];
        
        for (let k = 0; k < tokens.length; k++) {
          if (i === k || j === k) continue;
          const tokenC = tokens[k];
          
          const rateAB = rates.get(tokenA)?.get(tokenB);
          const rateBC = rates.get(tokenB)?.get(tokenC);
          const rateCA = rates.get(tokenC)?.get(tokenA);
          
          if (rateAB && rateBC && rateCA) {
            const result = this.calculateProfit(1000, rateAB, rateBC, rateCA);
            
            if (result.profitRate >= minProfitRate) {
              paths.push({
                path: [tokenA, tokenB, tokenC, tokenA],
                rates: [rateAB, rateBC, rateCA],
                ...result
              });
            }
          }
        }
      }
    }
    
    return paths.sort((a, b) => b.profitRate - a.profitRate);
  }
}

// 示例使用
function example() {
  console.log('=== 简单套利示例 ===\n');
  
  const simpleCalc = new SimpleArbitrageCalculator(0.003, 0.5);
  
  const profit = simpleCalc.calculateProfit(
    10.0,    // 买入价
    10.5,    // 卖出价
    1000,    // 交易量
    100000,  // 买入池流动性
    80000    // 卖出池流动性
  );
  
  if (profit) {
    console.log(`预期净利润: $${profit.toFixed(2)}`);
    console.log(`投资回报率: ${(profit / 1000 * 100).toFixed(2)}%`);
  } else {
    console.log('没有利润空间');
  }
  
  console.log('\n=== 三角套利示例 ===\n');
  
  const triCalc = new TriangularArbitrageCalculator(0.003);
  
  const result = triCalc.calculateProfit(
    1000,     // 起始金额
    10.0,     // APT → USDC
    0.00003,  // USDC → BTC
    3500      // BTC → APT
  );
  
  console.log(`起始金额: $${1000}`);
  console.log(`最终金额: $${result.endAmount.toFixed(2)}`);
  console.log(`净利润: $${result.profit.toFixed(2)}`);
  console.log(`利润率: ${result.profitRate.toFixed(2)}%`);
  
  console.log('\n=== 路径搜索示例 ===\n');
  
  const rates = new Map([
    ['APT', new Map([['USDC', 10.0], ['ETH', 0.005]])],
    ['USDC', new Map([['BTC', 0.00003], ['APT', 0.1]])],
    ['BTC', new Map([['APT', 3500], ['USDC', 35000]])],
    ['ETH', new Map([['APT', 200], ['USDC', 2000]])],
  ]);
  
  const paths = triCalc.findPaths(['APT', 'USDC', 'BTC'], rates, 0.5);
  
  console.log(`找到 ${paths.length} 个套利路径:\n`);
  paths.forEach((path, idx) => {
    console.log(`${idx + 1}. ${path.path.join(' → ')}`);
    console.log(`   利润率: ${path.profitRate.toFixed(2)}%`);
    console.log(`   利润: $${path.profit.toFixed(2)}\n`);
  });
}

// 运行示例
if (typeof window === 'undefined') {
  example();
}

export { SimpleArbitrageCalculator, TriangularArbitrageCalculator };
