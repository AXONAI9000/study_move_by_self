/**
 * 价格监控脚本
 * 实时监控多个 DEX 的价格变化
 */

import WebSocket from 'ws';
import { EventEmitter } from 'events';

interface PriceUpdate {
  dex: string;
  pair: string;
  price: number;
  liquidity: number;
  volume_24h: number;
  timestamp: number;
}

interface DexConfig {
  name: string;
  wsUrl: string;
  pairs: string[];
}

export class PriceMonitor extends EventEmitter {
  private connections: Map<string, WebSocket> = new Map();
  private priceCache: Map<string, PriceUpdate> = new Map();
  private reconnectIntervals: Map<string, NodeJS.Timeout> = new Map();

  constructor(private dexConfigs: DexConfig[]) {
    super();
  }

  async start() {
    console.log('🔍 启动价格监控...');
    
    for (const config of this.dexConfigs) {
      await this.connectDex(config);
    }
    
    console.log(`✅ 已连接到 ${this.dexConfigs.length} 个 DEX`);
  }

  private async connectDex(config: DexConfig) {
    const ws = new WebSocket(config.wsUrl);
    
    ws.on('open', () => {
      console.log(`✅ 已连接到 ${config.name}`);
      this.subscribe(ws, config);
    });
    
    ws.on('message', (data: WebSocket.Data) => {
      try {
        const update = this.parseMessage(data, config.name);
        if (update) {
          this.handlePriceUpdate(update);
        }
      } catch (error) {
        console.error(`解析消息失败 (${config.name}):`, error);
      }
    });
    
    ws.on('error', (error) => {
      console.error(`WebSocket 错误 (${config.name}):`, error.message);
    });
    
    ws.on('close', () => {
      console.log(`❌ 连接断开 (${config.name})`);
      this.connections.delete(config.name);
      this.scheduleReconnect(config);
    });
    
    this.connections.set(config.name, ws);
  }

  private subscribe(ws: WebSocket, config: DexConfig) {
    // 订阅价格更新
    const subscribeMessage = {
      type: 'subscribe',
      channel: 'prices',
      pairs: config.pairs
    };
    
    ws.send(JSON.stringify(subscribeMessage));
  }

  private parseMessage(data: WebSocket.Data, dex: string): PriceUpdate | null {
    const message = JSON.parse(data.toString());
    
    if (message.type !== 'price_update') {
      return null;
    }
    
    return {
      dex,
      pair: message.pair,
      price: parseFloat(message.price),
      liquidity: parseFloat(message.liquidity || '0'),
      volume_24h: parseFloat(message.volume_24h || '0'),
      timestamp: message.timestamp || Date.now()
    };
  }

  private handlePriceUpdate(update: PriceUpdate) {
    const key = `${update.dex}:${update.pair}`;
    const cached = this.priceCache.get(key);
    
    // 只有价格真正变化时才发出事件
    if (!cached || Math.abs(cached.price - update.price) / cached.price > 0.0001) {
      this.priceCache.set(key, update);
      this.emit('price_update', update);
    }
  }

  private scheduleReconnect(config: DexConfig) {
    // 清除旧的重连定时器
    const oldInterval = this.reconnectIntervals.get(config.name);
    if (oldInterval) {
      clearTimeout(oldInterval);
    }
    
    // 5秒后重连
    const interval = setTimeout(() => {
      console.log(`🔄 尝试重连到 ${config.name}...`);
      this.connectDex(config);
    }, 5000);
    
    this.reconnectIntervals.set(config.name, interval);
  }

  getPrice(dex: string, pair: string): PriceUpdate | null {
    return this.priceCache.get(`${dex}:${pair}`) || null;
  }

  getAllPrices(pair: string): PriceUpdate[] {
    const prices: PriceUpdate[] = [];
    
    for (const [key, value] of this.priceCache) {
      if (value.pair === pair) {
        prices.push(value);
      }
    }
    
    return prices;
  }

  stop() {
    console.log('🛑 停止价格监控...');
    
    // 关闭所有连接
    for (const ws of this.connections.values()) {
      ws.close();
    }
    
    // 清除所有定时器
    for (const interval of this.reconnectIntervals.values()) {
      clearTimeout(interval);
    }
    
    this.connections.clear();
    this.reconnectIntervals.clear();
  }
}

// 示例用法
if (require.main === module) {
  const dexConfigs: DexConfig[] = [
    {
      name: 'PancakeSwap',
      wsUrl: 'wss://pancakeswap.aptos.example/ws',
      pairs: ['APT/USDC', 'APT/BTC']
    },
    {
      name: 'LiquidSwap',
      wsUrl: 'wss://liquidswap.aptos.example/ws',
      pairs: ['APT/USDC', 'APT/BTC']
    }
  ];
  
  const monitor = new PriceMonitor(dexConfigs);
  
  monitor.on('price_update', (update: PriceUpdate) => {
    console.log(`💰 ${update.dex} ${update.pair}: ${update.price}`);
  });
  
  monitor.start();
  
  // 优雅退出
  process.on('SIGINT', () => {
    monitor.stop();
    process.exit(0);
  });
}
