/**
 * Day 29: 机会扫描器
 * 
 * 扫描 DEX 套利机会
 */

interface Price {
  dex: string;
  tokenPair: string;
  price: number;
  timestamp: number;
}

interface Opportunity {
  dexA: string;
  dexB: string;
  tokenPair: string;
  priceA: number;
  priceB: number;
  profitPercent: number;
  estimatedProfit: number;
}

class OpportunityScanner {
  private priceCache = new Map<string, Price[]>();

  addPrice(price: Price) {
    const key = price.tokenPair;
    if (!this.priceCache.has(key)) {
      this.priceCache.set(key, []);
    }
    this.priceCache.get(key)!.push(price);
    
    // 只保留最近的价格
    const prices = this.priceCache.get(key)!;
    if (prices.length > 10) {
      prices.shift();
    }
  }

  scanOpportunities(minProfitPercent: number = 1.0): Opportunity[] {
    const opportunities: Opportunity[] = [];

    for (const [pair, prices] of this.priceCache) {
      // 需要至少2个DEX的价格
      if (prices.length < 2) continue;

      // 只使用最近的价格
      const recentPrices = prices.slice(-5);

      for (let i = 0; i < recentPrices.length; i++) {
        for (let j = i + 1; j < recentPrices.length; j++) {
          const priceA = recentPrices[i];
          const priceB = recentPrices[j];

          const priceDiff = Math.abs(priceA.price - priceB.price);
          const avgPrice = (priceA.price + priceB.price) / 2;
          const profitPercent = (priceDiff / avgPrice) * 100;

          if (profitPercent >= minProfitPercent) {
            const tradeAmount = 10000; // $10000
            const estimatedProfit = this.calculateProfit(
              priceA.price,
              priceB.price,
              tradeAmount
            );

            opportunities.push({
              dexA: priceA.dex,
              dexB: priceB.dex,
              tokenPair: pair,
              priceA: priceA.price,
              priceB: priceB.price,
              profitPercent,
              estimatedProfit
            });
          }
        }
      }
    }

    return opportunities.sort((a, b) => b.estimatedProfit - a.estimatedProfit);
  }

  private calculateProfit(
    priceA: number,
    priceB: number,
    tradeAmount: number
  ): number {
    const buyPrice = Math.min(priceA, priceB);
    const sellPrice = Math.max(priceA, priceB);

    // 买入
    const buyAmount = tradeAmount / buyPrice;
    
    // 卖出
    const revenue = buyAmount * sellPrice;
    
    // 手续费 (0.3% * 2)
    const fees = tradeAmount * 0.006;
    
    // Gas 费用（估算）
    const gasCost = 0.1;
    
    const netProfit = revenue - tradeAmount - fees - gasCost;
    return Number(netProfit.toFixed(2));
  }

  printOpportunities(opportunities: Opportunity[]) {
    console.log(`\n💰 Found ${opportunities.length} arbitrage opportunities:\n`);

    for (const opp of opportunities) {
      console.log(`🔄 ${opp.tokenPair}`);
      console.log(`   ${opp.dexA}: $${opp.priceA.toFixed(4)}`);
      console.log(`   ${opp.dexB}: $${opp.priceB.toFixed(4)}`);
      console.log(`   📈 Profit: ${opp.profitPercent.toFixed(2)}% (~$${opp.estimatedProfit})`);
      console.log('');
    }
  }
}

// 示例使用
async function main() {
  const scanner = new OpportunityScanner();

  // 模拟价格数据
  const mockPrices: Price[] = [
    { dex: 'Liquidswap', tokenPair: 'APT/USDC', price: 10.0, timestamp: Date.now() },
    { dex: 'PancakeSwap', tokenPair: 'APT/USDC', price: 10.5, timestamp: Date.now() },
    { dex: 'SushiSwap', tokenPair: 'APT/USDC', price: 9.8, timestamp: Date.now() },
    { dex: 'Liquidswap', tokenPair: 'BTC/USDC', price: 45000, timestamp: Date.now() },
    { dex: 'PancakeSwap', tokenPair: 'BTC/USDC', price: 45100, timestamp: Date.now() },
  ];

  // 添加价格
  for (const price of mockPrices) {
    scanner.addPrice(price);
  }

  // 扫描机会
  const opportunities = scanner.scanOpportunities(1.0);
  scanner.printOpportunities(opportunities);
}

if (require.main === module) {
  main().catch(console.error);
}

export { OpportunityScanner };
