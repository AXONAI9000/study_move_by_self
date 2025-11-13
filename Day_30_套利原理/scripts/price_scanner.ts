// TypeScript 价格扫描器脚本
// 用于实时扫描多个 DEX 的价格并发现套利机会

import { AptosClient, Types } from 'aptos';

// 配置
const NODE_URL = 'https://fullnode.testnet.aptoslabs.com/v1';
const SCAN_INTERVAL = 3000; // 3秒扫描一次

// DEX 配置
interface DEXConfig {
  name: string;
  moduleAddress: string;
  poolAddress: string;
}

const DEXES: DEXConfig[] = [
  {
    name: 'Liquidswap',
    moduleAddress: '0x190d44266241744264b964a37b8f09863167a12d3e70cda39376cfb4e3561e12',
    poolAddress: '0x...',
  },
  {
    name: 'PancakeSwap',
    moduleAddress: '0x...',
    poolAddress: '0x...',
  },
];

// 价格数据接口
interface PriceData {
  dex: string;
  pair: string;
  price: number;
  reserve0: number;
  reserve1: number;
  liquidity: number;
  timestamp: number;
}

// 套利机会接口
interface ArbitrageOpportunity {
  buyDex: string;
  sellDex: string;
  pair: string;
  buyPrice: number;
  sellPrice: number;
  priceDiff: number;
  percentDiff: number;
  estimatedProfit: number;
  timestamp: number;
}

class PriceScanner {
  private client: AptosClient;
  private priceHistory: Map<string, PriceData[]>;
  
  constructor(nodeUrl: string) {
    this.client = new AptosClient(nodeUrl);
    this.priceHistory = new Map();
  }
  
  // 从单个 DEX 查询价格
  async fetchPriceFromDEX(dex: DEXConfig, pair: string): Promise<PriceData | null> {
    try {
      // 这里需要根据实际 DEX 的接口调整
      // 示例：查询池的储备量
      const resource = await this.client.getAccountResource(
        dex.poolAddress,
        `${dex.moduleAddress}::liquidity_pool::LiquidityPool<CoinA, CoinB>`
      );
      
      const data: any = resource.data;
      const reserve0 = parseInt(data.reserve_0);
      const reserve1 = parseInt(data.reserve_1);
      
      // 计算价格
      const price = reserve1 / reserve0;
      const liquidity = Math.sqrt(reserve0 * reserve1);
      
      return {
        dex: dex.name,
        pair,
        price,
        reserve0,
        reserve1,
        liquidity,
        timestamp: Date.now(),
      };
    } catch (error) {
      console.error(`Failed to fetch price from ${dex.name}:`, error);
      return null;
    }
  }
  
  // 扫描所有 DEX 的价格
  async scanPrices(pair: string): Promise<PriceData[]> {
    const promises = DEXES.map(dex => this.fetchPriceFromDEX(dex, pair));
    const results = await Promise.allSettled(promises);
    
    const prices: PriceData[] = [];
    for (const result of results) {
      if (result.status === 'fulfilled' && result.value) {
        prices.push(result.value);
      }
    }
    
    // 更新历史数据
    if (!this.priceHistory.has(pair)) {
      this.priceHistory.set(pair, []);
    }
    const history = this.priceHistory.get(pair)!;
    history.push(...prices);
    
    // 只保留最近100条记录
    if (history.length > 100) {
      this.priceHistory.set(pair, history.slice(-100));
    }
    
    return prices;
  }
  
  // 发现套利机会
  findArbitrageOpportunities(
    prices: PriceData[],
    minProfitPercent: number = 0.5
  ): ArbitrageOpportunity[] {
    const opportunities: ArbitrageOpportunity[] = [];
    
    // 比较所有 DEX 对
    for (let i = 0; i < prices.length; i++) {
      for (let j = i + 1; j < prices.length; j++) {
        const price1 = prices[i];
        const price2 = prices[j];
        
        const priceDiff = Math.abs(price1.price - price2.price);
        const percentDiff = (priceDiff / Math.min(price1.price, price2.price)) * 100;
        
        if (percentDiff >= minProfitPercent) {
          // 确定买入和卖出的 DEX
          const [buyDex, sellDex] = price1.price < price2.price
            ? [price1, price2]
            : [price2, price1];
          
          // 估算利润（简化计算）
          const estimatedAmount = 1000; // USDC
          const estimatedProfit = estimatedAmount * (percentDiff / 100);
          
          opportunities.push({
            buyDex: buyDex.dex,
            sellDex: sellDex.dex,
            pair: price1.pair,
            buyPrice: buyDex.price,
            sellPrice: sellDex.price,
            priceDiff,
            percentDiff,
            estimatedProfit,
            timestamp: Date.now(),
          });
        }
      }
    }
    
    return opportunities.sort((a, b) => b.percentDiff - a.percentDiff);
  }
  
  // 计算价格统计
  getPriceStats(pair: string): any {
    const history = this.priceHistory.get(pair);
    if (!history || history.length === 0) {
      return null;
    }
    
    const prices = history.map(h => h.price);
    const mean = prices.reduce((a, b) => a + b, 0) / prices.length;
    
    const variance = prices.reduce((sum, price) => {
      return sum + Math.pow(price - mean, 2);
    }, 0) / prices.length;
    
    const stdDev = Math.sqrt(variance);
    
    return {
      mean,
      stdDev,
      min: Math.min(...prices),
      max: Math.max(...prices),
      current: prices[prices.length - 1],
      samples: prices.length,
    };
  }
}

// 主函数
async function main() {
  console.log('🚀 Starting Price Scanner...\n');
  
  const scanner = new PriceScanner(NODE_URL);
  const pairs = ['APT/USDC', 'BTC/USDC', 'ETH/USDC'];
  
  let scanCount = 0;
  
  // 定期扫描
  setInterval(async () => {
    scanCount++;
    console.log(`\n📊 Scan #${scanCount} - ${new Date().toLocaleTimeString()}`);
    console.log('='.repeat(60));
    
    for (const pair of pairs) {
      const prices = await scanner.scanPrices(pair);
      
      if (prices.length > 0) {
        console.log(`\n${pair}:`);
        prices.forEach(p => {
          console.log(`  ${p.dex.padEnd(15)} Price: ${p.price.toFixed(4)}  Liquidity: $${(p.liquidity / 1e6).toFixed(2)}M`);
        });
        
        // 查找套利机会
        const opportunities = scanner.findArbitrageOpportunities(prices, 0.3);
        
        if (opportunities.length > 0) {
          console.log(`\n  🎯 Found ${opportunities.length} arbitrage opportunity(ies):`);
          opportunities.forEach(opp => {
            console.log(`     Buy: ${opp.buyDex} (${opp.buyPrice.toFixed(4)}) → Sell: ${opp.sellDex} (${opp.sellPrice.toFixed(4)})`);
            console.log(`     Price Diff: ${opp.percentDiff.toFixed(2)}% | Est. Profit: $${opp.estimatedProfit.toFixed(2)}`);
          });
        }
        
        // 显示统计信息
        const stats = scanner.getPriceStats(pair);
        if (stats) {
          console.log(`\n  📈 Statistics: Mean: ${stats.mean.toFixed(4)} | StdDev: ${stats.stdDev.toFixed(4)} | Range: [${stats.min.toFixed(4)}, ${stats.max.toFixed(4)}]`);
        }
      }
    }
  }, SCAN_INTERVAL);
  
  console.log(`\nScanning every ${SCAN_INTERVAL / 1000} seconds...`);
  console.log('Press Ctrl+C to stop.\n');
}

// 错误处理
process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
});

process.on('SIGINT', () => {
  console.log('\n\n👋 Stopping scanner...');
  process.exit(0);
});

// 运行
if (require.main === module) {
  main().catch(console.error);
}

export { PriceScanner, PriceData, ArbitrageOpportunity };
